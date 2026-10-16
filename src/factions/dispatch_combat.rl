import factions.orks.combat
import factions.orks.morale
import factions.orks.queries
import factions.legacy.combat

# Calculation/event-specific contracts for any army implementation. Queries
# are pure; appenders mutate only their initialized output. Actions borrow
# original contexts, finish accepted work atomically and restore controller
# ownership. Core owns common mechanics, sequencing and frame lifetime.
# See README.md and doc/army-api.md; named rule citations belong in adapters.

# Report that this battlefield casualty requires extension destruction
# processing before removal. Core combines this with common destruction,
# transport and retention needs. This is trigger presence, not execution or
# proof that an optional effect can currently be selected; default false.
fun faction_has_destruction_trigger(Board board, Model model) -> Bool:
    return orks_has_destruction_trigger(board, model)

# Report that this unit/model requires a whole-unit destruction event.
# Core calls after wound loss and issues the event only on actual last-model
# destruction, once per unit. Return false when no such extension event is
# needed; do not emit events, pay or remove the casualty here.
fun faction_unit_destruction_trigger(Board board, Unit unit, Model model) -> Bool:
    return orks_unit_destruction_trigger(board, unit, model)

# Report additional destruction processing required for this offboard model.
# Core retains the casualty and runs the common bank-aware destruction pipeline.
# Return false for none; do not grant external visibility/range or assume a
# battlefield location merely because an own-unit death effect is permitted.
fun faction_offboard_destruction_trigger(Model model) -> Bool:
    return orks_offboard_destruction_trigger(model)

# Append contextual weapon-rule instances for the actual bearer and selected
# profile/family, including a borrowed profile absent from its equipment slots.
# Core has seeded printed/per-slot/unit rules. Preserve existing conditions,
# parameters and independent origins; duplicate selection remains core (p78).
# Pure: mutate only rules; do not roll, pay or alter Board (Firing Deck p81).
fun append_weapon_rules(Board board, UnitID source, Int bearer, Weapon profile, WeaponCode family, WeaponAbilitySet rules):
    append_orks_weapon_rules(board, source, bearer, profile, family, rules)

# Append all characteristic terms for an actual declared weapon, preserving
# bearer/physical-copy provenance. Core evaluates order, caps and attack identity
# after this pure calculation (core p17; appendix02.02.01).
fun append_weapon_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers modifiers):
    append_orks_weapon_modifiers(board, source, declaration, kind, modifiers)

# Append unit-wide hit-roll terms, including retained component conferral.
# Repeated queries never alter Board. Core keeps each term individually
# ignorable and applies the cumulative cap (core p18; appendix02.02.02).
fun append_unit_hit_modifiers(Unit unit, RuleModifiers modifiers):
    append_orks_unit_hit_modifiers(unit, modifiers)

# Append target/declaration-specific attack modifiers and permissions to the
# caller's initialized snapshot. Preserve prior terms, individual ignore
# choices and frozen selection facts. Pure: no Board, dice or CP/use changes.
# Core owns ordered arithmetic, grouping and rolls (core pp17-19).
fun append_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo info):
    append_orks_attack_effects(board, source, target, weapon, info)

# Read a model-local grant requiring its containing unit/attachment context.
# Core ORs this with Model.has_ability for eligible models during unit any/all
# aggregation. Return false when absent; do not promote a bearer-only grant to
# every member. Core supplies the live/retained-source aggregation boundary.
fun faction_model_grants_ability(Unit unit, Model model, AbilityKind kind) -> Bool:
    return orks_model_grants_ability(unit, model, kind)

# Return the unit's complete effective Lone Operative permission, including
# its ordinary ability and conditional grants. Core uses this directly for
# detection/target range gating; false means no such protection. Evaluate grant
# source/attachment/proximity conditions here without changing stored abilities.
fun faction_lone_operative(Board board, Unit unit) -> Bool:
    return orks_lone_operative(board, unit)

# Return a minimum D6 result permitting this model to Fight on Death, or 0
# for no grant. Core queries before committing wound loss, rolls only on actual
# destruction, and retains a successful model without rerolling on selection.
# Check source, phase and already-fought restrictions here; do not roll or
# remove the model. Unit/model can be supplied from any damage bank.
fun faction_fight_death_threshold(Board board, Unit unit, Model model) -> Int:
    return orks_fight_death_threshold(board, unit, model)

# Resolve additional own-Shooting attack choices after attack-selection effects
# and before weapon/target declarations. Finish required rolls/grants before
# declarations snapshot their effects. Return completed if inapplicable; do not
# declare weapons or resolve their attacks inside this child.
fun before_weapon_declarations(Board board, UnitID source) -> OrksShokkaSelection:
    return orks_shokka_selection(board, source)

# Resolve additional own-Shooting completion effects after all declared groups
# and hit-results hooks, before selected-weapon Hazardous checks. The current
# activation ledger is still available. Complete required choices/damage using
# shared procedures; do not close the ledger or start a nested shared Attack.
fun on_shooting_attacks_finished(Board board, UnitID source) -> OrksShootingOptionEnd:
    return orks_shooting_option_end(board, source)

# Resolve optional support at unit Shooting selection before core marks source
# as having shot. Accepted support owns its target/use/grants but does not consume
# ordinary shooting by itself. Complete nested choices and restore decision
# ownership; return completed if no support applies.
fun on_unit_selected_to_shoot(Board board, UnitID source) -> OrksDreadherderShooting:
    return orks_dreadherder_shooting(board, source)

# Waive only the target engagement restriction for this shooting query.
# Range, visibility, mode, ownership and all other gates still apply (core p35).
# Pure additional permission; false leaves the ordinary restriction in force.
fun permits_shooting_at_engaged_unit(Board board, Unit unit) -> Bool:
    return orks_engaged_only_fortifications(board, unit)

# Return an additional partial-obscuration condition between observer/target
# when ordinary terrain-area checks have not supplied one. False adds nothing;
# true feeds common cover eligibility, not complete physical invisibility.
# Use the project's circular geometry approximation and leave Board unchanged.
fun faction_intervening_cover(Board board, Model observer, Model target) -> Bool:
    return orks_ramshackle_obscures(board, observer, target)

# Report that observer's attacks confer cover on the target unit independently
# of individual target-model terrain conditions. Core uses true as a unit-cover
# short circuit, so check the full observer-side condition. False leaves normal
# per-model cover checks intact; do not alter visibility or target state.
fun faction_observer_grants_cover(Board board, Model observer) -> Bool:
    return orks_wobbled_observer(board, observer)

# After declared attacks and destruction cleanup, before shooting-finished and
# Hazardous, resolve effects requiring actual successful hits. Read the current
# activation ledger and weapon tags, not merely declared targets. Finish chosen
# targets/grants before returning; leave ledger closure and damage engines to core.
fun on_successful_attacks_finished(Board board, UnitID source) -> OrksHitEffects:
    return orks_resolve_hit_effects(board, source)

# Resolve extra datasheet choices when source is selected to fight, before
# Pile In/Overrun and melee weapon declarations. Finish resource tests/grants
# needed by those later steps. Return completed if inapplicable; do not perform
# the ordinary pile-in or attack sequence here.
fun on_unit_selected_to_fight(Board board, UnitID source) -> OrksDatasheetFightSelection:
    return orks_datasheet_fight_selection(board, source)

# Resolve remaining selected-to-fight weapon-related choices before Pile In/
# Overrun and weapon declarations, after datasheet_fight_selection. Accepted
# effects must be ready for later weapon/Hazardous snapshots. Do not declare
# weapons or run attacks; return completed when no extra choice applies.
fun before_fight_weapon_selection(Board board, UnitID source) -> OrksRokkitSelection:
    return orks_rokkit_selection(board, source)

# Resolve additional attacker/defender choices once a target is configured
# for declared attacks, before refreshing target attack info and gathering dice.
# Check target/mode eligibility and commit accepted costs/effects. Core can
# revisit targets while resolving declarations; apply actual usage limits and
# restore decision ownership without starting a nested ordinary Attack.
fun on_attack_target_selected(Board board, UnitID source, UnitID target, Bool melee) -> OrksAttackTargeted:
    return orks_attack_targeted(board, source, target, melee)

# Resolve cancellation of up to count original rolled hits against target.
# Recheck recipient availability as each cancellation/effect resolves; generated
# Sustained Hits are excluded by core. Return intercepted in [0,count] after
# completion for core subtraction, including any mandatory shared damage/death
# processing. No eligible interception completes with intercepted == 0.
fun on_hit_rolls_resolved(Board board, UnitID target, CombatCounter count) -> OrksHitInterception:
    return intercept_orks_hits(board, target, count)

# Add allocation-specific save permission for the actual recipient/attack.
# Core seeds the effective model save and uses the final permission for save
# groups. Pure; preserve a better permission and all unrelated state (p19).
fun append_allocation_effects(Unit unit, Model model, AttackSequenceInfo attack, InvulnerableSavePermission permission):
    append_orks_allocation_effects(unit, model, attack, permission)

# Battlefield-slot entrypoint for the same became-shocked response contract.
# Translate target to a stable unit identity before any suspension/bank change;
# do not maintain a second offboard rules path. An absent slot may return
# completed; this does not roll a new test or automatically recover shock.
fun on_unit_became_battle_shocked(Board board, EntityIdentity subject) -> OrksBecameShocked:
    return orks_became_shocked(board, subject)

# Battlefield-slot entrypoint for the same became-shocked response contract.
# Translate target to a stable unit identity before any suspension/bank change;
# do not maintain a second offboard rules path. An absent slot may return
# completed; this does not roll a new test or automatically recover shock.
fun on_unit_became_battle_shocked(Board board, UnitID target) -> OrksBecameShocked:
    return orks_became_shocked(board, target)

# Resolve additional effects at the Command Battle-shock STEP boundary, after
# core CP gain and before core freezes test/recovery eligibility for all banks.
# Complete accepted choices before returning; do not run ordinary unit tests or
# move this boundary to Command-phase start. Inapplicable rules complete silently.
fun on_battle_shock_step_start(Board board) -> OrksMobMentalityStep:
    return orks_mob_mentality_step(board)

# At actual last-model destruction, resolve whole-unit abilities before
# removal. event/casualty retain their bank, original component and cause.
# Return demise suppression and ordered standard damage jobs; core queues
# them before removal without re-entering the active damage frame (core p87).
# No applicable ability completes with an empty result.
fun on_unit_destroyed(Board board, Model casualty, PendingDestruction event) -> OrksBeforeDestruction:
    return orks_before_destruction(board, casualty, event)

# Resolve model-destruction compatibility abilities for this actual killer
# and retained casualty. An empty killer is explicit. This existing family
# applies on the battlefield; shared source triggers handle all permitted banks.
# Return generated_mortal for the core job runner; never remove the casualty
# or recursively resolve damage. Missing abilities complete silently (core p87).
fun on_model_destroyed(Board board, Unit killer, Model casualty) -> OnModelDestroyed:
    return legacy_on_model_destroyed(board, killer, casualty)

# Peer menu for additional Shooting-phase activations beside core choices.
# Construction changes no shared state, including when it offers no enabled
# input. Set started on acceptance, complete that atomic activation and return
# to the core phase menu; only core can finish the phase/ordinary shooting.
fun during_shooting_phase(Board board) -> OrksShootingPhaseChoice:
    return orks_shooting_phase_choice(board)

# Once every weapon/target is declared, resolve declaration-dependent
# abilities before the first group. Borrow the original declarations; return
# independently owned effect keys for cleanup after ALL groups, not one target.
# Core owns grouping/attacks and expiry; no applicable rule returns an empty
# collection (core pp16-19; persisting effects appendix01.02.02).
fun on_targets_declared(Board board, DeclaredWeapons declarations, UnitID source, Bool melee) -> OrksDeclarationsComplete:
    return orks_declarations_complete(board, declarations, source, melee)

# Peer menu for one pending extension charge-end effect, interleaved with core
# charge effects. Construct without shared-state mutation, set started on first
# input and update the original progress before completing that effect. Core
# owns crushing_pending; do not clear it or reset sibling progress. The selected
# child completes before core offers another ordering choice.
fun on_charge_finished(Board board, FactionChargeProgress progress, Bool crushing_pending, UnitID source) -> OrksChargeChoice:
    return orks_charge_choice(board, progress, crushing_pending, source)

# Snapshot extension charge-end triggers after source completes its charge,
# before the ordered charge-effect menu opens. Return only pending progress;
# do not resolve effects, consume use or roll. The choice and remaining-work
# hooks must interpret this same snapshot and clear only completed choices.
fun capture_charge_triggers(Board board, UnitID source) -> FactionChargeProgress:
    return orks_charge_progress(board, source)

# Report unresolved extension work in progress. Core ORs this with common
# charge-effect work before offering/finishing the menu. Return false when
# exhausted; do not include core-owned work, clear flags or recompute eligibility
# from a later battlefield state in place of the captured progress.
fun charge_abilities_pending(FactionChargeProgress progress) -> Bool:
    return orks_charge_effects_remaining(progress)

# Augment only the optional tagged-hit slots of record for count hits in the
# current attack group. Core already added those successful hits to its total;
# do not add them again or report wounds/destruction. Use Board's group context
# for provenance and keep each tag count within recorded successful_hits.
fun record_faction_hit_tags(Board board, AttackResultRecord record, Int count):
    record_orks_hit_tags(board, record, count)

# Resolve after-attack choices using the completed activation ledger and core
# controller order, owning accepted costs/nonattack effects. Return reaction;
# if available is true, its valid source/target/mode must be ready for core's
# flat runner, which executes it after this child completes. Otherwise other
# request fields are unused. Restore decision ownership and never nest Attack;
# core copies the result before reusing the shared reaction frame.
fun faction_post_attack(Board board, UnitID attacker, Bool melee) -> OrksPostAttack:
    return resolve_orks_post_attack(board, attacker, melee)

# Start a ranged attack activation, after unit selection/support and before
# attack-selection source events and declarations. Finish ability choices and
# snapshot grants here; do not execute the ordinary attacks (core pp16-17).
fun on_shooting_attack_start(Board board, UnitID source) -> OrksAttackSelectionOptions:
    return orks_attack_selection_options(board, source, false)

# Start melee attacks after Pile In/Overrun, before source selection events and
# declarations. This differs from selected-to-fight before Pile In (pp38-42).
fun on_fight_attack_start(Board board, UnitID source) -> OrksAttackSelectionOptions:
    return orks_attack_selection_options(board, source, true)

# Configure the pending rolled-hit processing boundary without resolving it.
# True requires completing on_hit_rolls_resolved before critical conversion;
# generated hits remain separate. Pure, default no additional window (pp18/82).
fun append_hit_resolution_policy(Board board, Unit target, HitResolutionPolicy policy):
    append_orks_hit_resolution_policy(board, target, policy)

# Battle-shock has its own calculation: grant test success or append arithmetic
# to the roll total. No shock/recovery, dice or usage mutation here (core p30).
fun append_battle_shock_roll_effects(Board board, Unit unit, BattleShockRollEffects effects):
    append_orks_battle_shock_roll_effects(board, unit, effects)

# Additional checks supplement selected physical-weapon uses at the Hazardous
# boundary. Do not return mortal damage or consume a use here (core p81).
fun append_hazardous_roll_effects(Board board, Unit unit, HazardousRollEffects effects):
    append_orks_hazardous_roll_effects(board, unit, effects)
