import board
import source_effects

# Selected movement grants are captured at selection, so later status changes
# do not retroactively waive a previously selected Advance/Fall Back (Waaagh!).
fun orks_move_charge_permission(Board board, Unit unit, MovementKind kind) -> Bool:
    let fallback = kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape
    if !fallback and !(kind == MovementKind::advance):
        return false
    if unit_rule_effect(board, unit, RuleEffectKind::turbo_engine) > 0:
        return true
    if orks_package(board, unit, OrksDetachment::kult_of_speed) and unit.has_keyword(Keyword::speed_freeks):
        return true
    if !fallback:
        return false
    return (orks_package(board, unit, OrksDetachment::taktikal_brigade) and orks_taktikal_unit(unit)) or unit_has_orks_enhancement(unit, OrksEnhancement::glory_hog) or unit_has_orks_enhancement(unit, OrksEnhancement::kunnin_but_brutal)

# Runt Swarm's Advance/Fall Back permission waives only that action gate;
# shock, OC, engagement, shooting and once-per-turn restrictions still apply.
fun orks_move_action_permission(Board board, Unit unit, MovementKind kind) -> Bool:
    return (kind == MovementKind::advance or kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape) and ((orks_package(board, unit, OrksDetachment::runt_swarm) and orks_type(unit, OrksDatasheet::gretchin)) or unit_rule_effect(board, unit, RuleEffectKind::action_move_permission) > 0)

# Blitz Brigade excludes points only for Flyboyz Aircraft; public point-free
# mode already omits all price caps. It grants no substitute reserve quota.
fun orks_charge_reroll(Board board, Unit unit) -> Bool:
    return (orks_package(board, unit, OrksDetachment::blitz_brigade) and unit.has_keyword(Keyword::wagon)) or unit_has_orks_enhancement(unit, OrksEnhancement::competitive_streak)

# Advance/Fall Back waivers are retained at selection; later riled/option loss
# cannot retroactively change that selected move's restrictions (source wording).
fun capture_orks_selected_move(Board board, UnitID source, MovementKind kind):
    ref unit = board[source]
    if kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape:
        unit.history.fallback_allows_charge = orks_move_charge_permission(board, unit, kind)
        unit.history.fallback_allows_shooting = unit_has_orks_enhancement(unit, OrksEnhancement::kunnin_but_brutal)
    unit.history.selected_move_allows_action = orks_move_action_permission(board, unit, kind)
    if orks_package(board, unit, OrksDetachment::kult_of_speed) and unit.has_keyword(Keyword::speed_freeks):
        grant_orks_effect(board, source, source, 430, RuleEffectKind::ranged_assault, 1, SourceDuration::turn, invalid_entity_identity())

# Wimp-kickaz and the accepted Hunt card force a Desperate Escape; their unit
# source must still be engaged at this actual selection (ordinary source text).
fun orks_forces_escape(Board board, Unit unit) -> Bool:
    for enemy in range(board.units.size()):
        ref opponent = board.units[enemy]
        if opponent.owned_by_player1 != unit.owned_by_player1 and opponent.is_engaged_with(unit) and (unit_has_orks_enhancement(opponent, OrksEnhancement::wimp_kickaz) or unit_rule_effect(board, opponent, RuleEffectKind::hunt_escape_hazards) > 0):
            return true
    return false

# Each riled Wimp-kickaz instance supplies its printed cumulative-1; Hunt's
# shocked penalty applies only to its extra rolls, not the base hazard batch.
fun orks_escape_penalty(Board board, Unit unit) -> Int:
    let penalty = 0
    for enemy in range(board.units.size()):
        ref opponent = board.units[enemy]
        if opponent.owned_by_player1 != unit.owned_by_player1 and opponent.is_engaged_with(unit) and unit_has_orks_enhancement(opponent, OrksEnhancement::wimp_kickaz) and unit_is_riled_up(opponent):
            penalty = penalty + 1
    return penalty

# Once a Hunt-granted unit forces this escape, all engaged Beast Snagga units
# contribute3 extra rolls against Monster/Vehicle, as the card explicitly says.
fun orks_extra_escape_hazards(Board board, Unit unit) -> Int:
    if !unit.has_keyword(Keyword::monster) and !unit.has_keyword(Keyword::vehicle):
        return 0
    let active = false
    let count = 0
    for enemy in range(board.units.size()):
        ref opponent = board.units[enemy]
        if opponent.owned_by_player1 != unit.owned_by_player1 and opponent.is_engaged_with(unit):
            active = active or unit_rule_effect(board, opponent, RuleEffectKind::hunt_escape_hazards) > 0
            count = count + int(opponent.has_keyword(Keyword::beast_snagga))
    return 3 * count * int(active)

# Movement-phase free abilities may be used between activations and before
# selecting a particular unit; the same source usage gate governs both hooks.
fun orks_movement_ability_valid(Board board, UnitID source, OrksDetachmentAbility ability) -> Bool:
    if !orks_support_actor(board, source, board.current_player) or !(board.timing.phase == BattlePhase::movement):
        return false
    ref unit = board[source]
    if ability.value == OrksDetachmentAbility::roar_of_mork.value:
        return orks_psychic_available(board, source, false) and orks_roar_has_target(board, source)
    if ability.value == OrksDetachmentAbility::da_boss_is_watchin.value:
        return orks_watchin_available(board, unit)
    return false

# Avoid exposing an unavailable choice stage to legacy/non-Orks fixtures.
fun orks_movement_ability_available(Board board, UnitID source) -> Bool:
    return orks_movement_ability_valid(board, source, OrksDetachmentAbility::roar_of_mork) or orks_movement_ability_valid(board, source, OrksDetachmentAbility::da_boss_is_watchin)

# Watchin' riles its OWN unit to next own turn, once per army/battle; Roar
# selects an enemy after its psychic roll. Source: the two Orks option cards.
act orks_movement_abilities(ctx Board board, frm UnitID source) -> OrksMovementAbilities:
    while orks_movement_ability_available(board, source):
        actions:
            act finish_orks_movement_abilities()
                break
            act choose_orks_movement_ability(OrksDetachmentAbility ability) {orks_movement_ability_valid(board, source, ability)}
                if ability.value == OrksDetachmentAbility::roar_of_mork.value:
                    board.shared_actions.use_orks_psychic = use_orks_psychic(board, source, false)
                    subaction*(board) board.shared_actions.use_orks_psychic
                else:
                    commit_orks_watchin(board, board[source])

# Edge withdrawal is measured to any part of any live circular base, while
# no Enemy Engagement is waived (Instinctive Hunters; supplied Within).
fun orks_near_edge(Unit unit) -> Bool:
    for member in range(unit.models.size()):
        ref model = unit[member]
        if model.is_alive():
            let radius = model.base_radius_micrometres()
            let clearance = min(min(model.position.x.value, BOARD_WIDTH - model.position.x.value), min(model.position.y.value, BOARD_HEIGHT - model.position.y.value))
            if float(clearance * MICROMETRES_PER_INCH) - radius <= float(6 * MICROMETRES_PER_INCH):
                return true
    return false

# Move-end reactions require the enemy's completed move within8in. Scarper
# uses6in if attached, Whirligig6in if riled; otherwise each rollsD6. The
# target must remain unengaged and pays its own exact1CP (Orks source cards).
fun orks_enemy_move_card_valid(Board board, UnitID mover, UnitID target, Stratagem card) -> Bool:
    if mover.get() >= board.units.size() or target.get() >= board.units.size() or !(board.timing.phase == BattlePhase::movement) or board[target].owned_by_player1 == board.current_player or board[target].owned_by_player1 == board[mover].owned_by_player1 or !orks_support_actor(board, target, board[target].owned_by_player1) or board.is_in_melee(board[target]) or live_unit_distance(board[mover], board[target]) > 8.0 or !board.can_target_strat(board[target].owned_by_player1, card, board[target]):
        return false
    return card == Stratagem::orks_scarper and orks_type(board[target], OrksDatasheet::gretchin) or card == Stratagem::orks_whirligig_evasion and orks_type(board[target], OrksDatasheet::deffkoptas)

# A Move frame cannot contain a reactive Move frame recursively. This hook
# returns the selected move parameters to the flat activation wrapper.
act select_orks_enemy_move_reaction(ctx Board board, frm UnitID mover) -> OrksEnemyMoveReaction:
    frm available = false
    frm target : UnitID
    frm distance : StatModifier
    frm previous_owner = board.current_decision_maker
    if orks_enemy_move_available(board, mover):
        board.current_decision_maker = !board[mover].owned_by_player1
        actions:
            act decline_orks_move_reaction()
            act choose_supreme_kunnin_unit(frm UnitID nazdreg) {orks_supreme_kunnin_valid(board, mover, nazdreg)}
                commit_source_usage(board, make_source_usage(board[nazdreg].owned_by_player1, 154, board[nazdreg].identity, invalid_entity_identity(), SourceUseScope::army, source_use_limits(1, 0, 0, 0)))
                target = nazdreg
                available = true
                frm fixed_five = false
                if unit_is_riled_up(board[nazdreg]):
                    act choose_supreme_fixed_five(Bool five)
                    fixed_five = five
                distance = 5
                if !fixed_five:
                    act roll(Dice kunnin_distance)
                    distance = kunnin_distance.value
            act choose_orks_move_reaction_unit(frm UnitID reaction) {orks_enemy_move_card_valid(board, mover, reaction, Stratagem::orks_scarper) or orks_enemy_move_card_valid(board, mover, reaction, Stratagem::orks_whirligig_evasion)}
                frm card : Stratagem
                card = Stratagem::orks_scarper
                if !orks_type(board[reaction], OrksDatasheet::gretchin):
                    card = Stratagem::orks_whirligig_evasion
                board.commit_stratagem(board[reaction].owned_by_player1, card, board[reaction])
                target = reaction
                available = true
                distance = 6
                if card == Stratagem::orks_scarper and board[reaction].attached_units.empty() or card == Stratagem::orks_whirligig_evasion and !unit_is_riled_up(board[reaction]):
                    act roll(Dice escape_distance)
                    distance = escape_distance.value
    board.current_decision_maker = previous_owner

# Actual eligible units, not chosen datasheet labels, determine availability.
fun orks_enemy_move_available(Board board, UnitID mover) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_supreme_kunnin_valid(board, mover, target) or orks_enemy_move_card_valid(board, mover, target, Stratagem::orks_scarper) or orks_enemy_move_card_valid(board, mover, target, Stratagem::orks_whirligig_evasion):
            return true
    return false

# Readied Brawlers grants an explicit Assault Disembark permission to its
# WAGON's passengers after a successful Normal move, not before selection.
act orks_wagon_move_end(ctx Board board, frm UnitID source) -> OrksWagonMoveEnd:
    if board[source].owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::movement) or !(board[source].history.move_kind == MovementKind::normal) or !board[source].has_keyword(Keyword::wagon) or !board.can_target_strat(board[source].owned_by_player1, Stratagem::orks_readied_brawlers, board[source]):
        return
    actions:
        act decline_readied_brawlers()
        act readied_brawlers()
            board.commit_stratagem(board[source].owned_by_player1, Stratagem::orks_readied_brawlers, board[source])
            grant_orks_effect(board, source, source, 300 + Stratagem::orks_readied_brawlers.value, RuleEffectKind::assault_disembark, 1, SourceDuration::phase, invalid_entity_identity())

# A completed charge, not a declared/failed charge, triggers Impending Krunch;
# each currently engaged enemy makes its own-1 shock roll (Blitz Brigade).
act orks_wagon_charge_end(ctx Board board, frm UnitID source) -> OrksWagonChargeEnd:
    if board[source].owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::charge) or !board[source].has_charged or !board[source].has_keyword(Keyword::wagon) or !board.can_target_strat(board[source].owned_by_player1, Stratagem::orks_impending_krunch, board[source]):
        return
    actions:
        act decline_impending_krunch()
        act impending_krunch()
            board.commit_stratagem(board[source].owned_by_player1, Stratagem::orks_impending_krunch, board[source])
            frm targets : Bool[MAX_UNIT_COUNT]
            for slot in range(board.units.size()):
                targets[slot] = board[slot].owned_by_player1 != board[source].owned_by_player1 and has_live_model(board[slot]) and board[source].is_engaged_with(board[slot])
            while orks_pending_units(targets):
                act choose_krunch_target(frm UnitID target) {target.get() < board.units.size(), targets[target.get()]}
                targets[target.get()] = false
                frm penalty : LinearlyDistributedInt<0, 8>
                penalty = 1
                board.shared_actions.battle_shock_test = battle_shock_test(board, board[target], false, false, penalty)
                subaction*(board, board[target]) board.shared_actions.battle_shock_test

# Finite target flags permit player-chosen order without compaction hazards.
fun orks_pending_units(Bool[MAX_UNIT_COUNT] pending) -> Bool:
    for slot in range(MAX_UNIT_COUNT):
        if pending[slot]:
            return true
    return false

# Flyboss's ingress effect measures from the newly set up Aircraft, not its
# reserve coordinates. Accepted riled effects persist to next own turn.
fun orks_flyboss_ingress(Board board, UnitID source):
    if !unit_has_orks_enhancement(board[source], OrksEnhancement::flyboss):
        return
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_support_actor(board, target, board[source].owned_by_player1) and (board[target].has_keyword(Keyword::aircraft) or orks_type(board[target], OrksDatasheet::deffkoptas)) and board[target].has_keyword(Keyword::orks) and live_unit_distance(board[source], board[target]) <= 6.0:
            grant_orks_payload(board, source, target, 200 + OrksEnhancement::flyboss.value, riled_up_grant(), SourceDuration::next_own_turn)

# Impulsive Recon allows the first own Movement phase (round1), subject to
# ordinary ingress placement; the zero-based round alone does not waive it.
fun orks_ingress_round_allowed(Board board, Unit unit) -> Bool:
    return board.current_round >= 1 or (unit.has_ability(AbilityKind::deff_from_shadows) and unit.owned_by_player1 != board.current_player and board.timing.phase == BattlePhase::movement) or (unit.owned_by_player1 == board.current_player and board.timing.phase == BattlePhase::movement and unit.has_keyword(Keyword::aircraft) and unit_has_orks_enhancement(unit, OrksEnhancement::impulsive_recon) and !unit.history.has_ingressed)

# Kaptin's Hat redeploys up to3 friendly ORKS infantry after BOTH armies deploy;
# its permission includes Strategic Reserves without a price/cost calculation.
# An embarked source can use this unmeasured army ability (01.02.04).
fun orks_kaptin_source(Board board, Bool owner) -> SourceInstance:
    let result : SourceInstance
    let bank : SourceBank
    for b in range(3):
        bank.value = b
        for slot in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, slot)
            if unit.owned_by_player1 != owner:
                continue
            for member in range(unit.models.size()):
                if model_has_orks_enhancement(unit, unit[member], OrksEnhancement::kaptins_hat):
                    result = make_source_usage(unit.owned_by_player1, 200 + OrksEnhancement::kaptins_hat.value, unit.identity, unit[member].identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1))
    return result

# A unit is redeployed at most once by this source, even if its reserve bank
# index changes. Battlefield slots remain stable through the round trip.
fun orks_kaptin_target(Board board, UnitID target, Bool owner, Bool[MAX_UNIT_COUNT] selected) -> Bool:
    return orks_support_actor(board, target, owner) and board[target].has_keyword(Keyword::orks) and board[target].has_keyword(Keyword::infantry) and !selected[target.get()] and board.reserve_units.has_capacity()

# Accepted prebattle redeploy keeps equipment/identities and actual source
# permissions; terrain/whole-base placement uses the usual setup kernel.
act orks_kaptin_redeploy(ctx Board board) -> OrksKaptinRedeploy:
    frm owner = board.starting_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = owner
        frm instance : SourceInstance
        instance = orks_kaptin_source(board, owner)
        if instance.rule.value != 0 and source_usage_available(board, instance):
            actions:
                act decline_kaptins_hat()
                act kaptins_hat()
                    commit_source_usage(board, instance)
                    frm selected : Bool[MAX_UNIT_COUNT]
                    frm count : BInt<0, 4>
                    while count.value < 3:
                        actions:
                            act finish_kaptin_redeploy()
                                break
                            act choose_kaptin_redeploy_unit(frm UnitID target) {orks_kaptin_target(board, target, owner, selected)}
                                selected[target.get()] = true
                                count = count + 1
                                frm original : Unit
                                original = board[target]
                                let moved = reposition_unit(board, target)
                                assert(moved, "redeploy unit could not leave battlefield")
                                frm reserve : UnitID
                                reserve = board.reserve_units.size() - 1
                                actions:
                                    act kaptin_strategic_reserves()
                                        # Prebattle selection is not a reactive
                                        # reposition exempt from reserve deadline.
                                        board.reserve_units[reserve.get()].history.repositioned = false
                                    act place_kaptin_redeploy(BoardPosition position) {setup_at_valid(board, board.reserve_units[reserve.get()], position, MovementKind::normal, board.reserve_units[reserve.get()].all_have_ability(AbilityKind::infiltrators))}
                                        enter_from_reserves(board, reserve, position, MovementKind::normal)
                                        board[target].history = original.history
        owner = !owner
        controllers = controllers + 1
    board.current_decision_maker = board.starting_player

# Bomb selection excludes Lone Operative even at close distance. Burna also
# excludes Monster/Vehicle; both use actual visibility and base distance.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Blitza-bommer,Burna-bommer}
fun orks_aircraft_bomb_target(Board board, UnitID source, UnitID target, Bool burna) -> Bool:
    if target.get() >= board.units.size() or board[target].off_battlefield or !has_live_model(board[target]) or board[target].owned_by_player1 == board[source].owned_by_player1 or orks_lone_operative(board, board[target]):
        return false
    if burna and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)):
        return false
    return unit_visible_to_unit(board, board[source], board[target]) and live_unit_distance(board[source], board[target]) <= float(24 + 12 * int(burna))

# Race's grant includes cargo; source-unit range is battlefield only, whereas
# the cargo receives an army effect without an offboard measurement.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
fun orks_race_target(Board board, Unit source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 == source.owned_by_player1 and board[target].has_keyword(Keyword::speed_freeks) and live_unit_distance(source, board[target]) <= 6.0

# Race retains the shared per-army/round budget across both start/end windows.
# Cargo is selected by actual carrier identity, not TRANSPORT unit anchor.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
fun commit_orks_race(Board board, SourceInstance instance, UnitID target):
    let location = locate_source(board, instance.source_unit, invalid_entity_identity())
    assert(location.found and source_bank_unit(board, location.bank, location.unit.value).has_ability(AbilityKind::get_back_in_da_race) and orks_race_target(board, source_bank_unit(board, location.bank, location.unit.value), target), "invalid Race target")
    commit_source_usage(board, instance)
    board[target].battle_socked = false
    grant_orks_payload(board, target, target, 168, riled_up_grant(), SourceDuration::next_own_turn)
    for passenger in range(board.embarked_units.size()):
        ref cargo = board.embarked_units[passenger]
        if board[target].find_model(cargo.embarked_transport) >= 0:
            cargo.battle_socked = false
            grant_orks_own_payload(board, cargo, 168, riled_up_grant(), SourceDuration::next_own_turn)

# Named movement effects do not invent visibility for Found 'Em or range for
# Makari. Drive-by's explicit visible/non-Monster/Vehicle restrictions remain.
# Sources: Orks/Kommandos Found 'Em; Warbuggies Drive-by Skorchin'.
fun orks_datasheet_move_target(Board board, UnitID source, UnitID target, Bool skorch) -> Bool:
    if target.get() >= board.units.size() or board[target].off_battlefield or !has_live_model(board[target]) or board[target].owned_by_player1 == board[source].owned_by_player1:
        return false
    if skorch and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle) or !unit_visible_to_unit(board, board[source], board[target])):
        return false
    return live_unit_distance(board[source], board[target]) <= float(12 - 6 * int(skorch))

# Stable source-use counters survive transfers/revival. Makari is army/battle,
# Da Jump army/round; ordinary free selection abilities resolve once per phase.
# Source cards' Movement clauses and explicit once-per-army restrictions.
fun orks_datasheet_move_available(Board board, UnitID source, OrksDatasheetMoveAbility ability) -> Bool:
    if source.get() >= board.units.size() or board[source].off_battlefield or board[source].owned_by_player1 != board.current_player or board.timing.phase.value != BattlePhase::movement.value or !has_live_model(board[source]):
        return false
    ref unit = board[source]
    if ability.value == OrksDatasheetMoveAbility::makari.value:
        return unit.has_ability(AbilityKind::makari_banner) and source_usage_available(board, make_source_usage(unit.owned_by_player1, 148, unit.identity, invalid_entity_identity(), SourceUseScope::army, source_use_limits(1, 0, 0, 1)))
    if ability.value == OrksDatasheetMoveAbility::da_jump.value:
        return board.reserve_units.has_capacity() and orks_datasheet_psychic_available(board, source, 151)
    let skorch = ability.value == OrksDatasheetMoveAbility::drive_by_skorchin.value
    if (!skorch and !unit.has_ability(AbilityKind::found_em)) or (skorch and !unit.has_ability(AbilityKind::drive_by_skorchin)) or !source_usage_available(board, make_source_usage(unit.owned_by_player1, 149 + int(skorch), unit.identity, invalid_entity_identity(), SourceUseScope::unit, source_use_limits(1, 0, 0, 0))):
        return false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_datasheet_move_target(board, source, target, skorch):
            return true
    return false

# Finite action domain contains four ability names, not new positions or
# Cartesian products of unit/model/weapon selectors (Godot action contract).
fun orks_datasheet_move_any(Board board, UnitID source) -> Bool:
    let ability : OrksDatasheetMoveAbility
    for kind in range(4):
        ability.value = kind
        if orks_datasheet_move_available(board, source, ability):
            return true
    return false

# Makari selects zero..round friendly army units, including offboard own-army
# units without ranges; the shared bank selector prevents duplicate targets.
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun orks_makari_target(Board board, SourceBank bank, UnitID target, Bool owner, EntityIdentity[5] selected) -> Bool:
    if target.get() >= source_bank_size(board, bank):
        return false
    ref unit = source_bank_unit(board, bank, target.get())
    if unit.owned_by_player1 != owner or !unit.has_keyword(Keyword::orks) or !has_live_model(unit):
        return false
    for index in range(5):
        if selected[index] == unit.identity:
            return false
    return true

# One MovementPhase owns this selector; accepted psychic1 still moves the
# unit to reserves. Default effect duration is this phase (01.02.02), allowing
# Deep Strike on same-phase ingress rather than permanent roster mutation.
# Sources: Orks/Ghazghkull-Thraka Makari; Kommandos; Warbuggies; Weirdboy Da Jump.
act orks_datasheet_movement(ctx Board board, frm UnitID source) -> OrksDatasheetMovement:
    frm previous_bank = board.orks_support_bank
    act choose_datasheet_move_ability(frm OrksDatasheetMoveAbility ability) {orks_datasheet_move_available(board, source, ability)}
    if ability.value == OrksDatasheetMoveAbility::makari.value:
        commit_source_usage(board, make_source_usage(board[source].owned_by_player1, 148, board[source].identity, invalid_entity_identity(), SourceUseScope::army, source_use_limits(1, 0, 0, 1)))
        frm chosen : EntityIdentity[5]
        frm count : BInt<0, 6>
        while count.value < board.current_round.value + 1:
            actions:
                act finish_makari_targets()
                    break
                act choose_makari_bank(frm SourceBank bank)
                    board.orks_support_bank = bank
                    actions:
                        act cancel_makari_bank()
                        act choose_makari_unit(UnitID target) {orks_makari_target(board, bank, target, board[source].owned_by_player1, chosen)}
                            ref unit = source_bank_unit(board, bank, target.get())
                            chosen[count.value] = unit.identity
                            grant_orks_own_payload(board, unit, 165, riled_up_grant(), SourceDuration::next_own_turn)
                            count = count + 1
    if ability.value == OrksDatasheetMoveAbility::found_em.value or ability.value == OrksDatasheetMoveAbility::drive_by_skorchin.value:
        frm skorch = ability.value == OrksDatasheetMoveAbility::drive_by_skorchin.value
        act choose_datasheet_move_target(frm UnitID target) {orks_datasheet_move_target(board, source, target, skorch)}
        commit_source_usage(board, make_source_usage(board[source].owned_by_player1, 149 + int(skorch), board[source].identity, invalid_entity_identity(), SourceUseScope::unit, source_use_limits(1, 0, 0, 0)))
        frm kind = RuleEffectKind::found_detection
        if skorch:
            kind = RuleEffectKind::overwatch_blocked
        grant_orks_effect(board, source, target, 166 + int(skorch), kind, 1, SourceDuration::turn, invalid_entity_identity())
    if ability.value == OrksDatasheetMoveAbility::da_jump.value:
        frm jump_rule : BInt<151, 163>
        jump_rule = 151
        board.shared_actions.orks_psychic_test = orks_datasheet_psychic(board, source, jump_rule)
        subaction*(board) board.shared_actions.orks_psychic_test
        if has_live_model(board[source]):
            grant_orks_effect(board, source, source, 163, RuleEffectKind::deep_strike, 1, SourceDuration::phase, invalid_entity_identity())
            assert(reposition_unit(board, source), "Da Jump requires reserve capacity")
    board.orks_support_bank = previous_bank

# Supreme Kunnin' is free, once per phase PER ARMY, and checks the enemy's
# completed endpoint. It cannot trigger from the controlling player's moves.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
fun orks_supreme_kunnin_valid(Board board, UnitID mover, UnitID source) -> Bool:
    return mover.get() < board.units.size() and source.get() < board.units.size() and board.timing.phase == BattlePhase::movement and board[source].owned_by_player1 != board.current_player and board[source].owned_by_player1 != board[mover].owned_by_player1 and !board[source].off_battlefield and has_live_model(board[source]) and board[source].has_ability(AbilityKind::supreme_kunnin) and !board.is_in_melee(board[source]) and live_unit_distance(board[source], board[mover]) <= 8.0 and source_usage_available(board, make_source_usage(board[source].owned_by_player1, 154, board[source].identity, invalid_entity_identity(), SourceUseScope::army, source_use_limits(1, 0, 0, 0)))

# Taktikal Know-wotz splits the exact10 models into two five-model components
# BEFORE attachments/transport formations. Original model identities/equipment
# survive; each resulting unit receives exactly one of the two token abilities.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
fun split_orks_kommandos(Board board, UnitID source, Bool[10] first_group, Bool bomb_first):
    assert(source.get() < board.reserve_units.size() and board.reserve_units.has_capacity(), "split needs a roster slot")
    ref original = board.reserve_units[source.get()]
    assert(original.models.size() == 10 and original.attached_units.empty() and orks_type(original, OrksDatasheet::kommandos), "split must precede attachments")
    let count = 0
    for member_index in range(10):
        count = count + int(first_group[member_index])
    assert(count == 5, "each split Kommando unit needs five models")
    let second : Unit
    second.name = "Kommandos (split)"s
    second.owned_by_player1 = original.owned_by_player1
    configure_orks_attachment(second, OrksDatasheet::kommandos)
    let first_models : CheckedVector<Model, MAX_UNIT_MODELS>
    for member_index in range(10):
        let model = original[member_index]
        let bomb = first_group[member_index] == bomb_first
        let ability_index = model.abilities.size()
        while ability_index > 0:
            ability_index = ability_index - 1
            if model.abilities[ability_index] == AbilityKind::taktikal_know_wotz or model.abilities[ability_index] == AbilityKind::bomb_squig and !bomb or model.abilities[ability_index] == AbilityKind::found_em and bomb:
                model.abilities.erase(ability_index)
        if first_group[member_index]:
            first_models.append(model)
        else:
            second.models.append(model)
    original.models = first_models
    original.destroyed_models.value.clear()
    original.capture_starting_strength()
    board.identify_unit(second)
    for member_index in range(second.models.size()):
        second[member_index].original_unit = second.identity
    second.capture_starting_strength()
    board.reserve_units.append(second)

# Each initial unit gets one optional split decision in its owner's order;
# resulting five-model units cannot split again or refill a spent Bomb Squig.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos (Declare Battle Formations).
act orks_kommando_formations(ctx Board board) -> OrksKommandoFormations:
    frm source : UnitIterator
    frm previous_owner = board.current_decision_maker
    while source.value < board.reserve_units.size():
        if board.reserve_units[source.value].has_ability(AbilityKind::taktikal_know_wotz) and board.reserve_units[source.value].models.size() == 10 and board.reserve_units.has_capacity():
            board.current_decision_maker = board.reserve_units[source.value].owned_by_player1
            act split_kommando_unit(Bool split)
            if split:
                frm selected : Bool[10]
                frm count : BInt<0, 6>
                while count.value < 5:
                    act choose_split_kommando(ModelID member_index) {member_index.get() < 10, !selected[member_index.get()]}
                    selected[member_index.get()] = true
                    count = count + 1
                act choose_split_bomb_squig(Bool first_group)
                frm slot : UnitID
                slot = source.value
                split_orks_kommandos(board, slot, selected, first_group)
        source = source + 1
    board.current_decision_maker = previous_owner

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

# Selection precedes Advance dice and Fall Back mode hazards. Fungus-Fuel,
# 'Ere We Go and Stomping Juggernaut use their exact actor/window requirements.
fun orks_move_card_valid(Board board, UnitID actor, Stratagem card, Bool charging) -> Bool:
    if actor.get() >= board.units.size() or board[actor].owned_by_player1 != board.current_player or !board.can_target_strat(board[actor].owned_by_player1, card, board[actor]):
        return false
    ref unit = board[actor]
    if card == Stratagem::orks_stomping_juggernaut:
        return unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::walker) and ((charging and board.timing.phase == BattlePhase::charge) or (!charging and board.timing.phase == BattlePhase::movement))
    if charging or !(board.timing.phase == BattlePhase::movement):
        return false
    if card == Stratagem::orks_fungus_fuel_injection:
        return unit.has_keyword(Keyword::orks) and (unit.has_keyword(Keyword::mounted) or unit.has_keyword(Keyword::vehicle))
    if card == Stratagem::orks_ere_we_go:
        return orks_type(unit, OrksDatasheet::beast_snagga_boyz) or orks_type(unit, OrksDatasheet::boyz)
    return false

# Optional absent source cards return without extra inputs in core fixtures.
fun orks_move_cards_remaining(Board board, UnitID actor, Bool charging) -> Bool:
    return orks_move_card_valid(board, actor, Stratagem::orks_stomping_juggernaut, charging) or orks_move_card_valid(board, actor, Stratagem::orks_fungus_fuel_injection, charging) or orks_move_card_valid(board, actor, Stratagem::orks_ere_we_go, charging)

# These grants precede the actual movement/charge snapshot. Mobile remains a
# real keyword; user area-only geometry does not invent dense physical features.
act orks_move_selection(ctx Board board, frm UnitID actor, frm Bool charging) -> OrksMoveSelection:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[actor].owned_by_player1
    while orks_move_cards_remaining(board, actor, charging):
        actions:
            act finish_orks_move_selection()
                break
            act choose_orks_move_stratagem(frm Stratagem move_card) {orks_move_card_valid(board, actor, move_card, charging)}
                board.commit_stratagem(board[actor].owned_by_player1, move_card, board[actor])
                if move_card == Stratagem::orks_fungus_fuel_injection:
                    grant_orks_payload(board, actor, actor, 300 + move_card.value, characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2), SourceDuration::phase)
                else:
                    frm effect : RuleEffectKind
                    effect = RuleEffectKind::mobile
                    if move_card == Stratagem::orks_ere_we_go:
                        effect = RuleEffectKind::advance_plus_two
                    grant_orks_effect(board, actor, actor, 300 + move_card.value, effect, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Mind Mostly on the Mission triggers only after selecting Advance/Fall Back,
# and waives only those action-start restrictions (Taktikal Brigade source).
act orks_move_mode(ctx Board board, frm UnitID actor, frm MovementKind kind) -> OrksMoveMode:
    if board[actor].owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::movement) or !orks_taktikal_unit(board[actor]) or !(kind == MovementKind::advance or kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape) or !board.can_target_strat(board[actor].owned_by_player1, Stratagem::orks_mind_mostly_on_the_mission, board[actor]):
        return
    actions:
        act decline_mind_on_mission()
        act mind_on_mission()
            board.commit_stratagem(board[actor].owned_by_player1, Stratagem::orks_mind_mostly_on_the_mission, board[actor])
            grant_orks_effect(board, actor, actor, 300 + Stratagem::orks_mind_mostly_on_the_mission.value, RuleEffectKind::action_move_permission, 1, SourceDuration::phase, invalid_entity_identity())

# The Da Big Hunt CP target is an engaged friendly Beast Snagga unit; the
# enemy mover is a separate subject and may not pay/receive the stratagem.
fun orks_escape_target_valid(Board board, UnitID mover, UnitID snaggas) -> Bool:
    return mover.get() < board.units.size() and snaggas.get() < board.units.size() and board.timing.phase == BattlePhase::movement and board[snaggas].owned_by_player1 != board.current_player and board[mover].owned_by_player1 != board[snaggas].owned_by_player1 and board[snaggas].has_keyword(Keyword::beast_snagga) and board[snaggas].is_engaged_with(board[mover]) and board.can_target_strat(board[snaggas].owned_by_player1, Stratagem::orks_where_d_ya_fink_you_re_going, board[snaggas])

# Recheck the current engagement before exposing the reaction, preserving
# actual fall-back selection timing and controller ownership (source card).
fun orks_escape_reaction_available(Board board, UnitID mover) -> Bool:
    let target : UnitID
    for index in range(board.units.size()):
        target = index
        if orks_escape_target_valid(board, mover, target):
            return true
    return false

# Accepted reaction forces the Desperate Escape mode before hazard rolls;
# the printed unit-granted rule remains active for this Movement phase.
act orks_fallback_selection(ctx Board board, frm UnitID mover) -> OrksFallbackSelection:
    if !orks_escape_reaction_available(board, mover):
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = !board[mover].owned_by_player1
    actions:
        act decline_hunting_escape()
        act choose_hunting_escape_unit(frm UnitID hunters) {orks_escape_target_valid(board, mover, hunters)}
            board.commit_stratagem(board[hunters].owned_by_player1, Stratagem::orks_where_d_ya_fink_you_re_going, board[hunters])
            grant_orks_effect(board, hunters, hunters, 300 + Stratagem::orks_where_d_ya_fink_you_re_going.value, RuleEffectKind::hunt_escape_hazards, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Measured targets must be live battlefield units; no external range or LOS
# exists to reserves/passengers (appendix01.02.04). Self-targeting is allowed
# for Keep Huntin' because a unit is within its own range.
fun orks_move_target_valid(Board board, SourceInstance instance, UnitID target) -> Bool:
    if target.get() < 0 or target.get() >= board.units.size() or board[target].off_battlefield or !has_live_damage_recipient(board[target]):
        return false
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if !location.found or location.bank.value != SourceBank::battlefield.value:
        return false
    ref source = source_bank_unit(board, location.bank, location.unit.value)
    if source.off_battlefield or !has_live_damage_recipient(source):
        return false
    if instance.rule.value == 147:
        return orks_race_target(board, source, target)
    if instance.rule.value == ORKS_KEEP_HUNTIN_RULE or instance.rule.value == ORKS_INTIMIDATING_RULE:
        return board[target].owned_by_player1 == instance.owner and (board[target].has_keyword(Keyword::beast_snagga) and instance.rule.value == ORKS_KEEP_HUNTIN_RULE or board[target].has_keyword(Keyword::orks) and instance.rule.value == ORKS_INTIMIDATING_RULE) and source.distance(board[target]) <= 6.0
    if instance.rule.value == ORKS_BOMB_SQUIG_RULE:
        return board[target].owned_by_player1 != instance.owner and source.distance(board[target]) <= 12.0 and unit_visible_to_unit(board, source, board[target])
    return false

# An optional ability with no legal target cannot introduce an input deadlock.
# Keep source handles separate from UnitID selectors (editor action contract).
fun orks_move_source_has_target(Board board, SourceInstance instance) -> Bool:
    let found = false
    let target : UnitID
    for index in range(board.units.size()):
        target = index
        found = found or orks_move_target_valid(board, instance, target)
    return found

# Movement dispatch includes ordinary grants and both targeted Orks abilities
# in the same controller/order group (user-supplied Rules Sequencing).
fun orks_move_source_valid(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> Bool:
    if !pending_source_valid(board, pending, event, player):
        return false
    ref instance = board.source_instances[pending[event.value].source.value]
    if instance.rule.value == ORKS_KEEP_HUNTIN_RULE or instance.rule.value == ORKS_INTIMIDATING_RULE or instance.rule.value == ORKS_BOMB_SQUIG_RULE or instance.rule.value == 147:
        return orks_move_source_has_target(board, instance)
    return true

# Keep the same mandatory/optional semantics as ordinary source events while
# excluding unavailable target selectors (Rules Sequencing; source timings).
fun orks_move_sources_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    let found = false
    let event : SourceEventID
    for index in range(pending.size()):
        event = index
        if orks_move_source_valid(board, pending, event, player) and (!mandatory_only or !board.source_instances[pending[index].source.value].optional):
            found = true
    return found

# Accepted Keep Huntin' removes shock immediately and installs a persistent
# riled grant until the next own turn; source death must not end it early.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss (Keep Huntin'!).
fun commit_orks_keep_huntin(Board board, PendingSourceEvents pending, SourceEventID event, Bool player, UnitID target):
    assert(orks_move_source_valid(board, pending, event, player), "Keep Huntin' unavailable")
    ref instance = board.source_instances[pending[event.value].source.value]
    assert((instance.rule.value == ORKS_KEEP_HUNTIN_RULE or instance.rule.value == ORKS_INTIMIDATING_RULE) and orks_move_target_valid(board, instance, target), "invalid Keep Huntin' target")
    commit_source_effect_to_unit(board, instance, pending[event.value].source.value, board[target].identity)
    board[target].battle_socked = false
    pending[event.value].resolved = true

# Selected movement-source ability: Race/Keep Huntin/Bomb Squig/Mek/Shokk-boosta, with existing core damage/hazard procedures (Orks cards; pp24/87).
act orks_resolve_movement_source(ctx Board board, ctx PendingSourceEvents pending, frm SourceEventID event, frm Bool player) -> OrksMovementSource:
    frm source_index : SourceInstanceID
    source_index = pending[event.value].source.value
    if board.source_instances[source_index.value].rule.value == 147:
        act choose_race_target(frm UnitID race_target) {orks_move_source_valid(board, pending, event, player), orks_move_target_valid(board, board.source_instances[source_index.value], race_target)}
        pending[event.value].resolved = true
        commit_orks_race(board, board.source_instances[source_index.value], race_target)
    else:
        if board.source_instances[source_index.value].rule.value == ORKS_KEEP_HUNTIN_RULE or board.source_instances[source_index.value].rule.value == ORKS_INTIMIDATING_RULE:
            act choose_keep_huntin_target(frm UnitID hunt_target) {orks_move_source_valid(board, pending, event, player), orks_move_target_valid(board, board.source_instances[source_index.value], hunt_target)}
            commit_orks_keep_huntin(board, pending, event, player, hunt_target)
        else:
            if board.source_instances[source_index.value].rule.value == ORKS_BOMB_SQUIG_RULE:
                act choose_bomb_squig_target(frm UnitID bomb_target) {orks_move_source_valid(board, pending, event, player), orks_move_target_valid(board, board.source_instances[source_index.value], bomb_target)}
                commit_source_usage(board, board.source_instances[source_index.value])
                pending[event.value].resolved = true
                frm location = locate_source(board, board.source_instances[source_index.value].source_unit, invalid_entity_identity())
                frm bomb_source : UnitID
                bomb_source = location.unit.value
                act roll(Dice bomb_result)
                if bomb_result.value >= 3:
                    board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
                    subaction* board.shared_actions.evaluate_random_stat
                    frm bomb_damage_result_snapshot_1 = board.shared_actions.evaluate_random_stat.result
                    frm amount : CombatCounter
                    amount = bomb_damage_result_snapshot_1.value
                    board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, bomb_target, bomb_source, true, amount)
                    subaction*(board) board.shared_actions.resolve_mortal_wounds
            else:
                if board.source_instances[source_index.value].rule.value == ORKS_MEK_REPAIR_RULE:
                    pending[event.value].resolved = true
                    subaction*(board) mek_repair = repair_orks_vehicle(board, board.source_instances[source_index.value])
                else:
                    if board.source_instances[source_index.value].rule.value == ORKS_SHOKK_BOOST_RULE:
                        pending[event.value].resolved = true
                        frm boost_location = locate_source(board, board.source_instances[source_index.value].source_unit, invalid_entity_identity())
                        frm boosting_unit : UnitID
                        boosting_unit = boost_location.unit.value
                        frm boost_hazards : HazardousUses
                        for member_index in range(board[boosting_unit].models.size()):
                            if board[boosting_unit][member_index].is_alive():
                                boost_hazards = boost_hazards + 1
                        board.shared_actions.resolve_hazards = resolve_hazards(board, boosting_unit, boost_hazards)
                        subaction*(board) board.shared_actions.resolve_hazards
                    else:
                        commit_pending_source(board, pending, event, player)
        board.current_decision_maker = player

# Pulse Jet selection and D6+18 budget are Orks special-move rules, offered alongside ordinary move modes (Orks index).
act orks_special_move_choice(ctx Board board, frm UnitID id) -> OrksSpecialMoveChoice:
    frm kind : MovementKind
    frm extra : StatModifier
    frm started = false
    actions:
        act pulse_jet_move() {battlefield_move_eligible(board, id, MovementKind::pulse_jet), orks_special_move_available(board, board[id], MovementKind::pulse_jet)}
            started = true
            kind = MovementKind::pulse_jet
            act roll(Dice pulse_roll)
            extra = pulse_roll.value + 18

# Shokk-boosta is selected before the ordinary Advance roll (Orks/Big-Mek).
act orks_prepare_advance(ctx Board board, frm UnitID id) -> OrksPrepareAdvance:
    if board.timing.phase == BattlePhase::movement and board[id].owned_by_player1 == board.current_player and board[id].has_ability(AbilityKind::shokk_boosta):
        act use_shokk_boosta(Bool boost_move)
        board[id].shokk_boosta_move = boost_move

# Shokk six and Unstoppable Advance can replace the rerolled face before the remaining move bonuses (Orks/Big-Mek/Blitz Brigade).
act orks_modify_advance_roll(ctx Board board, frm UnitID id) -> OrksModifyAdvanceRoll:
    if board[id].shokk_boosta_move:
        act use_shokk_six(Bool change_to_six)
        if change_to_six:
            board.current_roll.result = 6
    if orks_package(board, board[id], OrksDetachment::blitz_brigade) and board[id].has_keyword(Keyword::wagon):
        act use_unstoppable_advance(Bool six_instead)
        if six_instead:
            board.current_roll.result = 6

# Completed-move wagon, passenger and enemy reactions use shared reactive movement; preserve original source order (Orks cards).
act orks_after_move(ctx Board board, frm UnitID id) -> OrksAfterMove:
    board.shared_actions.orks_wagon_move_end = orks_wagon_move_end(board, id)
    subaction*(board) board.shared_actions.orks_wagon_move_end
    subaction*(board) trukk_reactions = orks_trukk_reactions(board, id)
    while orks_enemy_move_available(board, id):
        board.shared_actions.select_orks_enemy_move_reaction = select_orks_enemy_move_reaction(board, id)
        subaction*(board) board.shared_actions.select_orks_enemy_move_reaction
        frm reply_available_snapshot_11 = board.shared_actions.select_orks_enemy_move_reaction.available
        frm reply_distance_snapshot_11 = board.shared_actions.select_orks_enemy_move_reaction.distance
        frm reply_target_snapshot_11 = board.shared_actions.select_orks_enemy_move_reaction.target
        if !reply_available_snapshot_11:
            break
        board.shared_actions.granted_move = reactive_move(board, reply_target_snapshot_11, reply_distance_snapshot_11, false)
        subaction*(board) board.shared_actions.granted_move

# Own-unit psychic/datasheet/support choices use their real banks alongside core Movement choices (Orks cards;01.02.04).
act orks_movement_phase_choice(ctx Board board) -> OrksMovementPhaseChoice:
    frm started = false
    actions:
        act use_orks_offboard_dread_power() {orks_offboard_dread_power_available(board, SourceBank::reserves, board.current_player) or orks_offboard_dread_power_available(board, SourceBank::embarked, board.current_player)}
            started = true
            subaction*(board) power = choose_orks_offboard_dread_power(board, board.current_player)
        act use_orks_offboard_watchin() {orks_offboard_support_available(board, SourceBank::reserves, board.current_player, false) or orks_offboard_support_available(board, SourceBank::embarked, board.current_player, false)}
            started = true
            board.shared_actions.choose_orks_offboard_support = choose_orks_offboard_support(board, board.current_player, false)
            subaction*(board) board.shared_actions.choose_orks_offboard_support
        act use_orks_datasheet_movement(frm UnitID datasheet_unit) {orks_datasheet_move_any(board, datasheet_unit)}
            started = true
            subaction*(board) datasheet_move = orks_datasheet_movement(board, datasheet_unit)
        act use_orks_movement_support(frm UnitID support_unit) {orks_phase_support_available(board, support_unit)}
            started = true
            subaction*(board) support = orks_phase_support(board, support_unit)

# Assault Disembark and Gut Hatch grant specific post-move charge permission (Orks transport cards).
fun orks_assault_disembark(Board board, Unit carrier_unit) -> Bool:
    return unit_rule_effect(board, carrier_unit, RuleEffectKind::assault_disembark) > 0 or carrier_unit.has_ability(AbilityKind::gut_hatch) and carrier_unit.history.move_kind == MovementKind::normal

# Minefield Detail supplies Scouts6; all combined printed Scouts values must match (Orks/Taktikal Brigade; user ruling).
fun orks_scouts_override(Unit unit) -> Int:
    if unit_has_orks_enhancement(unit, OrksEnhancement::minefield_detail) and unit.embarked_transport.value == 0:
        for member in range(unit.models.size()):
            for entry in range(unit[member].scout_distances.size()):
                assert(unit[member].scout_distances[entry].value == 6, "Scouts values must all be identical")
        return 6
    return -1

# Completed Pulse Jet installs its source-owned charge/action/defence effects (Orks Pulse Jet Move).
fun orks_record_move_effects(Board board, UnitID id, MovementKind kind):
    if kind == MovementKind::pulse_jet:
        board[id].can_charge = false
        grant_orks_effect(board, id, id, 173, RuleEffectKind::no_charge, 1, SourceDuration::turn, invalid_entity_identity())
        grant_orks_effect(board, id, id, 174, RuleEffectKind::no_action, 1, SourceDuration::turn, invalid_entity_identity())
        grant_orks_effect(board, id, id, 175, RuleEffectKind::pulse_defence, 1, SourceDuration::next_own_turn, invalid_entity_identity())

# Pulse Engine supplies Pulse Jet selection permission (Orks/Wazdakka).
fun orks_special_move_available(Board board, Unit unit, MovementKind kind) -> Bool:
    return kind == MovementKind::pulse_jet and unit_rule_effect(board, unit, RuleEffectKind::pulse_engine) > 0

# Shokk-boosta permits model traversal without granting FLY or terrain traversal (Orks/Big-Mek).
fun orks_prepare_movement_policy(Unit unit, MovementKind kind, MovementGeometryPolicy policy):
    if kind == MovementKind::advance and unit.shokk_boosta_move:
        policy.traverse_enemies = true
        policy.exclude_titanic = false
        policy.exclude_monster_vehicle = false

# Pulse Jet traversal overrides remain separate from ordinary FLY/Walker costs (Orks Special Move Types).
fun orks_finish_movement_policy(MovementKind kind, MovementGeometryPolicy policy):
    if kind == MovementKind::pulse_jet:
        policy.traverse_enemies = true
        policy.traverse_terrain = true
        policy.free_vertical_movement = true
        policy.exclude_titanic = false
        policy.exclude_monster_vehicle = false
