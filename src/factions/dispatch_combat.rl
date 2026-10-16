import factions.orks.combat
import factions.orks.morale
import factions.orks.queries


# Combat/morale extension contract. UnitID indexes battlefield units; bearer
# and slot index source models/equipment. Stable-identity responses can locate
# other banks explicitly. Queries are pure. Appenders contribute to initialized
# caller-owned snapshots without rolling/paying or erasing unrelated sources.
# Action hooks own their choices/CP/use; core owns attack/damage execution and
# casualty removal. Frames borrow original contexts. Read results after completion;
# peer started flags are read after one input. See README.md for shared lifetimes.

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

# Contribute configuration/source-granted weapon-rule instances for the actual
# equipped slot of battlefield source[bearer], with zero-based valid indices.
# result already contains intrinsic/earlier contributions; preserve their
# conditions/keys. May append or apply specified numeric-instance increments;
# core owns later duplicate selection. No applicable contribution is a no-op.
fun append_faction_package_weapon_rules(Board board, UnitID source, Int bearer, Int slot, WeaponAbilitySet result):
    append_orks_package_weapon_rules(board, source, bearer, slot, result)

# Explicit-profile variant: source/bearer are the model making the attack,
# selected is its used profile and name the physical weapon family. The profile
# can be borrowed and absent from the source's slots. Apply the same contextual
# contributions without substituting a coincidentally matching equipped slot;
# preserve prior result instances and source provenance.
fun append_faction_package_weapon_rules(Board board, UnitID source, Int bearer, Weapon selected, WeaponCode name, WeaponAbilitySet result):
    append_orks_package_weapon_rules(board, source, bearer, selected, name, result)

# Append source/bearer/weapon-dependent arithmetic for kind on declaration.
# Core has resolved the bearer and seeded common model/weapon modifiers;
# it calls this before datasheet contributions and final evaluation/grouping.
# Preserve prior modifiers and their operation/source metadata; default no-op.
fun append_faction_declaration_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_declaration_modifiers(board, source, declaration, kind, result)

# Augment initialized info for the actual source/target/declaration group
# with applicable modifiers, reroll permissions and conditional attack facts.
# Preserve common facts except where an explicit rule overrides one; keep
# individually ignorable modifier provenance. Core compares group snapshots
# and resolves dice later, so this hook must not roll, spend or mutate Board.
fun append_faction_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo info):
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

# Return a live battlefield recipient unit index for rolled-hit interception,
# or -1 for none; index 0 is valid. Core also uses presence to defer Lethal Hits
# conversion until interception. Keep this lookup consistent with the interceptor
# action; a query must not cancel hits or apply damage.
fun faction_hit_interceptor(Board board, Unit unit) -> Int:
    return orks_grot_shield(board, unit)

# Resolve additional own-Shooting attack choices after attack-selection effects
# and before weapon/target declarations. Finish required rolls/grants before
# declarations snapshot their effects. Return completed if inapplicable; do not
# declare weapons or resolve their attacks inside this child.
fun faction_pre_declaration_options(Board board, UnitID source) -> OrksShokkaSelection:
    return orks_shokka_selection(board, source)

# Resolve additional own-Shooting completion effects after all declared groups
# and hit-results hooks, before selected-weapon Hazardous checks. The current
# activation ledger is still available. Complete required choices/damage using
# shared procedures; do not close the ledger or start a nested shared Attack.
fun faction_shooting_finished(Board board, UnitID source) -> OrksShootingOptionEnd:
    return orks_shooting_option_end(board, source)

# Resolve optional support at unit Shooting selection before core marks source
# as having shot. Accepted support owns its target/use/grants but does not consume
# ordinary shooting by itself. Complete nested choices and restore decision
# ownership; return completed if no support applies.
fun faction_shooting_support(Board board, UnitID source) -> OrksDreadherderShooting:
    return orks_dreadherder_shooting(board, source)

# Compatibility gate for engagement treated exceptionally by two consumers:
# true relaxes core's engaged-target shooting restriction and lets an unshocked
# unit skip Desperate Escape hazards. Grant only when both meanings apply;
# false preserves ordinary checks. This Boolean cannot express them separately.
fun faction_engagement_exception(Board board, Unit unit) -> Bool:
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
fun faction_hit_results(Board board, UnitID source) -> OrksHitEffects:
    return orks_resolve_hit_effects(board, source)

# Resolve extra datasheet choices when source is selected to fight, before
# Pile In/Overrun and melee weapon declarations. Finish resource tests/grants
# needed by those later steps. Return completed if inapplicable; do not perform
# the ordinary pile-in or attack sequence here.
fun faction_datasheet_fight_selection(Board board, UnitID source) -> OrksDatasheetFightSelection:
    return orks_datasheet_fight_selection(board, source)

# Resolve remaining selected-to-fight weapon-related choices before Pile In/
# Overrun and weapon declarations, after datasheet_fight_selection. Accepted
# effects must be ready for later weapon/Hazardous snapshots. Do not declare
# weapons or run attacks; return completed when no extra choice applies.
fun faction_melee_weapon_selection(Board board, UnitID source) -> OrksRokkitSelection:
    return orks_rokkit_selection(board, source)

# Append unit/datasheet-granted instances for selected to result after earlier
# weapon-rule contributions. Preserve parameters, conditions and source keys;
# core chooses duplicate instances later. The explicit profile may be borrowed:
# do not assume it occupies a source equipment slot. Default no-op.
fun append_faction_datasheet_weapon_rules(Board board, UnitID source, Weapon selected, WeaponAbilitySet result):
    append_orks_datasheet_weapon_rules(board, source, selected, result)

# Append datasheet arithmetic for kind using declaration's actual bearer and
# weapon provenance. result already contains common, intrinsic and package
# contributions; preserve them. Core evaluates modifier ordering, bounds and
# identical-attack grouping. This is a pure contribution, not an activation.
fun append_faction_datasheet_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_datasheet_modifiers(board, source, declaration, kind, result)

# Resolve additional attacker/defender choices once a target is configured
# for declared attacks, before refreshing target attack info and gathering dice.
# Check target/mode eligibility and commit accepted costs/effects. Core can
# revisit targets while resolving declarations; apply actual usage limits and
# restore decision ownership without starting a nested ordinary Attack.
fun faction_attack_targeted(Board board, UnitID source, UnitID target, Bool melee) -> OrksAttackTargeted:
    return orks_attack_targeted(board, source, target, melee)

# Resolve cancellation of up to count original rolled hits against target.
# Recheck recipient availability as each cancellation/effect resolves; generated
# Sustained Hits are excluded by core. Return intercepted in [0,count] after
# completion for core subtraction, including any mandatory shared damage/death
# processing. No eligible interception completes with intercepted == 0.
fun intercept_faction_hits(Board board, UnitID target, CombatCounter count) -> OrksHitInterception:
    return intercept_orks_hits(board, target, count)

# Return the absolute allocation-specific InSv target for model against info,
# starting from model.effective_invulnerable_save() if no extra permission applies.
# Lower is better; above 6 means none. Core uses this to group eligible recipients
# and select saves. This is not an arithmetic modifier, a roll or model mutation.
fun faction_allocation_invulnerable(Unit unit, Model model, AttackSequenceInfo info) -> Int:
    return orks_allocation_invulnerable(unit, model, info)

# Resolve responses immediately after subject becomes Battle-shocked. subject
# is a stable unit identity; locate its actual bank and re-resolve after nested
# damage/transfers. Apply accepted costs/effects through shared procedures,
# restore decision ownership and return completed if subject/rules are absent.
# Core owns the original test and any frozen recovery eligibility.
fun faction_became_shocked(Board board, EntityIdentity subject) -> OrksBecameShocked:
    return orks_became_shocked(board, subject)

# Battlefield-slot entrypoint for the same became-shocked response contract.
# Translate target to a stable unit identity before any suspension/bank change;
# do not maintain a second offboard rules path. An absent slot may return
# completed; this does not roll a new test or automatically recover shock.
fun faction_became_shocked(Board board, UnitID target) -> OrksBecameShocked:
    return orks_became_shocked(board, target)

# Resolve additional effects at the Command Battle-shock STEP boundary, after
# core CP gain and before core freezes test/recovery eligibility for all banks.
# Complete accepted choices before returning; do not run ordinary unit tests or
# move this boundary to Command-phase start. Inapplicable rules complete silently.
fun faction_before_battle_shock(Board board) -> OrksMobMentalityStep:
    return orks_mob_mentality_step(board)

# Resolve extension choices before a retained casualty is removed. event gives
# its actual bank/unit; casualty is the caller-owned retained model. After child
# completion, core reads suppress_demise and crash_mortals, using the legacy-named
# headbutt_recipient only if crash_mortals > 0. Return zero mortals/false suppression
# for no replacement effect. Core queues that damage and performs removal/order;
# do not remove the casualty or re-enter the active damage resolver here.
fun faction_before_destruction(Board board, Model casualty, PendingDestruction event) -> OrksBeforeDestruction:
    return orks_before_destruction(board, casualty, event)

# Return a nonnegative number of additional Hazardous uses beyond the selected
# physical-weapon uses, or zero. Core checks/resolves this after the ordinary
# Hazardous batch. This is a roll count, not damage; do not roll, spend or mutate
# source usage inside a query that core may evaluate twice.
fun faction_extra_attack_hazards(Board board, Unit unit) -> Int:
    return orks_extra_attack_hazards(board, unit)

# Return permission for the current Battle-shock test to succeed without a
# roll. Core determines whether a test is needed and whether success can recover
# shock from its frozen step eligibility. Return false for ordinary resolution;
# do not clear shock or consume source use merely by checking permission.
fun faction_automatic_shock_success(Board board, Unit unit) -> Bool:
    return orks_automatic_shock_success(board, unit)

# Return a nonnegative penalty subtracted from the Leadership roll TOTAL,
# or zero. Core combines this with other penalties and applies the roll minimum
# before comparison with effective Ld. Do not change Ld, roll dice or apply shock
# here; this query may operate on an offboard unit.
fun faction_leadership_roll_penalty(Board board, Unit unit) -> Int:
    return orks_leadership_roll_penalty(board, unit)

# Peer menu for additional Shooting-phase activations beside core choices.
# Construction changes no shared state, including when it offers no enabled
# input. Set started on acceptance, complete that atomic activation and return
# to the core phase menu; only core can finish the phase/ordinary shooting.
fun faction_shooting_phase_choice(Board board) -> OrksShootingPhaseChoice:
    return orks_shooting_phase_choice(board)

# After all weapons/targets are declared but before any attack group resolves,
# complete declaration-dependent choices/effects. declarations is the original
# context, not a new declaration menu. Return effect, a scoped grant key for core
# cleanup after all groups (0 means none). Do not resolve attacks or erase
# unrelated grants; one key is the current result interface's supported scope.
fun faction_declarations_complete(Board board, DeclaredWeapons declarations, UnitID source, Bool melee) -> OrksDeclarationsComplete:
    return orks_declarations_complete(board, declarations, source, melee)

# Peer menu for one pending extension charge-end effect, interleaved with core
# charge effects. Construct without shared-state mutation, set started on first
# input and update the original progress before completing that effect. Core
# owns crushing_pending; do not clear it or reset sibling progress. The selected
# child completes before core offers another ordering choice.
fun faction_charge_choice(Board board, FactionChargeProgress progress, Bool crushing_pending, UnitID source) -> OrksChargeChoice:
    return orks_charge_choice(board, progress, crushing_pending, source)

# Snapshot extension charge-end triggers after source completes its charge,
# before the ordered charge-effect menu opens. Return only pending progress;
# do not resolve effects, consume use or roll. The choice and remaining-work
# hooks must interpret this same snapshot and clear only completed choices.
fun faction_charge_progress(Board board, UnitID source) -> FactionChargeProgress:
    return orks_charge_progress(board, source)

# Report unresolved extension work in progress. Core ORs this with common
# charge-effect work before offering/finishing the menu. Return false when
# exhausted; do not include core-owned work, clear flags or recompute eligibility
# from a later battlefield state in place of the captured progress.
fun faction_charge_effects_remaining(FactionChargeProgress progress) -> Bool:
    return orks_charge_effects_remaining(progress)

# Return whether this source contributes one additional, individually
# ignorable +1 HIT-ROLL term. Core snapshots the Boolean and applies its ordinary
# modifier selection/cap, independently of WS/BS and other +1 sources. Return
# false for none; this interface cannot express a magnitude other than +1.
fun faction_innate_hit_bonus(Unit unit) -> Bool:
    return orks_innate_hit_bonus(unit)

# Resolve extra choices at attack activation start, before common attack-
# selection events and declarations. melee identifies the mode. Snapshot any
# selection-time facts and commit accepted tokens/CP/grants; later grouping reads
# them. Complete nested effects and leave the ordinary attack/declarations to core.
fun faction_attack_selection_options(Board board, UnitID source, Bool melee) -> OrksAttackSelectionOptions:
    return orks_attack_selection_options(board, source, melee)

# Append unit-local characteristic arithmetic for kind before the declaration
# and datasheet modifier hooks. This signature has no weapon/target context;
# contribute only terms valid at that scope, preserving earlier result entries.
# Core performs operation ordering/caps. No contribution is a no-op.
fun append_faction_intrinsic_modifiers(Board board, UnitID source, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_intrinsic_modifiers(board, source, kind, result)

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
