import attack_results
import board
import source_effects

# Green Tide, Bully Boyz and Throat-slittas add separate ability instances;
# p78's duplicate chooser still decides between sources without summing them.
fun append_orks_package_weapon_rules(Board board, UnitID source, Int bearer, Int slot, WeaponAbilitySet result):
    let name : WeaponCode
    name = equipped_weapon_family(board[source][bearer], slot).value
    append_orks_package_weapon_rules(board, source, bearer, board[source][bearer].weapons[slot].profile, name, result)

# Borrowed Firing Deck weapons receive carrier-model/unit package rules using
# their own named profile, never the carrier's coincidentally matching slot.
# Orks detachment cards and core Firing Deck p81.
fun append_orks_package_weapon_rules(Board board, UnitID source, Int bearer, Weapon selected, WeaponCode name, WeaponAbilitySet result):
    ref unit = board[source]
    ref model = unit[bearer]
    let melee = selected.range() == 0
    if melee and orks_package(board, unit, OrksDetachment::green_tide):
        if orks_type(unit, OrksDatasheet::boyz):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
        if unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry) and unit.has_charged:
            result.append(conditional_weapon_rule(WeaponRuleKind::letal_hits, 0, non_monster_vehicle_weapon_rule(WeaponRuleKind::letal_hits, 0).target_condition))
    if melee and orks_package(board, unit, OrksDetachment::bully_boyz) and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz)):
        result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    if !melee and orks_package(board, unit, OrksDetachment::shoota_boyz) and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry):
        result.append(weapon_rule(WeaponRuleKind::assault))
    if !melee:
        append_orks_effect_ability(board, model, RuleEffectKind::ranged_assault, WeaponRuleKind::assault, 0, result)
        append_orks_effect_ability(board, model, RuleEffectKind::ranged_lethal, WeaponRuleKind::letal_hits, 0, result)
        append_orks_effect_ability(board, model, RuleEffectKind::ranged_sustained, WeaponRuleKind::sustained_hit, 1, result)
        append_orks_effect_ability(board, model, RuleEffectKind::ranged_hazardous, WeaponRuleKind::hazardous, 0, result)
        append_orks_effect_ability(board, model, RuleEffectKind::vindictive_all, WeaponRuleKind::letal_hits, 0, result)
        append_orks_effect_ability(board, model, RuleEffectKind::vindictive_all, WeaponRuleKind::sustained_hit, 1, result)
        append_orks_effect_ability(board, model, RuleEffectKind::vindictive_all, WeaponRuleKind::hazardous, 0, result)
    else:
        append_orks_effect_ability(board, model, RuleEffectKind::melee_lethal, WeaponRuleKind::letal_hits, 0, result)
    if melee and unit_has_orks_enhancement(unit, OrksEnhancement::throat_slittas):
        result.append(non_monster_vehicle_weapon_rule(WeaponRuleKind::letal_hits, 0))
    if !melee and model_has_orks_enhancement(unit, model, OrksEnhancement::supa_glowy_fing):
        result.append(conditional_weapon_rule(WeaponRuleKind::anti, 4, Keyword::infantry))
        result.append(weapon_rule(WeaponRuleKind::devastating_wounds))
        result.append(weapon_rule(WeaponRuleKind::supa_hazardous))
    if !melee and unit_has_orks_enhancement(unit, OrksEnhancement::targetin_gizmos) and orks_carrier_has_passenger(board, model, true):
        result.append(weapon_rule(WeaponRuleKind::ignore_cover))
        if unit_is_riled_up(unit):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    if !melee and name.value == Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun.value:
        append_orks_effect_ability(board, model, RuleEffectKind::shokka_torrent, WeaponRuleKind::torrent, 0, result)
        append_orks_effect_ability(board, model, RuleEffectKind::shokka_sustained, WeaponRuleKind::sustained_hit, 2, result)
    # Source wording increases existing numeric instances instead of creating
    # a competing instance; apply increments to each before duplicate selection.
    if !melee and unit_has_orks_enhancement(unit, OrksEnhancement::supa_snazz_dakka) and name.value == Weapon::orks_flash_gitz_snazzgun_cutta.value:
        result.append(weapon_rule(WeaponRuleKind::rapid_fire, 1))
    for effect_index in range(model.rule_effects.size()):
        ref effect = model.rule_effects[effect_index]
        if !source_grant_active(board, effect.source_effect):
            continue
        if !melee and effect.kind.value == RuleEffectKind::rapid_fire_increment.value:
            increment_orks_weapon_ability(result, WeaponRuleKind::rapid_fire, effect.amount.value, effect.source_effect)
        if melee and effect.kind.value == RuleEffectKind::cleave_increment.value:
            increment_orks_weapon_ability(result, WeaponRuleKind::cleave, effect.amount.value, effect.source_effect)

# Close-range Dakka/Mow 'Em Down explicitly improve a printed numeric rule;
# the resulting instance keeps its condition and expiry key (Orks cards; p78).
fun increment_orks_weapon_ability(WeaponAbilitySet rules, WeaponRuleKind kind, Int increment, SourceEffectKey key):
    if increment == 0:
        return
    let found = false
    for rule_index in range(rules.size()):
        if rules[rule_index].kind == kind:
            assert(rules[rule_index].parameter_increment_source.value == 0, "only one friendly stratagem can improve this ability per phase")
            rules[rule_index].parameter_increment_source = key
            rules[rule_index].parameter_increment_amount = increment
            rules[rule_index].parameter = rules[rule_index].parameter.value + increment
            found = true
    if !found:
        let granted = weapon_rule(kind, increment)
        granted.source_effect = key
        rules.append(granted)

# Model/weapon arithmetic is inserted before core rounding/caps. Da Hunt is
# target-dependent and handled at gathered attack time, not as an aura.
fun append_orks_declaration_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    let bearer = declared_model_index(board, source, declaration)
    if bearer < 0:
        return
    ref unit = board[source]
    ref model = unit[bearer]
    let melee = declaration.weapon.range() == 0
    let addition = 0
    if melee and kind.value == ModifiedCharacteristic::armour_penetration.value and unit.has_charged and model_has_orks_enhancement(unit, model, OrksEnhancement::headwoppas_killchoppa):
        addition = addition - 1
    if melee and kind.value == ModifiedCharacteristic::attacks.value and model_has_orks_enhancement(unit, model, OrksEnhancement::ferocious_show_off):
        addition = addition + 1 + int(live_attachment_strength(unit) >= 11)
    if melee and kind.value == ModifiedCharacteristic::damage.value and model_has_orks_enhancement(unit, model, OrksEnhancement::brutal_but_kunnin):
        addition = addition + 1
    if !melee and kind.value == ModifiedCharacteristic::range.value:
        if orks_package(board, unit, OrksDetachment::shoota_boyz) and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry) and unit_is_riled_up(unit):
            addition = addition + 3
        if unit_has_orks_enhancement(unit, OrksEnhancement::targetin_squigs) and !declared_weapon_has_kind(declaration, WeaponRuleKind::torrent):
            addition = addition + 3
    if kind.value == ModifiedCharacteristic::attacks.value:
        if melee:
            addition = addition + unit_rule_effect(board, unit, RuleEffectKind::unbridled_attacks)
        addition = addition + unit_rule_effect(board, unit, RuleEffectKind::button_attacks)
        if !melee and declaration.weapon_name.value == Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun.family_id():
            addition = addition + model_rule_effect(board, model, RuleEffectKind::shokka_attacks)
    if kind.value == ModifiedCharacteristic::strength.value:
        addition = addition + 2 * unit_rule_effect(board, unit, RuleEffectKind::button_strength)
        if orks_package(board, unit, OrksDetachment::wurrband) and model.has_keyword(Keyword::orks) and model.has_keyword(Keyword::psyker) and declared_weapon_has_kind(declaration, WeaponRuleKind::psychic):
            addition = addition + 1 + orks_psychic_contributors(board, unit, model) / 5
    if kind.value == ModifiedCharacteristic::armour_penetration.value:
        addition = addition - unit_rule_effect(board, unit, RuleEffectKind::button_ap)
    if addition != 0:
        result.append(rule_modifier(ModifierOperation::add, addition))

# Gather all source-dependent effects before modifier caps and hit/wound
# classification; each hit contribution remains individually ignorable.
# Sources: Da Hunt is On, Skyborne Loons and the40 Orks source cards.
fun append_orks_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo info):
    info.squig_launcha_weapon = weapon.weapon_name.value == Weapon::orks_rukkatrukk_squigbuggies_squig_launchas.family_id()
    ref unit = board[source]
    ref victim = board[target]
    let bearer = declared_model_index(board, source, weapon)
    ref model = unit[bearer]
    let ranged = weapon.weapon.range() > 0
    append_orks_datasheet_attack_effects(board, source, target, weapon, info)
    if orks_package(board, unit, OrksDetachment::da_big_hunt) and unit.has_keyword(Keyword::beast_snagga) and (victim.has_keyword(Keyword::monster) or victim.has_keyword(Keyword::vehicle)):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::add, -1))
    if ranged and orks_package(board, unit, OrksDetachment::flyboyz) and unit_is_riled_up(unit) and unit.has_keyword(Keyword::orks) and (unit.has_keyword(Keyword::aircraft) or orks_type(unit, OrksDatasheet::deffkoptas)):
        info.attack_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if model_has_orks_enhancement(unit, model, OrksEnhancement::proper_killy) or unit_rule_effect(board, unit, RuleEffectKind::reroll_hits_ones) > 0:
        info.reroll1_hits = true
    if unit_rule_effect(board, unit, RuleEffectKind::reroll_hits_all) > 0:
        info.reroll_hits = true
    if unit_rule_effect(board, unit, RuleEffectKind::armed_to_da_teef) > 0:
        info.reroll1_hits = true
        info.reroll_hits = info.reroll_hits or unit_is_riled_up(unit)
    if ranged and orks_package(board, unit, OrksDetachment::wreckas) and orks_wrecka_unit(unit) and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player and (unit.history.wrecka_objective_selection or unit_in_any_objective_range(board, victim)):
        info.reroll1_hits = true
    if ranged:
        if unit_rule_effect(board, unit, RuleEffectKind::reroll_hits_fly) > 0 and victim.has_keyword(Keyword::fly):
            info.reroll_hits = true
        if unit_rule_effect(board, unit, RuleEffectKind::wound_bonus_non_monster_vehicle) > 0 and !victim.has_keyword(Keyword::monster) and !victim.has_keyword(Keyword::vehicle):
            info.attack_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if unit_rule_effect(board, unit, RuleEffectKind::close_range_ap) > 0 and live_unit_distance(unit, victim) <= 9.0:
            info.ap_modifiers.append(rule_modifier(ModifierOperation::add, -1))
        if weapon.borrowed_weapon and unit_rule_effect(board, unit, RuleEffectKind::deck_hit_bonus) > 0:
            info.attack_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if unit_rule_effect(board, unit, RuleEffectKind::hit_plus_one) > 0:
            info.attack_hit_modifiers.append(rule_modifier(ModifierOperation::add, unit_rule_effect(board, unit, RuleEffectKind::hit_plus_one)))
        if unit_rule_effect(board, victim, RuleEffectKind::all_wound_protection) > 0 or (unit_rule_effect(board, victim, RuleEffectKind::strong_wound_protection) > 0 and info.attack_strength() > info.target_toughness.value):
            info.attack_wound_modifiers.append(rule_modifier(ModifierOperation::add, -1))
        if victim.all_have_ability(AbilityKind::stealth):
            info.attack_hit_modifiers.append(rule_modifier(ModifierOperation::add, -1))
        info.fail_hits_up_to_three = unit_rule_effect(board, victim, RuleEffectKind::fail_hits_one_to_three) > 0
        if unit_rule_effect(board, victim, RuleEffectKind::lifted) > 0:
            info.target_has_cover = false
        else:
            info.target_has_cover = info.target_has_cover or orks_smoky_cover(board, model, victim)

# Intentional user-approved approximation: every noncircular footprint is a
# circle, and intervening circular bases stand in for model-body obscuration.
# Smoky Gubbinz uses partial cover only; this never blocks physical visibility.
fun orks_smoky_cover(Board board, Model observer, Unit target) -> Bool:
    if target.empty():
        return false
    for target_model in range(target.models.size()):
        let obscured = false
        for blocker_unit in range(board.units.size()):
            ref blockers = board.units[blocker_unit]
            if blockers.off_battlefield or !unit_has_orks_enhancement(blockers, OrksEnhancement::smoky_gubbinz):
                continue
            for blocker_model in range(blockers.models.size()):
                ref blocker = blockers[blocker_model]
                if !blocker.is_alive() or blocker.identity == observer.identity or blocker.identity == target[target_model].identity:
                    continue
                let distance = point_segment_distance_squared(float(blocker.position.x.value * MICROMETRES_PER_INCH), float(blocker.position.y.value * MICROMETRES_PER_INCH), float(observer.position.x.value * MICROMETRES_PER_INCH), float(observer.position.y.value * MICROMETRES_PER_INCH), float(target[target_model].position.x.value * MICROMETRES_PER_INCH), float(target[target_model].position.y.value * MICROMETRES_PER_INCH))
                obscured = obscured or distance <= blocker.base_radius_micrometres() * blocker.base_radius_micrometres()
        if !obscured:
            return false
    return true

# Kill Kommanda affects only its bearer while attached, not its bodyguards;
# Tellyporta's unit grant is separate. Orks Taktikal Brigade enhancement card.
fun orks_model_grants_ability(Unit unit, Model model, AbilityKind kind) -> Bool:
    return model.original_unit != unit.identity and component_source_active(unit, unit.identity) and model_has_orks_enhancement(unit, model, OrksEnhancement::kill_kommanda) and (kind == AbilityKind::infiltrators or kind == AbilityKind::stealth)

# Dreadherder grants the unit Lone Operative while within3in of a friendly
# non-Big-Mek ORKS Walker; offboard units cannot measure this distance.
fun orks_lone_operative(Board board, Unit unit) -> Bool:
    if orks_datasheet_lone_operative(board, unit) or unit.is_lone_operative() or orks_snagga_following(board, unit) or orks_shokka_supported(board, unit):
        return true
    if unit.off_battlefield or !unit.attached_units.empty() or !unit_has_orks_enhancement(unit, OrksEnhancement::dreadherder):
        return false
    for nearby in range(board.units.size()):
        ref walker = board.units[nearby]
        if !walker.off_battlefield and has_live_model(walker) and walker.owned_by_player1 == unit.owned_by_player1 and walker.has_keyword(Keyword::orks) and walker.has_keyword(Keyword::walker) and !walker.has_keyword(Keyword::big_mek) and orks_dreadherder_bearer_near(unit, walker):
            return true
    return false

# Attack bookkeeping follows actual hits and prevented wound loss; declaration
# alone cannot trigger Gun-crazy Show-offs/Goaded Into Action (Orks cards).
# A bounded activation serial distinguishes a unit destroyed by this attacking
# unit from an earlier casualty. This is identity infrastructure for Infested.
# A successful original roll is distinct from generated Sustained Hits. Grot
# Shields cancels only rolled hits, leaving the separately generated hits.
# Brute Force Warbosses roll3+, riled+1; paid Fight-on-Death cards roll4+,
# with riled+1 or Crazed Rampage's Deff Dread+3. Selection of their own unit
# to fight closes eligibility, even if individual models did not attack.
fun orks_fight_death_threshold(Board board, Unit unit, Model model) -> Int:
    if unit.has_fought or model.state == ModelState::fight_on_death:
        return 0
    let threshold = 0
    # Mozrog/One Last Kill: destroy-time2+ only in Fight before selection.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    if board.timing.phase == BattlePhase::fight and model.has_ability(AbilityKind::one_last_kill):
        threshold = 2
    if orks_package(board, unit, OrksDetachment::brute_bosses) and model.has_keyword(Keyword::warboss):
        threshold = 3 - int(unit_is_riled_up(unit))
    if board.timing.phase == BattlePhase::fight:
        if unit_rule_effect(board, unit, RuleEffectKind::fight_on_death_four) > 0:
            let card_threshold = 4 - int(unit_is_riled_up(unit))
            if threshold == 0 or threshold > card_threshold:
                threshold = card_threshold
        if unit_rule_effect(board, unit, RuleEffectKind::fight_on_death_dread) > 0:
            let dread_threshold = 4 - 3 * int(orks_type(unit, OrksDatasheet::deff_dread))
            if threshold == 0 or threshold > dread_threshold:
                threshold = dread_threshold
    return threshold

# Grot Shields uses a living Gretchin unit named by the accepted grant; losing
# its last battlefield model ends interception without changing the CP target.
fun orks_grot_shield(Board board, Unit unit) -> Int:
    for member in range(unit.models.size()):
        for effect in range(unit[member].rule_effects.size()):
            ref grant = unit[member].rule_effects[effect]
            if grant.kind.value == RuleEffectKind::grot_shield.value and source_grant_active(board, grant.source_effect):
                for grots in range(board.units.size()):
                    if board.units[grots].identity == grant.associated_unit and !board.units[grots].off_battlefield and has_live_model(board.units[grots]):
                        return grots
    return -1

# Dreadherder measures from its actual bearer, not a closer bodyguard. Its
# model Lone Operative remains subject to the unattached core rule (p83).
fun orks_dreadherder_bearer_near(Unit unit, Unit walker) -> Bool:
    for member in range(unit.models.size()):
        if model_has_orks_enhancement(unit, unit[member], OrksEnhancement::dreadherder) and live_distance_to_model(walker, unit[member]) <= 3.0:
            return true
    return false

# Reactions rely on the actual completed activation ledger and original enemy
# unit. Hit/lost-wound criteria are distinct, and the user's no-price scope
# does not erase CP expenditure or destroyed-target exceptions.
fun orks_post_attack_card_valid(Board board, UnitID attacker, UnitID target, Stratagem card, Bool melee) -> Bool:
    if target.get() >= board.units.size() or attacker.get() >= board.units.size():
        return false
    ref unit = board[target]
    let hit = false
    let lost = false
    let destroyed = false
    for record in range(board.attack_records.size()):
        if board.attack_records[record].target == unit.identity:
            hit = board.attack_records[record].successful_hits > 0
            lost = board.attack_records[record].wounds_lost > 0
            destroyed = board.attack_records[record].destroyed
    if !board.can_target_strat(unit.owned_by_player1, card, unit):
        return false
    if card == Stratagem::orks_infested_war_zone:
        return destroyed and unit.destroyed_attack == board.attack_serial and unit.owned_by_player1 != board[attacker].owned_by_player1 and orks_original_type(unit, OrksDatasheet::gretchin) and board.reserve_units.has_capacity()
    if melee or !(board.timing.phase == BattlePhase::shooting) or unit.off_battlefield or !has_live_model(unit):
        return false
    if card == Stratagem::orks_grab_it:
        return target.get() == attacker.get() and unit.owned_by_player1 == board.current_player and orks_wrecka_unit(unit) and !board.is_in_melee(unit)
    if unit.owned_by_player1 == board.current_player or unit.owned_by_player1 == board[attacker].owned_by_player1:
        return false
    if card == Stratagem::orks_gun_crazy_show_offs:
        return hit and (orks_type(unit, OrksDatasheet::flash_gitz) or orks_type(unit, OrksDatasheet::tankbustas)) and has_live_model(board[attacker]) and (shooting_kind_valid(board, target, ShootingKind::normal) or shooting_kind_valid(board, target, ShootingKind::assault) or shooting_kind_valid(board, target, ShootingKind::close_quarters) or shooting_kind_valid(board, target, ShootingKind::indirect))
    if card == Stratagem::orks_goaded_into_action:
        return lost and unit.has_keyword(Keyword::beast_snagga) and !board.is_in_melee(unit) and has_surge_target(board, target)
    return false

# A destroyed unit loses its live keyword union but its original datasheet
# remains in battle-start metadata. This helper is ONLY for destruction cards;
# ordinary attached keyword tests must still exclude extinct components (p67).
fun orks_original_type(Unit unit, OrksDatasheet kind) -> Bool:
    for member in range(unit.battle_start_models.value.size()):
        if model_matches_datasheet(unit.battle_start_models.value[member], kind):
            return true
    return false

# A selected beneficiary must offer an actual source card, not just have a
# ledger entry. Separate UnitID and Stratagem choices avoid a large product.
fun orks_post_attack_target_valid(Board board, UnitID attacker, UnitID target, Bool melee) -> Bool:
    return orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_infested_war_zone, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_grab_it, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_gun_crazy_show_offs, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_goaded_into_action, melee)

# No recursive Attack frame is stored inside an Attack. Gun-crazy returns a
# queued actor; the flat outer runner performs its ordinary shooting later.
act resolve_orks_post_attack(ctx Board board, frm UnitID attacker, frm Bool melee) -> OrksPostAttack:
    frm previous_owner = board.current_decision_maker
    frm reaction : ReactionAttackRequest
    frm owner = board.current_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = owner
        while orks_post_attack_owner_available(board, attacker, melee, owner):
            actions:
                act finish_orks_attack_reactions()
                    break
                act choose_orks_attack_reaction_unit(frm UnitID recipient) {orks_post_attack_target_valid(board, attacker, recipient, melee), board[recipient].owned_by_player1 == owner}
                    act choose_orks_attack_reaction_card(frm Stratagem card) {orks_post_attack_card_valid(board, attacker, recipient, card, melee)}
                    board.commit_stratagem(owner, card, board[recipient])
                    if card == Stratagem::orks_infested_war_zone:
                        create_orks_replacement(board, recipient)
                    if card == Stratagem::orks_grab_it:
                        grant_orks_effect(board, recipient, recipient, 300 + card.value, RuleEffectKind::no_charge, 1, SourceDuration::turn, invalid_entity_identity())
                        frm six : StatModifier
                        six = 6
                        board.shared_actions.granted_move = reactive_move(board, recipient, six, true)
                        subaction*(board) board.shared_actions.granted_move
                    if card == Stratagem::orks_gun_crazy_show_offs:
                        reaction.available = true
                        reaction.source = recipient
                        reaction.target = attacker
                        reaction.restrict_target = true
                    if card == Stratagem::orks_goaded_into_action:
                        board.current_roll = rerollable_dice_roll(board, unit_is_riled_up(board[recipient]), false, false, owner, recipient)
                        subaction*(board) board.current_roll
                        frm distance_result_snapshot_2 = board.current_roll.result
                        frm goad_distance : StatModifier
                        goad_distance = distance_result_snapshot_2.value
                        board.shared_actions.granted_move = surge(board, recipient, goad_distance, true)
                        subaction*(board) board.shared_actions.granted_move
                    board.current_decision_maker = owner
        owner = !owner
        controllers = controllers + 1
    board.current_decision_maker = previous_owner

# Exactly two controller groups follow Rules Sequencing. A destroyed source
# can still pay a destroyed-unit card through its retained metadata.
fun orks_post_attack_owner_available(Board board, UnitID attacker, Bool melee, Bool owner) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if board[target].owned_by_player1 == owner and orks_post_attack_target_valid(board, attacker, target, melee):
            return true
    return false

# Flat attack/reaction queue: every Gun-crazy use consumes the ordinary shared
# once-per-phase stratagem limit, so repeated reactions end by rule rather than
# an invented depth cutoff. Its sole target is the enemy unit that just shot.
# Unpredictable Genius triggers only when all declared ranged attacks share
# one target. Multiple-target declarations remain legal and do NOT trigger it.
# Madcap Meks source; target declarations/core grouping pp16-17.

# The actual selected source keywords, not profile names or a guessed legacy
# Big Mek factory, determine whether the table roll is required.
fun orks_madcap_actor(Board board, Unit unit) -> Bool:
    return orks_package(board, unit, OrksDetachment::madcap_meks) and unit.owned_by_player1 == board.current_player and board.timing.phase == BattlePhase::shooting and (unit.has_keyword(Keyword::big_mek) or orks_type(unit, OrksDatasheet::mek_gunz) or orks_type(unit, OrksDatasheet::morkanaut) or orks_type(unit, OrksDatasheet::wazbom_blastajet))

# Hop Splat selects an OTHER enemy within3in of the chosen target. No eligible
# other enemy means no selection/damage; no original-target substitution.
fun orks_hop_splat_target(Board board, UnitID source, UnitID target, UnitID other) -> Bool:
    return other.get() < board.units.size() and other.get() != target.get() and orks_support_actor(board, other, !board[source].owned_by_player1) and live_unit_distance(board[target], board[other]) <= 3.0

# Scoped grants cease after this shooting activation, rather than at phase
# end. Their keys are returned to the caller for precise overlapping expiry.
act orks_unpredictable_genius(ctx Board board, frm UnitID source, frm UnitID target) -> OrksUnpredictableGenius:
    frm effect : SourceEffectKey
    if !orks_madcap_actor(board, board[source]):
        return
    act roll(Dice genius_face)
    if genius_face == 1:
        grant_orks_effect(board, source, target, 470, RuleEffectKind::invulnerable_save, 4, SourceDuration::phase, invalid_entity_identity())
        effect = board.next_source_effect
    if genius_face == 4:
        grant_orks_effect(board, source, source, 470, RuleEffectKind::hit_plus_one, 1, SourceDuration::phase, invalid_entity_identity())
        effect = board.next_source_effect
    if genius_face == 5:
        grant_orks_effect(board, source, target, 470, RuleEffectKind::lifted, 1, SourceDuration::phase, invalid_entity_identity())
        effect = board.next_source_effect
    if genius_face == 6:
        grant_orks_payload(board, source, target, 470, characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, -1), SourceDuration::phase)
        effect = board.next_source_effect
    if genius_face == 2 or genius_face == 3:
        frm other_available = false
        let other : UnitID
        for slot in range(board.units.size()):
            other = slot
            other_available = other_available or orks_hop_splat_target(board, source, target, other)
        if other_available:
            act choose_hop_splat_target(frm UnitID splash_target) {orks_hop_splat_target(board, source, target, splash_target)}
            board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
            subaction* board.shared_actions.evaluate_random_stat
            frm damage_result_snapshot_1 = board.shared_actions.evaluate_random_stat.result
            frm amount : CombatCounter
            amount = damage_result_snapshot_1.value
            board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, splash_target, source, true, amount)
            subaction*(board) board.shared_actions.resolve_mortal_wounds

# Temperamental Shokka is optional once at this selection and affects its
# actual bearer; each branch keeps chance input explicit (source upgrade).
act orks_shokka_selection(ctx Board board, frm UnitID source) -> OrksShokkaSelection:
    frm member_index : ModelIterator
    while member_index.value < board[source].models.size():
        if model_has_orks_enhancement(board[source], board[source][member_index.value], OrksEnhancement::temperamental_shokka):
            frm bearer : ModelID
            bearer = member_index.value
            actions:
                act decline_temperamental_shokka()
                act temperamental_shokka()
                    act roll(Dice shokka_face)
                    frm kind : RuleEffectKind
                    kind = RuleEffectKind::shokka_attacks
                    if shokka_face == 1:
                        kind = RuleEffectKind::shokka_torrent
                        grant_orks_model_effect(board, source, bearer, 480, RuleEffectKind::shokka_destroy)
                    if shokka_face == 6:
                        kind = RuleEffectKind::shokka_sustained
                    grant_orks_model_effect(board, source, bearer, 481, kind)
        member_index = member_index + 1

# Enhanced Runt-maw chooses an enemy actually hit by the unit's attacks. Its
# Leadership ROLL penalty persists until next own turn, never alters Ld stats.
fun orks_runt_maw_target(Board board, UnitID source, UnitID target) -> Bool:
    if target.get() >= board.units.size() or !orks_support_actor(board, target, !board[source].owned_by_player1):
        return false
    for record in range(board.attack_records.size()):
        if board.attack_records[record].target == board[target].identity and board.attack_records[record].successful_hits > 0:
            return true
    return false

# Model destruction bypasses wound prevention, then runs ordinary destruction
# triggers. It is not damage, and cannot retroactively add weapon Hazardous.
act orks_shooting_option_end(ctx Board board, frm UnitID source) -> OrksShootingOptionEnd:
    subaction*(board) barrage = orks_rokkit_barrage(board, source)
    if unit_has_orks_enhancement(board[source], OrksEnhancement::enhanced_runt_maw):
        frm target_available = false
        let target : UnitID
        for slot in range(board.units.size()):
            target = slot
            target_available = target_available or orks_runt_maw_target(board, source, target)
        if target_available:
            act choose_runt_maw_target(frm UnitID snotlings) {orks_runt_maw_target(board, source, snotlings)}
            grant_orks_effect(board, source, snotlings, 200 + OrksEnhancement::enhanced_runt_maw.value, RuleEffectKind::snotling_leadership_penalty, 1, SourceDuration::next_own_turn, invalid_entity_identity())
    frm member_index : ModelIterator
    while member_index.value < board[source].models.size():
        if board[source][member_index.value].is_alive() and model_rule_effect(board, board[source][member_index.value], RuleEffectKind::shokka_destroy) > 0:
            frm bearer : ModelID
            bearer = member_index.value
            frm identity = board[source][bearer].identity
            let job = damage_job(DamageKind::normal, source, source, false, false, board[source][bearer].wounds_left(), identity)
            commit_wound_loss(board, job, bearer, board[source][bearer].wounds_left(), false)
            frm jobs : DamageJobs
            board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, source)
            subaction*(board) board.shared_actions.resolve_damage_jobs
            let remaining = board[source].find_model(identity)
            if remaining >= 0:
                member_index = remaining + 1
        else:
            member_index = member_index + 1

# Dreadherder's Shooting-phase selection is conditional on its bearer being
# within3in of a friendly non-Big-Mek ORKS Walker. The selected Walker may be
# Big Mek; the exclusion belongs to the preceding proximity clause, not target.
fun orks_dreadherder_target(Board board, UnitID source, UnitID target) -> Bool:
    if target.get() >= board.units.size() or !orks_support_actor(board, target, board[source].owned_by_player1) or !board[target].has_keyword(Keyword::orks) or !board[target].has_keyword(Keyword::walker):
        return false
    for bearer in range(board[source].models.size()):
        ref model = board[source][bearer]
        if model_has_orks_enhancement(board[source], model, OrksEnhancement::dreadherder):
            let proximate = false
            for nearby in range(board.units.size()):
                ref walker = board.units[nearby]
                if !walker.off_battlefield and has_live_model(walker) and walker.owned_by_player1 == board[source].owned_by_player1 and walker.has_keyword(Keyword::orks) and walker.has_keyword(Keyword::walker) and !walker.has_keyword(Keyword::big_mek) and live_distance_to_model(walker, model) <= 3.0:
                    proximate = true
            if proximate and live_distance_to_model(board[target], model) <= 3.0:
                return true
    return false

# One selection per phase belongs to this ability's printed phase period;
# its accepted hit-reroll grant lasts through the TURN, including Fight.
act orks_dreadherder_shooting(ctx Board board, frm UnitID source) -> OrksDreadherderShooting:
    frm previous_owner = board.current_decision_maker
    if !orks_support_actor(board, source, board.current_player) or !(board.timing.phase == BattlePhase::shooting):
        return
    board.current_decision_maker = board[source].owned_by_player1
    frm available = false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        available = available or orks_dreadherder_target(board, source, target)
    frm usage : SourceInstance
    usage.rule = 200 + OrksEnhancement::dreadherder.value
    usage.owner = board[source].owned_by_player1
    usage.source_unit = board[source].identity
    usage.use_scope = SourceUseScope::unit
    usage.limits.phase = 1
    if available and source_usage_available(board, usage):
        actions:
            act decline_dreadherder()
            act choose_dreadherder_target(frm UnitID walker) {orks_dreadherder_target(board, source, walker)}
                commit_source_usage(board, usage)
                grant_orks_effect(board, source, walker, 200 + OrksEnhancement::dreadherder.value, RuleEffectKind::reroll_hits_ones, 1, SourceDuration::turn, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Dreadherder can be used before other units shoot; selecting its bearer to
# shoot is not required and must not consume the bearer's shooting opportunity.
fun orks_dreadherder_available(Board board, UnitID source) -> Bool:
    if !orks_support_actor(board, source, board.current_player) or !(board.timing.phase == BattlePhase::shooting):
        return false
    let usage : SourceInstance
    usage.rule = 200 + OrksEnhancement::dreadherder.value
    usage.owner = board[source].owned_by_player1
    usage.source_unit = board[source].identity
    usage.use_scope = SourceUseScope::unit
    usage.limits.phase = 1
    if !source_usage_available(board, usage):
        return false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_dreadherder_target(board, source, target):
            return true
    return false

# Non-stacking live aura: same named ability contributes once. The source
# unit itself qualifies; offboard units cannot measure to others (01.02.04).
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun orks_prophet_aura(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !unit.has_keyword(Keyword::orks):
        return false
    for source in range(board.units.size()):
        ref actor = board[source]
        if !actor.off_battlefield and actor.owned_by_player1 == unit.owned_by_player1 and actor.has_ability(AbilityKind::prophet_waaagh) and live_unit_distance(actor, unit) <= 6.0:
            return true
    return false

# Each Wartrakk model needs a qualifying neighbouring Speed Freeks unit;
# Ghaz requires ANOTHER friendly Infantry unit. Neither can use reserve ranges.
# Sources: Orks/Wartrakks Speednob Support; Ghazghkull-Thraka Da Grand Warlord's Ladz.
fun orks_datasheet_lone_operative(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !has_live_model(unit):
        return false
    if unit.has_ability(AbilityKind::grand_warlords_ladz):
        for ally in range(board.units.size()):
            ref nearby = board[ally]
            if nearby.identity != unit.identity and !nearby.off_battlefield and has_live_model(nearby) and nearby.owned_by_player1 == unit.owned_by_player1 and nearby.has_keyword(Keyword::orks) and nearby.has_keyword(Keyword::infantry) and live_unit_distance(unit, nearby) <= 3.0:
                return true
    if unit.has_ability(AbilityKind::speednob_support):
        let all_supported = true
        for member_index in range(unit.models.size()):
            if !unit[member_index].is_alive():
                continue
            let supported = false
            for ally in range(board.units.size()):
                ref nearby = board[ally]
                supported = supported or (!nearby.off_battlefield and has_live_model(nearby) and nearby.owned_by_player1 == unit.owned_by_player1 and nearby.has_keyword(Keyword::speed_freeks) and !orks_type(nearby, OrksDatasheet::wartrakks) and live_distance_to_model(nearby, unit[member_index]) <= 3.0)
            all_supported = all_supported and supported
        return all_supported
    return false

# Fortification's explicit ranged-target exception applies only to an enemy
# engaged exclusively with Fortification units, with a live conferring bunker.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
fun orks_engaged_only_fortifications(Board board, Unit unit) -> Bool:
    let found = false
    for enemy in range(board.units.size()):
        ref foe = board[enemy]
        if foe.owned_by_player1 != unit.owned_by_player1 and !foe.off_battlefield and has_live_model(foe) and unit.is_engaged_with(foe):
            if !foe.has_keyword(Keyword::fortification):
                return false
            found = found or foe.has_ability(AbilityKind::fortification_rules)
    return found

# User-approved abstraction: a circular bunker base crossing the centre sight
# segment gives partial obscuration. Exact hull silhouettes remain deferred.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka (Ramshackle Cover).
fun orks_ramshackle_obscures(Board board, Model observer, Model target) -> Bool:
    for bunker in range(board.units.size()):
        ref source = board[bunker]
        if source.off_battlefield or !source.has_ability(AbilityKind::ramshackle_cover):
            continue
        for member_index in range(source.models.size()):
            ref obstacle = source[member_index]
            if !obstacle.is_alive() or obstacle.identity == observer.identity or obstacle.identity == target.identity:
                continue
            let radius = obstacle.base_radius_micrometres()
            if point_segment_distance_squared(float(obstacle.position.x.value * MICROMETRES_PER_INCH), float(obstacle.position.y.value * MICROMETRES_PER_INCH), float(observer.position.x.value * MICROMETRES_PER_INCH), float(observer.position.y.value * MICROMETRES_PER_INCH), float(target.position.x.value * MICROMETRES_PER_INCH), float(target.position.y.value * MICROMETRES_PER_INCH)) <= radius * radius:
                return true
    return false

# Wobbled is on the attacking unit; benefit of cover belongs to its targets.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz (Bubblechukka).
fun orks_wobbled_observer(Board board, Model observer) -> Bool:
    for unit_index in range(board.units.size()):
        if board[unit_index].find_model(observer.identity) >= 0:
            return unit_rule_effect(board, board[unit_index], RuleEffectKind::wobbled) > 0
    return false

# Post-shot effects share one chosen-target action, with eligibility based on
# successful hits. Squig Launchas provenance is separate from other weapons.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Mek-Gunz,Wartrakks,Rukkatrukk-Squigbuggies}
fun orks_hit_effect_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    if !orks_barrage_target_valid(board, source, target):
        return false
    if board[source].has_ability(AbilityKind::squig_barrage):
        if board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle):
            return false
        for record in range(board.attack_records.size()):
            if board.attack_records[record].target == board[target].identity and board.attack_records[record].tagged_hits[AttackHitTag::squig_launcha.value].value > 0:
                return true
        return false
    return true

# Each surviving Mek Gunz model must have the same ranged WEAPON NAME.
# Different profiles of one weapon are not different equipment (04.01.03).
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz (Madcap Artillery).
fun orks_matching_mek_guns(Unit unit) -> Int:
    let family = -1
    for member_index in range(unit.models.size()):
        if !unit[member_index].is_alive() or !model_matches_datasheet(unit[member_index], OrksDatasheet::mek_gunz):
            continue
        for slot in range(unit[member_index].weapons.size()):
            if unit[member_index].weapons[slot].profile.range() == 0:
                continue
            if family >= 0 and family != unit[member_index].weapons[slot].profile.family_id():
                return -1
            family = unit[member_index].weapons[slot].profile.family_id()
    return family

# The attack owns this frame; normal target choice precedes weapon Hazardous
# checks, preserving hit provenance when the firing model later dies (p81).
# Sources: Orks/Mek-Gunz Madcap Artillery; Wartrakks Bust 'Em; Squig Barrage.
act orks_resolve_hit_effects(ctx Board board, frm UnitID source) -> OrksHitEffects:
    if !has_live_model(board[source]) or !(board[source].has_ability(AbilityKind::madcap_artillery) or board[source].has_ability(AbilityKind::bust_em) or board[source].has_ability(AbilityKind::squig_barrage)):
        return
    if board[source].has_ability(AbilityKind::madcap_artillery) and orks_matching_mek_guns(board[source]) < 0:
        return
    frm available = false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        available = available or orks_hit_effect_target_valid(board, source, target)
    if !available:
        return
    act choose_datasheet_hit_target(frm UnitID victim) {orks_hit_effect_target_valid(board, source, victim)}
    if board[source].has_ability(AbilityKind::squig_barrage):
        grant_orks_effect(board, source, victim, 156, RuleEffectKind::covered_squigs, 1, SourceDuration::next_own_turn, invalid_entity_identity())
    if board[source].has_ability(AbilityKind::bust_em):
        grant_orks_effect(board, source, victim, 157, RuleEffectKind::busted, 1, SourceDuration::turn, invalid_entity_identity())
    if board[source].has_ability(AbilityKind::madcap_artillery):
        frm gun : WeaponCode
        gun = orks_matching_mek_guns(board[source])
        if gun.value == Weapon::orks_mek_gunz_bubblechukka.value:
            grant_orks_effect(board, source, victim, 158, RuleEffectKind::wobbled, 1, SourceDuration::next_own_turn, invalid_entity_identity())
        if gun.value == Weapon::orks_mek_gunz_traktor_kannon.value:
            grant_orks_effect(board, source, victim, 159, RuleEffectKind::grounded, 1, SourceDuration::next_own_turn, invalid_entity_identity())
        if gun.value == Weapon::orks_mek_gunz_smasha_gun.value:
            grant_orks_payload(board, source, victim, 160, characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::subtract, 2), SourceDuration::next_own_turn)
        if gun.value == Weapon::orks_mek_gunz_kustom_mega_kannon.value:
            grant_orks_payload(board, source, victim, 161, characteristic_modifier(ModifiedCharacteristic::leadership, ModifierOperation::add, 1), SourceDuration::next_own_turn)

# Warpath is chosen at SelectedFight BEFORE Pile In/Overrun. The shared roll
# spends the same level budget used by any other psychic ability this round.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Weirdboy,Kill-Rig}
act orks_datasheet_fight_selection(ctx Board board, frm UnitID source) -> OrksDatasheetFightSelection:
    frm rule : BInt<151, 163>
    rule = 152
    if board[source].has_ability(AbilityKind::kill_rig_warpath):
        rule = 153
    if orks_datasheet_psychic_available(board, source, rule.value):
        act use_datasheet_warpath(Bool warpath)
        if warpath:
            board.shared_actions.orks_psychic_test = orks_datasheet_psychic(board, source, rule)
            subaction*(board) board.shared_actions.orks_psychic_test
            frm kind = RuleEffectKind::weirdboy_warpath
            if rule.value == 153:
                kind = RuleEffectKind::psychic_warpath
            if has_live_model(board[source]):
                grant_orks_effect(board, source, source, rule.value, kind, 1, SourceDuration::phase, invalid_entity_identity())

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
        grant_orks_model_effect(board, source, bearer, 114, RuleEffectKind::boss_ammo_hit)
    else:
        grant_orks_effect(board, source, source, 113, RuleEffectKind::ammo_runts_hit, 1, SourceDuration::phase, invalid_entity_identity())

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
            grant_orks_effect(board, source, source, 115, RuleEffectKind::rokkit_charge, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Boyz charge permission includes every melee weapon of the attached unit.
# Dakkarig's riled ability applies only to ranged attacks; Rokkit Charge's
# Hazardous is acquired before selected physical weapons are counted (p81).
# Sources: Orks/Boyz Tide of Muscle, Big-Mek-Dakkarig, Stormboyz.
fun append_orks_datasheet_weapon_rules(Board board, UnitID source, Weapon selected, WeaponAbilitySet result):
    ref unit = board[source]
    # Big Mek's More Dakka is unit-wide; Mek's Kustom Dakka lacks Sustained Hits.
    # https://wahapedia.ru/wh40k11ed/factions/orks/{Big-Mek,Mek}
    if selected.range() > 0:
        if unit.has_ability(AbilityKind::more_dakka) or unit.has_ability(AbilityKind::kustom_dakka):
            result.append(weapon_rule(WeaponRuleKind::ignore_cover))
        if unit.has_ability(AbilityKind::more_dakka) and unit_is_riled_up(unit):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    # Unit-wide intrinsic/granted rules are read at declaration. Psychic Warpath
    # does not grant the same bonus to ranged attacks (source cards;04.01.03).
    # https://wahapedia.ru/wh40k11ed/factions/orks/{Nazdreg,Kill-Rig,Weirdboy}
    if selected.range() > 0 and unit.has_ability(AbilityKind::nazdregs_know_wotz):
        result.append(weapon_rule(WeaponRuleKind::ignore_cover))
    if selected.range() == 0:
        if unit_rule_effect(board, unit, RuleEffectKind::psychic_warpath) > 0:
            result.append(weapon_rule(WeaponRuleKind::letal_hits))
        if unit_rule_effect(board, unit, RuleEffectKind::psychic_warpath) > 0 or unit_rule_effect(board, unit, RuleEffectKind::weirdboy_warpath) > 0:
            result.append(weapon_rule(WeaponRuleKind::psychic))
    if selected.range() == 0:
        if unit.has_charged and unit.has_ability(AbilityKind::tide_of_muscle):
            result.append(weapon_rule(WeaponRuleKind::letal_hits))
        if unit_rule_effect(board, unit, RuleEffectKind::rokkit_charge) > 0:
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
    # Super Runts improves only Scavenged Shivs, including the inverse numeric
    # direction of WS. Its riled permission is registered by the existing passive
    # source engine and is lost/restored with the actual Zodgrod source.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
    if unit.has_ability(AbilityKind::super_runts) and declaration.weapon_name.value == Weapon::orks_gretchin_scavenged_shivs.family_id():
        if kind.value == ModifiedCharacteristic::attacks.value or kind.value == ModifiedCharacteristic::strength.value:
            result.append(rule_modifier(ModifierOperation::add, 1))
        if kind.value == ModifiedCharacteristic::weapon_skill.value:
            result.append(rule_modifier(ModifierOperation::subtract, 1))
    # Butchery counts actual embarked models, not transport seats, caps at+22,
    # and changes only the Butcha Boyz weapon (not its two Extra Attacks weapons).
    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    if kind.value == ModifiedCharacteristic::attacks.value and board[source].has_ability(AbilityKind::fully_loaded_butchery) and declaration.weapon_name.value == Weapon::orks_hunta_rig_butcha_boyz.family_id():
        let passenger_count = 0
        for passenger_bearer_index in range(board[source].models.size()):
            if board[source][passenger_bearer_index].is_alive():
                passenger_count = passenger_count + embarked_models_for_psyker(board, board[source][passenger_bearer_index].identity)
        result.append(rule_modifier(ModifierOperation::add, min(22, passenger_count * 2)))
    let addition = 0
    if declaration.weapon.range() == 0:
        if unit.has_charged and model.has_ability(AbilityKind::might_is_right):
            if kind.value == ModifiedCharacteristic::attacks.value:
                addition = addition + 3
            if kind.value == ModifiedCharacteristic::strength.value:
                addition = addition + 2
        if unit.has_charged and unit.has_ability(AbilityKind::high_speed_carnage) and (kind.value == ModifiedCharacteristic::strength.value or kind.value == ModifiedCharacteristic::damage.value):
            addition = addition + 1
        if unit_rule_effect(board, unit, RuleEffectKind::rokkit_charge) > 0 and (kind.value == ModifiedCharacteristic::attacks.value or kind.value == ModifiedCharacteristic::strength.value):
            addition = addition + 1
    else:
        if kind.value == ModifiedCharacteristic::attacks.value and declaration.weapon_name.value == Weapon::orks_blitzkannon.family_id() and model.has_ability(AbilityKind::blitz_dem_gitz) and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player:
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
    # Contributions enter the existing characteristic/cap/ignore pipeline.
    # AP is improved by subtracting, worsened by adding; duplicates of the same
    # unit ability do not multiply. Distinct repair modifiers remain cumulative.
    # Sources: Orks/Flash-Gitz, Meganobz, Painboss, Mek, Tankbustas.
    ref unit = board[source]
    ref victim = board[target]
    let bearer = declared_model_index(board, source, declaration)
    if declaration.weapon.range() > 0 and unit.has_ability(AbilityKind::finderz_keeperz) and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player and (unit_in_any_objective_range(board, unit) or unit_in_any_objective_range(board, victim)):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if victim.has_ability(AbilityKind::arrogant_invulnerability):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if victim.has_ability(AbilityKind::hardy_bioniks):
        info.greater_strenght_wound_protection = true
    if declaration.weapon.range() == 0 and board.timing.phase == BattlePhase::fight and unit.has_ability(AbilityKind::krumpin_time) and unit_is_riled_up(unit):
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if bearer >= 0:
        for repair_index in range(unit[bearer].rule_effects.size()):
            ref repair = unit[bearer].rule_effects[repair_index]
            if repair.kind.value == RuleEffectKind::clever_hit.value and source_grant_active(board, repair.source_effect):
                info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, max(1, repair.amount.value)))
    if orks_pulsa_applies(board, unit, victim.identity):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
        info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::letal_hits))
    # Target-dependent modifiers keep their original operations and separate hit
    # contributions so the standard cap/ignore/grouping machinery still applies.
    # Sources: Orks/{Battlewagon,Dakkajet,Deffkoptas,Ghazghkull-Thraka,Gorkanaut,
    # Gunwagon,Morkanaut,Kommandos,Wazbom-Blastajet,Mek-Gunz,Wartrakks,Kill-Rig}.
    let ranged = declaration.weapon.range() > 0
    let own_shooting = ranged and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player
    let monster_vehicle = victim.has_keyword(Keyword::monster) or victim.has_keyword(Keyword::vehicle)
    if ranged and victim.has_ability(AbilityKind::mobile_fortress):
        info.damage_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if own_shooting and unit.has_ability(AbilityKind::strafing_run) and !victim.has_keyword(Keyword::fly):
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if own_shooting and unit.has_ability(AbilityKind::deff_from_above) and unit.history.has_ingressed and unit.history.ingress_turn == board.turn_serial.value + 1:
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if own_shooting and (unit.has_ability(AbilityKind::mobile_arsenal) or unit.has_ability(AbilityKind::big_an_shooty)) or !ranged and unit.has_ability(AbilityKind::big_an_stompy):
        info.reroll1_hits = true
    if own_shooting and monster_vehicle and unit.has_ability(AbilityKind::weak_spot):
        info.attack_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if !ranged and orks_prophet_aura(board, unit):
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        info.attack_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if unit.has_ability(AbilityKind::nowhere_to_hide) and unit_is_hidden(board, victim):
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if unit_rule_effect(board, unit, RuleEffectKind::covered_squigs) > 0:
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if unit_rule_effect(board, victim, RuleEffectKind::pulse_defence) > 0:
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if ranged and orks_engaged_only_fortifications(board, victim) and info.shooting_kind.value != ShootingKind::close_quarters.value:
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if ranged and unit_rule_effect(board, victim, RuleEffectKind::burna_mark) > 0:
        info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::ignore_cover))
    if unit_rule_effect(board, victim, RuleEffectKind::busted) > 0 and unit.has_keyword(Keyword::speed_freeks) and unit.owned_by_player1 != victim.owned_by_player1:
        info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::letal_hits))
    if unit_rule_effect(board, unit, RuleEffectKind::beastscent) > 0 and monster_vehicle:
        info.attack_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if !ranged and unit_rule_effect(board, unit, RuleEffectKind::weirdboy_warpath) > 0:
        info.reroll1_wounds = true
    ref model = unit[bearer]
    if declaration.weapon.range() == 0:
        if unit.has_ability(AbilityKind::sumfin_to_prove):
            info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if declaration.weapon.value == Weapon::orks_paired_krumpas.value:
            info.reroll_hits = true
            info.reroll_wounds = true
        if unit.has_ability(AbilityKind::da_bigger_dey_iz) and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)):
            info.reroll_wounds = true
    else:
        if unit_rule_effect(board, unit, RuleEffectKind::ammo_runts_hit) > 0:
            info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if model_rule_effect(board, model, RuleEffectKind::boss_ammo_hit) > 0:
            info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if orks_type(unit, OrksDatasheet::killa_kans) and !orks_target_has_toughness_seven(board[target]):
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))

# Literal selection windows for source cards. Ranged cards say YOUR Shooting
# phase; Fight cards apply in either player's Fight phase. Unit CP targeting
# and package ownership are still the shared p54 policy.
fun orks_selected_stratagem_valid(Board board, UnitID actor, Stratagem strat, Bool melee) -> Bool:
    if actor.get() >= board.units.size() or !board.can_target_strat(board[actor].owned_by_player1, strat, board[actor]):
        return false
    ref unit = board[actor]
    let own_shooting = !melee and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player
    let fighting = melee and board.timing.phase == BattlePhase::fight
    if strat == Stratagem::orks_hit_em_harder:
        return fighting and unit.has_keyword(Keyword::orks)
    if strat == Stratagem::orks_mow_em_down:
        return fighting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::vehicle) and !unit.has_keyword(Keyword::walker) and unit.has_charged
    if strat == Stratagem::orks_close_range_dakka:
        return own_shooting and unit.has_keyword(Keyword::orks)
    if strat == Stratagem::orks_unbridled_carnage:
        return fighting and orks_type(unit, OrksDatasheet::boyz) and unit.has_charged
    if strat == Stratagem::orks_armed_to_da_teef:
        return (fighting or own_shooting) and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz))
    if strat == Stratagem::orks_kustom_dakka or strat == Stratagem::orks_glowin_dakka or strat == Stratagem::orks_never_enough_dakka:
        return own_shooting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry)
    if strat == Stratagem::orks_drive_by_bustin:
        return own_shooting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::transport)
    if strat == Stratagem::orks_vindictive_artillerists:
        return own_shooting and orks_type(unit, OrksDatasheet::mek_gunz)
    if strat == Stratagem::orks_dakkastorm:
        return own_shooting and unit.has_keyword(Keyword::speed_freeks)
    if strat == Stratagem::orks_long_uncontrolled_bursts:
        return own_shooting and unit.has_keyword(Keyword::orks) and (unit.has_keyword(Keyword::aircraft) or orks_type(unit, OrksDatasheet::deffkoptas))
    return false

# Expose a source enum only when an actual card fits this activation. Keeping
# absent hooks automatic avoids spurious decline inputs in ordinary attacks.
fun orks_selected_stratagem_remaining(Board board, UnitID actor, Bool melee) -> Bool:
    let strat : Stratagem
    for card in range(max(strat) + 1):
        strat.value = card
        if orks_selected_stratagem_valid(board, actor, strat, melee):
            return true
    return false

# Each accepted effect pays CP BEFORE resolution and uses a keyed source grant;
# its default lifetime is this phase unless the source states otherwise (01.02.02).
act orks_attack_selection(ctx Board board, frm UnitID actor, frm Bool melee) -> OrksAttackSelection:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[actor].owned_by_player1
    while orks_selected_stratagem_remaining(board, actor, melee):
        actions:
            act finish_orks_attack_selection()
                break
            act choose_orks_attack_stratagem(frm Stratagem selected_card) {orks_selected_stratagem_valid(board, actor, selected_card, melee)}
                board.commit_stratagem(board[actor].owned_by_player1, selected_card, board[actor])
                frm effect : RuleEffectKind
                effect = RuleEffectKind::melee_lethal
                if selected_card == Stratagem::orks_mow_em_down:
                    effect = RuleEffectKind::cleave_increment
                if selected_card == Stratagem::orks_close_range_dakka:
                    effect = RuleEffectKind::rapid_fire_increment
                if selected_card == Stratagem::orks_unbridled_carnage:
                    # The melee-only addition is gathered per selected weapon.
                    effect = RuleEffectKind::unbridled_attacks
                if selected_card == Stratagem::orks_armed_to_da_teef:
                    effect = RuleEffectKind::armed_to_da_teef
                if selected_card == Stratagem::orks_kustom_dakka:
                    effect = RuleEffectKind::wound_bonus_non_monster_vehicle
                if selected_card == Stratagem::orks_glowin_dakka:
                    effect = RuleEffectKind::close_range_ap
                if selected_card == Stratagem::orks_never_enough_dakka or selected_card == Stratagem::orks_dakkastorm:
                    effect = RuleEffectKind::ranged_sustained
                if selected_card == Stratagem::orks_drive_by_bustin:
                    effect = RuleEffectKind::deck_hit_bonus
                if selected_card == Stratagem::orks_long_uncontrolled_bursts:
                    effect = RuleEffectKind::reroll_hits_fly
                if selected_card == Stratagem::orks_vindictive_artillerists:
                    act choose_artillerist_mode(frm OrksArtilleristMode mode)
                    effect = RuleEffectKind::ranged_lethal
                    if mode.value == OrksArtilleristMode::sustained.value:
                        effect = RuleEffectKind::ranged_sustained
                    if mode.value == OrksArtilleristMode::both_hazardous.value:
                        effect = RuleEffectKind::vindictive_all
                grant_orks_effect(board, actor, actor, 300 + selected_card.value, effect, 1, SourceDuration::phase, invalid_entity_identity())
    # Dread Mob is optional, separate from CP targeting and not blocked by shock.
    if (melee and board.timing.phase == BattlePhase::fight or !melee and board.timing.phase == BattlePhase::shooting and board[actor].owned_by_player1 == board.current_player) and orks_package(board, board[actor], OrksDetachment::dread_mob) and board[actor].has_keyword(Keyword::orks) and board[actor].has_keyword(Keyword::walker) and !board[actor].has_keyword(Keyword::titanic):
        actions:
            act decline_try_dat_button()
            act choose_button_dice(frm Bool two_dice)
                frm first_button : Dice
                act roll(Dice button_face)
                first_button = button_face
                apply_orks_button(board, actor, button_face)
                if two_dice:
                    frm second_button : Dice
                    second_button = first_button
                    while second_button.value == first_button.value:
                        act roll(Dice other_button)
                        second_button = other_button
                    apply_orks_button(board, actor, second_button)
                    grant_orks_effect(board, actor, actor, 410, RuleEffectKind::button_hazard, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Every distinct die supplies its relevant cumulative characteristic addition;
# only identical D6 faces repeat (Try Dat Button!, not identical table bands).
fun apply_orks_button(Board board, UnitID actor, Dice face):
    let effect = RuleEffectKind::button_attacks
    if face.value >= 3 and face.value <= 4:
        effect = RuleEffectKind::button_strength
    if face.value >= 5:
        effect = RuleEffectKind::button_ap
    grant_orks_effect(board, actor, actor, 410 + face.value, effect, 1, SourceDuration::phase, invalid_entity_identity())

# Defensive cards trigger for the actual targeted unit, not a guessed initial
# target before declarations. Grot Shields selects a DIFFERENT CP target below.
fun orks_targeted_stratagem_valid(Board board, UnitID source, UnitID target, Stratagem strat, Bool melee) -> Bool:
    if source.get() >= board.units.size() or target.get() >= board.units.size() or board[source].owned_by_player1 == board[target].owned_by_player1 or !board.can_target_strat(board[target].owned_by_player1, strat, board[target]):
        return false
    ref unit = board[target]
    let fighting = melee and board.timing.phase == BattlePhase::fight
    let opposing_shooting = !melee and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 != board.current_player
    if strat == Stratagem::orks_orks_is_never_beaten:
        return fighting and unit.has_keyword(Keyword::orks) and !unit.has_keyword(Keyword::titanic)
    if strat == Stratagem::orks_too_arrogant_to_die:
        return fighting and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz))
    if strat == Stratagem::orks_crazed_rampage:
        return fighting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::walker) and !unit.has_keyword(Keyword::titanic)
    if strat == Stratagem::orks_hulking_brutes:
        return opposing_shooting and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz))
    if strat == Stratagem::orks_speediest_freeks:
        return opposing_shooting and unit.has_keyword(Keyword::speed_freeks)
    return false

# A rejected surcharge cannot spend the base CP first. The defending owner
# chooses the printed1CP/2CP option, then commits the final legal cost atomically.
act orks_attack_targeted(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee) -> OrksAttackTargeted:
    frm owner = board[target].owned_by_player1
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = owner
    while orks_targeted_stratagem_remaining(board, source, target, melee):
        actions:
            act finish_orks_attack_targeted()
                break
            act choose_orks_defence_stratagem(frm Stratagem defence_card) {orks_targeted_stratagem_valid(board, source, target, defence_card, melee)}
                frm extra_cost : BInt<0, 2>
                frm effect : RuleEffectKind
                effect = RuleEffectKind::fight_on_death_four
                if defence_card == Stratagem::orks_crazed_rampage:
                    effect = RuleEffectKind::fight_on_death_dread
                if defence_card == Stratagem::orks_speediest_freeks:
                    effect = RuleEffectKind::fail_hits_one_to_three
                if defence_card == Stratagem::orks_hulking_brutes:
                    act choose_hulking_protection(Bool all_attacks) {board.can_target_strat_with_cost(owner, defence_card, board[target], defence_card.cost() + int(all_attacks))}
                    extra_cost = int(all_attacks)
                    effect = RuleEffectKind::strong_wound_protection
                    if all_attacks:
                        effect = RuleEffectKind::all_wound_protection
                board.commit_stratagem_with_cost(owner, defence_card, board[target], defence_card.cost() + extra_cost.value)
                grant_orks_effect(board, target, target, 300 + defence_card.value, effect, 1, SourceDuration::phase, invalid_entity_identity())
    if orks_grot_shield_available(board, source, target, melee):
        actions:
            act decline_grot_shields()
            act choose_grot_shield_unit(frm UnitID shield) {orks_grot_shield_unit_valid(board, source, target, shield, melee)}
                board.commit_stratagem(owner, Stratagem::orks_grot_shields, board[shield])
                grant_orks_effect(board, shield, target, 300 + Stratagem::orks_grot_shields.value, RuleEffectKind::grot_shield, 1, SourceDuration::phase, board[shield].identity)
    board.current_decision_maker = previous_owner

# Only the five printed defensive cards can appear at this hook; enum capacity
# is never substituted for phase/unit/package eligibility (Orks source cards).
fun orks_targeted_stratagem_remaining(Board board, UnitID source, UnitID target, Bool melee) -> Bool:
    let strat : Stratagem
    for card in range(max(strat) + 1):
        strat.value = card
        if orks_targeted_stratagem_valid(board, source, target, strat, melee):
            return true
    return false

# Grot Shields pays for a GRETCHIN unit while protecting nearby non-Gretchin
# ORKS infantry. Payer, stratagem target and beneficiary remain distinct.
fun orks_grot_shield_unit_valid(Board board, UnitID source, UnitID target, UnitID shield, Bool melee) -> Bool:
    if melee or source.get() >= board.units.size() or target.get() >= board.units.size() or shield.get() >= board.units.size() or !(board.timing.phase == BattlePhase::shooting):
        return false
    ref recipient = board[target]
    ref grots = board[shield]
    return recipient.owned_by_player1 != board.current_player and board[source].owned_by_player1 != recipient.owned_by_player1 and recipient.has_keyword(Keyword::orks) and recipient.has_keyword(Keyword::infantry) and !orks_type(recipient, OrksDatasheet::gretchin) and !grots.off_battlefield and grots.owned_by_player1 == recipient.owned_by_player1 and orks_type(grots, OrksDatasheet::gretchin) and live_unit_distance(grots, recipient) <= 3.0 and board.can_target_strat(grots.owned_by_player1, Stratagem::orks_grot_shields, grots)

# No dead-end offboard/empty shielding choices are synthesized for the UI.
fun orks_grot_shield_available(Board board, UnitID source, UnitID target, Bool melee) -> Bool:
    let shield : UnitID
    for unit in range(board.units.size()):
        shield = unit
        if orks_grot_shield_unit_valid(board, source, target, shield, melee):
            return true
    return false

# Resolve one mortal per cancelled rolled hit through the ordinary prevention,
# allocation and destruction engine; stop when no shielding model remains.
# Runt Swarm/Grot Shields; core mortal wounds p24, destruction p87.
act intercept_orks_hits(ctx Board board, frm UnitID target, frm CombatCounter count) -> OrksHitInterception:
    frm intercepted : CombatCounter
    while count > 0 and orks_grot_shield(board, board[target]) >= 0:
        frm shield : UnitID
        shield = orks_grot_shield(board, board[target])
        frm one : CombatCounter
        one = 1
        board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, shield, target, false, one)
        subaction*(board) board.shared_actions.resolve_mortal_wounds
        intercepted = intercepted + 1
        count = count - 1

# A model's supported source remains distinct from its attached bodyguards.
# Support Shokka excludes whole SAG units, including itself, and measures
# from the actual bearer, never from a closer bodyguard (core p83).
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
fun orks_shokka_supported(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !unit.attached_units.empty():
        return false
    for bearer in range(unit.models.size()):
        if !unit[bearer].is_alive() or !unit[bearer].has_ability(AbilityKind::support_shokka):
            continue
        for other in range(board.units.size()):
            ref ally = board[other]
            if !ally.off_battlefield and has_live_model(ally) and ally.owned_by_player1 == unit.owned_by_player1 and ally.has_keyword(Keyword::orks) and ally.has_keyword(Keyword::infantry) and !orks_type(ally, OrksDatasheet::big_mek_with_shokk_attack_gun) and live_distance_to_model(ally, unit[bearer]) <= 3.0:
                return true
    return false

# Pulsa affects its recorded target identity for the phase, not a later
# replacement target. The target need not remain within24in after selection.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_pulsa_applies(Board board, Unit source, EntityIdentity target) -> Bool:
    for bearer in range(source.models.size()):
        for index in range(source[bearer].rule_effects.size()):
            ref effect = source[bearer].rule_effects[index]
            if effect.kind.value == RuleEffectKind::pulsa_target.value and effect.associated_unit == target and source_grant_active(board, effect.source_effect):
                return true
    return false

# Kustom Force Field is equipment on the living/retained source, unit-wide
# and RANGED only. Do not grant a permanent model InSv that works in melee.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun orks_allocation_invulnerable(Unit unit, Model model, AttackSequenceInfo info) -> Int:
    let save = model.effective_invulnerable_save()
    if info.source.range() > 0 and unit.has_ability(AbilityKind::kustom_force_field):
        save = min(save, 4)
    return save

# Securing uses actual control/range/OC at this selected end-window effect.
# No generic Battleline or points-based securing permission is invented.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun secure_orks_gretchin_objectives(Board board, SourceInstance instance):
    let location = locate_source(board, instance.source_unit, invalid_entity_identity())
    if !location.found or location.bank.value != SourceBank::battlefield.value:
        return
    board.update_objective_control(true)
    for objective in range(4):
        if board.unit_controls_objective(board[location.unit.value], objective):
            board.grant_secured_objective(objective, instance.owner)

# Each actually engaged source model contributes one D6; do not use unit
# size, charge distance or a weapon's Strength. Printed3+ causes1 mortal.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
fun orks_impetus_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and board[source].is_engaged_with(board[target])

# One Charge owns this frame, sharing existing chance/mortal/destruction
# frames. Simultaneous Mobbed/Crushing/Impetus are ordered by the controller.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
act orks_krushin_impetus(ctx Board board, frm UnitID source) -> OrksKrushinImpetus:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[source].owned_by_player1
    act choose_impetus_target(frm UnitID target) {orks_impetus_target_valid(board, source, target)}
    frm amount : CombatCounter
    frm member_index : ModelIterator
    while member_index.value < board[source].models.size():
        frm engaged = false
        for enemy in range(board[target].models.size()):
            engaged = engaged or (board[source][member_index.value].is_alive() and board[target][enemy].is_alive() and board[source][member_index.value].is_engaged_with(board[target][enemy]))
        if engaged:
            act roll(Dice impact)
            amount = amount + int(impact.value >= 3)
        member_index = member_index + 1
    board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, target, source, false, amount)
    subaction*(board) board.shared_actions.resolve_mortal_wounds
    board.current_decision_maker = previous_owner

# Target choice needs no LOS clause; the printed24in and M/V restrictions
# apply at selection. After selection, stable target identity controls grants.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_pulsa_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)) and live_unit_distance(board[source], board[target]) <= 24.0

# No unavailable target may leave this free optional selection stuck.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas (Pulsa Rokkit).
fun orks_pulsa_available(Board board, UnitID source) -> Bool:
    if board.timing.phase.value != BattlePhase::shooting.value or board[source].owned_by_player1 != board.current_player or !board[source].has_ability(AbilityKind::pulsa_rokkit):
        return false
    let bearer = -1
    for member in range(board[source].models.size()):
        if board[source][member].is_alive() and board[source][member].has_ability(AbilityKind::pulsa_rokkit):
            bearer = member
    if bearer < 0 or !source_usage_available(board, make_source_usage(board[source].owned_by_player1, ORKS_PULSA_RULE, board[source][bearer].original_unit, board[source][bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1))):
        return false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_pulsa_target_valid(board, source, target):
            return true
    return false

# One Attack owns the pre-declaration Pulsa choice; declining spends nothing.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
act orks_pulsa_selection(ctx Board board, frm UnitID source) -> OrksPulsaSelection:
    if !orks_pulsa_available(board, source):
        return
    act use_pulsa_rokkit(Bool pulsa)
    if pulsa:
        act choose_pulsa_target(frm UnitID target) {orks_pulsa_target_valid(board, source, target)}
        for member in range(board[source].models.size()):
            if board[source][member].is_alive() and board[source][member].has_ability(AbilityKind::pulsa_rokkit):
                commit_source_usage(board, make_source_usage(board[source].owned_by_player1, ORKS_PULSA_RULE, board[source][member].original_unit, board[source][member].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1)))
        grant_orks_effect(board, source, source, ORKS_PULSA_RULE, RuleEffectKind::pulsa_target, 1, SourceDuration::phase, board[target].identity)

# Rokkit Barrage uses actual successful hit records, not declarations; it
# never fires in Overwatch/out-of-phase shooting. Choose exactly one hit unit.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_barrage_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    if target.get() >= board.units.size() or board[target].off_battlefield or !has_live_model(board[target]) or board[target].owned_by_player1 == board[source].owned_by_player1:
        return false
    for entry in range(board.attack_records.size()):
        if board.attack_records[entry].target == board[target].identity and board.attack_records[entry].successful_hits.value > 0:
            return true
    return false

# The standard shock frame applies the printed-1 and all shock transitions.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
act orks_rokkit_barrage(ctx Board board, frm UnitID source) -> OrksRokkitBarrage:
    if board.timing.phase.value != BattlePhase::shooting.value or board[source].owned_by_player1 != board.current_player or !board[source].has_ability(AbilityKind::rokkit_barrage):
        return
    frm available = false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        available = available or orks_barrage_target_valid(board, source, target)
    if available:
        act choose_rokkit_barrage_target(frm UnitID shocked) {orks_barrage_target_valid(board, source, shocked)}
        frm penalty : LinearlyDistributedInt<0, 8>
        penalty = 1
        board.shared_actions.battle_shock_test = battle_shock_test(board, board[shocked], false, false, penalty)
        subaction*(board, board[shocked]) board.shared_actions.battle_shock_test

# Flyin Headbutt decides suppression/target/eight dice; return mortal jobs to the shared destruction stack (Orks/Flyboyz; core p87).
act orks_before_destruction(ctx Board board, ctx Model casualty, frm PendingDestruction event) -> OrksBeforeDestruction:
    frm suppress_demise = false
    frm headbutt_recipient : UnitID
    frm crash_mortals : CombatCounter
    crash_mortals = 0
    if event.bank.value == SourceBank::battlefield.value and casualty.has_keyword(Keyword::aircraft) and casualty.destroyed_whole_unit and board.can_target_strat(source_bank_unit(board, event.bank, event.unit.get()).owned_by_player1, Stratagem::orks_flyin_headbutt, source_bank_unit(board, event.bank, event.unit.get())) and orks_headbutt_has_target(board, event.unit, casualty):
        actions:
            act decline_flyin_headbutt()
            act flyin_headbutt()
                board.commit_stratagem(source_bank_unit(board, event.bank, event.unit.get()).owned_by_player1, Stratagem::orks_flyin_headbutt, source_bank_unit(board, event.bank, event.unit.get()))
                suppress_demise = true
                act choose_headbutt_target(frm UnitID crash_target) {orks_headbutt_target(board, event.unit, casualty, crash_target)}
                headbutt_recipient = crash_target
                frm headbutt_rolls : BInt<0, 9>
                frm headbutt_mortals : CombatCounter
                while headbutt_rolls.value < 8:
                    act roll(Dice crash_face)
                    headbutt_rolls = headbutt_rolls + 1
                    headbutt_mortals = headbutt_mortals.value + int(crash_face.value >= 4)
                if headbutt_mortals > 0:
                    crash_mortals = headbutt_mortals

# Dreadherder support is an optional Shooting-phase action alongside core shooting (Orks/Dread Mob).
act orks_shooting_phase_choice(ctx Board board) -> OrksShootingPhaseChoice:
    frm started = false
    actions:
        act use_dreadherder_support(frm UnitID dreadherder_source) {orks_dreadherder_available(board, dreadherder_source)}
            started = true
            board.shared_actions.faction_shooting_support = orks_dreadherder_shooting(board, dreadherder_source)
            subaction*(board) board.shared_actions.faction_shooting_support

# Unpredictable Genius owns its single-target trigger and effect; common declarations/grouping remain core (Orks/Madcap Meks).
act orks_declarations_complete(ctx Board board, ctx DeclaredWeapons declarations, frm UnitID source, frm Bool melee) -> OrksDeclarationsComplete:
    frm effect : SourceEffectKey
    if !melee and single_declared_target(declarations) >= 0:
        frm target : UnitID
        target = single_declared_target(declarations)
        subaction*(board) genius = orks_unpredictable_genius(board, source, target)
        effect = genius.effect

# Mobbed/Impetus remain interleaved with common charge-end effects in the charger-chosen order (Orks cards; user Rules Sequencing).
act orks_charge_choice(ctx Board board, ctx FactionChargeProgress progress, ctx Bool crushing_pending, frm UnitID source) -> OrksChargeChoice:
    frm started = false
    actions:
        act resolve_krushin_impetus() {progress.impetus}
            started = true
            progress.impetus = false
            subaction*(board) impetus = orks_krushin_impetus(board, source)
        act decline_krushin_impetus() {progress.impetus}
            started = true
            progress.impetus = false
        act resolve_mobbed() {progress.mobbed}
            started = true
            progress.mobbed = false
            board.shared_actions.faction_after_charge_shock = resolve_orks_mobbed(board, source)
            subaction*(board) board.shared_actions.faction_after_charge_shock

# Capture Wrecka objective selection, Ammo Runt and paid attack choices before declarations (Orks cards).
act orks_attack_selection_options(ctx Board board, frm UnitID source, frm Bool melee) -> OrksAttackSelectionOptions:
    board[source].history.wrecka_objective_selection = unit_in_any_objective_range(board, board[source])
    # Source-specific free choices enter the same declaration snapshots as
    # paid rules: Ammo Runts (Boyz/Nobz/Warboss).
    if !melee:
        subaction*(board) datasheet_selection = orks_datasheet_selection(board, source)
    subaction*(board) detachment_selection = orks_attack_selection(board, source, melee)

# Surly return and Flyboyz aircraft destruction retain their pending casualty (Orks cards; core p87).
fun orks_has_destruction_trigger(Board board, Model model) -> Bool:
    return model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value or orks_aircraft_death_source(board, model)

# Orks attack ledger records actual wounds lost before clamping, not rolled damage (Orks detachment triggers).
# Track Orks attack/phase kill provenance only after actual last-model destruction (Orks combat triggers).
# Flyin Headbutt requires the Aircraft unit destruction event (Orks/Flyboyz).
fun orks_unit_destruction_trigger(Board board, Unit unit, Model model) -> Bool:
    return orks_package(board, unit, OrksDetachment::flyboyz) and model.has_keyword(Keyword::aircraft)

# Surly return retains its source even in reserves/passengers; no offboard distance permission is introduced (Orks/Surly).
fun orks_offboard_destruction_trigger(Model model) -> Bool:
    return model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value

# Only Squig Launcha's special hit provenance is faction policy; the generic
# ledger already counted the hits (Squigbuggies/Squig Barrage).
fun record_orks_hit_tags(Board board, AttackResultRecord record, Int count):
    if board.attack_info.squig_launcha_weapon:
        add_attack_count(record.tagged_hits[AttackHitTag::squig_launcha.value], count)

# Orks/Get Stuck In and each printed datasheet/package grant append actual
# instances. Core p78 selects duplicate instances; Firing Deck p81 uses the
# actual bearer plus the borrowed profile/family, not an incidental slot.
fun append_orks_weapon_rules(Board board, UnitID source, Int bearer, Weapon profile, WeaponCode family, WeaponAbilitySet rules):
    append_riled_assault_rules(board[source][bearer], profile, rules)
    if war_horde_melee_rule_applies(board, source, profile):
        rules.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    append_orks_package_weapon_rules(board, source, bearer, profile, family, rules)
    append_orks_datasheet_weapon_rules(board, source, profile, rules)

# Orks/Brutal Impact, enhancements and datasheets use one declared-weapon
# contract; source-specific conditions remain here (appendix02.02.01).
fun append_orks_weapon_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers modifiers):
    append_orks_intrinsic_modifiers(board, source, kind, modifiers)
    append_orks_declaration_modifiers(board, source, declaration, kind, modifiers)
    append_orks_datasheet_modifiers(board, source, declaration, kind, modifiers)

# Kustom Force Field grants4+ only against ranged attacks; it is neither a
# permanent model stat nor a save modifier (Orks/Big Mek in Mega Armour; p19).
fun append_orks_allocation_effects(Unit unit, Model model, AttackSequenceInfo attack, InvulnerableSavePermission permission):
    if attack.source.range() > 0 and unit.has_ability(AbilityKind::kustom_force_field):
        permission.target = min(permission.target.value, 4)
