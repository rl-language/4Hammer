import orks_infantry_data
import source_effects

# Unit-token use follows original component identity through attachment and
# revival; Boss Ammo Runt is its own per-unit token, not the Boyz/Nobz token.
# Sources: Orks/Boyz, Nobz, Warboss (Ammo Runts/Boss' Ammo Runt).
fun orks_ammo_usage(Unit unit, Model model, Bool boss) -> SourceInstance:
    let usage : SourceInstance
    usage.rule = 113 + int(boss)
    usage.owner = unit.owned_by_player1
    usage.source_unit = model.original_unit
    usage.source_model = model.identity
    usage.use_scope = SourceUseScope::unit
    usage.limits.battle = 1
    return usage

# Find the actual conferring bearer; datasheet labels or an empty bodyguard
# cannot supply an ability after its last source model has been removed (p67).
fun orks_ammo_bearer(Board board, UnitID source, Bool boss) -> Int:
    let result = -1
    if source.get() >= board.units.size():
        return result
    let ability = AbilityKind::ammo_runts
    if boss:
        ability = AbilityKind::boss_ammo_runt
    for index in range(board[source].models.size()):
        if model_confers_attached_abilities(board[source][index]) and board[source][index].has_ability(ability) and source_usage_available(board, orks_ammo_usage(board[source], board[source][index], boss)) and result < 0:
            result = index
    return result

# These free tokens are available only at own-Shooting selection, including
# already battle-shocked units; no CP or wound/damage-roll reroll is invented.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss (Boss' Ammo Runt).
fun orks_ammo_available(Board board, UnitID source, Bool boss) -> Bool:
    return source.get() < board.units.size() and !board[source].off_battlefield and has_live_model(board[source]) and board.timing.phase == BattlePhase::shooting and board[source].owned_by_player1 == board.current_player and orks_ammo_bearer(board, source, boss) >= 0

# A unit-wide Ammo Runts grant and a bearer-only Boss grant may coexist. Their
# ordinary duration is the current phase (appendix01.02.02); tokens are spent
# before installing the effect and cannot refresh through attachment/revival.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Boyz,Nobz,Warboss}
fun commit_orks_ammo(Board board, UnitID source, Bool boss):
    assert(orks_ammo_available(board, source, boss), "Ammo Runt unavailable")
    let bearer : ModelID
    bearer = orks_ammo_bearer(board, source, boss)
    commit_source_usage(board, orks_ammo_usage(board[source], board[source][bearer], boss))
    if boss:
        grant_orks_model_effect(board, source, bearer, 114, OrksEffectKind::boss_ammo_hit)
    else:
        grant_orks_effect(board, source, source, 113, OrksEffectKind::ammo_runts_hit, 1, SourceDuration::phase, invalid_entity_identity())

# Free ammunition choices precede Shooting weapon gathering; one Attack owns
# this frame. Orks/Boyz, Nobz and Warboss Ammo Runts; appendix01.02.02 duration.
act orks_datasheet_selection(ctx Board board, frm UnitID source) -> OrksDatasheetSelection:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[source].owned_by_player1
    subaction*(board) pulsa_selection = orks_pulsa_selection(board, source)
    if orks_ammo_available(board, source, false):
        act use_ammo_runts(Bool ammo_use)
        if ammo_use:
            commit_orks_ammo(board, source, false)
    if orks_ammo_available(board, source, true):
        act use_boss_ammo_runt(Bool boss_ammo_use)
        if boss_ammo_use:
            commit_orks_ammo(board, source, true)
    board.current_decision_maker = previous_owner

# Orks/Stormboyz Rokkit Charge is chosen WHEN SELECTED TO FIGHT, before
# Overrun movement and attack declaration, not delayed until attack gathering.
# One SelectedFight owns this frame; grants expire at phase end01.02.02.
act orks_rokkit_selection(ctx Board board, frm UnitID source) -> OrksRokkitSelection:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[source].owned_by_player1
    if board[source].has_charged and board[source].has_ability(AbilityKind::rokkit_charge):
        act use_rokkit_charge(Bool rokkit_use)
        if rokkit_use:
            grant_orks_effect(board, source, source, 115, OrksEffectKind::rokkit_charge, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Boyz charge permission includes every melee weapon of the attached unit.
# Dakkarig's riled ability applies only to ranged attacks; Rokkit Charge's
# Hazardous is acquired before selected physical weapons are counted (p81).
# Sources: Orks/Boyz Tide of Muscle, Big-Mek-Dakkarig, Stormboyz.
fun append_orks_datasheet_weapon_rules(Board board, UnitID source, Weapon selected, WeaponAbilitySet result):
    ref unit = board[source]
    append_orks_elite_weapon_rules(unit, selected, result)
    if selected.range() == 0:
        if unit.has_charged and unit.has_ability(AbilityKind::tide_of_muscle):
            result.append(weapon_rule(WeaponRuleKind::letal_hits))
        if unit_orks_effect(board, unit, OrksEffectKind::rokkit_charge) > 0:
            result.append(weapon_rule(WeaponRuleKind::hazardous))
    else:
        if unit.has_ability(AbilityKind::even_more_dakka) and unit_is_riled_up(unit):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))

# Might Is Right affects only that Warboss bearer; Carnage/Rokkit Charge
# affect the combined unit's melee attacks, including mandatory Extra Attacks.
# Dakkarig's ranged target is already declared when A is generated (04.03).
# Sources: Orks/Warboss, Warbikers, Stormboyz, Big-Mek-Dakkarig.
fun append_orks_datasheet_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    let bearer = declared_model_index(board, source, declaration)
    if bearer < 0:
        return
    ref unit = board[source]
    ref model = unit[bearer]
    append_orks_elite_modifiers(unit, declaration, kind, result)
    let addition = 0
    if declaration.weapon.range() == 0:
        if unit.has_charged and model.has_ability(AbilityKind::might_is_right):
            if kind.value == ModifiedCharacteristic::attacks.value:
                addition = addition + 3
            if kind.value == ModifiedCharacteristic::strength.value:
                addition = addition + 2
        if unit.has_charged and unit.has_ability(AbilityKind::high_speed_carnage) and (kind.value == ModifiedCharacteristic::strength.value or kind.value == ModifiedCharacteristic::damage.value):
            addition = addition + 1
        if unit_orks_effect(board, unit, OrksEffectKind::rokkit_charge) > 0 and (kind.value == ModifiedCharacteristic::attacks.value or kind.value == ModifiedCharacteristic::strength.value):
            addition = addition + 1
    else:
        if kind.value == ModifiedCharacteristic::attacks.value and declaration.weapon_name.value == NamedWeapon::blitzkannon.value and model.has_ability(AbilityKind::blitz_dem_gitz) and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player:
            for target in range(board.units.size()):
                if declaration.targeted[target] and !board[target].has_keyword(Keyword::monster) and !board[target].has_keyword(Keyword::vehicle):
                    addition = 6
    if addition != 0:
        result.append(rule_modifier(ModifierOperation::add, addition))

# Kans check EVERY live target model's own effective T, not bodyguard T or
# the attacking group's inherited maximum. Retained corpses are not models
# with an active characteristic for this condition (core p87; source wording).
# https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
fun orks_target_has_toughness_seven(Unit target) -> Bool:
    let found = false
    for index in range(target.models.size()):
        found = found or (target[index].is_alive() and target[index].effective_toughness() >= 7)
    return found

# Distinct model/unit contributions retain separate ignore choices and group
# identity. Paired Krumpas never buffs a different weapon/bearer; Mozrog's
# Monster/Vehicle wound rerolls apply to all of that unit's melee attacks.
# Sources: Orks/Bigboss, Boyz, Nobz, Warboss, Killa-Kans, Mozrog-Skragbad.
fun append_orks_datasheet_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon declaration, AttackSequenceInfo info):
    append_orks_elite_attack_effects(board, source, target, declaration, info)
    let bearer = declared_model_index(board, source, declaration)
    ref unit = board[source]
    ref model = unit[bearer]
    if declaration.weapon.range() == 0:
        if unit.has_ability(AbilityKind::sumfin_to_prove):
            info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if model.paired_krumpas and declaration.weapon_name.value == NamedWeapon::kustom_krumpa.value:
            info.reroll_hits = true
            info.reroll_wounds = true
        if unit.has_ability(AbilityKind::da_bigger_dey_iz) and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)):
            info.reroll_wounds = true
    else:
        if unit_orks_effect(board, unit, OrksEffectKind::ammo_runts_hit) > 0:
            info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if model_orks_effect(board, model, OrksEffectKind::boss_ammo_hit) > 0:
            info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if orks_type(unit, OrksDatasheet::killa_kans) and !orks_target_has_toughness_seven(board[target]):
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))

# Identical Stampede auras do not stack. Live friendly Snagga units within6in
# gain+1, including the source itself; recipients offboard cannot be measured.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
fun orks_stampede_charge_bonus(Board board, Unit unit) -> Int:
    if unit.off_battlefield or !unit.has_keyword(Keyword::beast_snagga):
        return 0
    let present = false
    for index in range(board.units.size()):
        ref source = board[index]
        present = present or (!source.off_battlefield and has_live_model(source) and source.owned_by_player1 == unit.owned_by_player1 and source.has_ability(AbilityKind::thundering_stampede) and live_unit_distance(source, unit) <= 6.0)
    return int(present)

# Both monster characters need a nearby friendly Snagga unit; an excluded
# MONSTER CHARACTER unit cannot qualify even if it also has other models.
# Orks/Beastboss-on-Squigosaur Boss of da Hunt; Mozrog Beast Snagga Following.
fun orks_snagga_following(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !unit.attached_units.empty() or !unit.has_ability(AbilityKind::boss_of_da_hunt):
        return false
    let present = false
    for index in range(board.units.size()):
        ref ally = board[index]
        present = present or (!ally.off_battlefield and has_live_model(ally) and ally.owned_by_player1 == unit.owned_by_player1 and ally.has_keyword(Keyword::beast_snagga) and !(ally.has_keyword(Keyword::monster) and ally.has_keyword(Keyword::character)) and live_unit_distance(ally, unit) <= 3.0)
    return present
