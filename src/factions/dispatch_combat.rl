import factions.orks.combat
import factions.orks.morale
import factions.orks.queries

# Combat/morale extension contracts. UnitID indexes battlefield units; bearer
# and slot index the source's models/equipment. Stable EntityIdentity overloads
# can support all banks. Read queries leave state unchanged; appenders modify
# caller-owned output without rolling or paying. Appenders are cumulative:
# do not reapply to the same result as if they were idempotent queries.
# Returned frames borrow contexts and can mutate Board during initialization
# or resumption, except peer menus, which must wait for an accepted input.
# Core owns shared attack, damage, casualty removal and flat reaction execution.
# Concrete rules/citations: orks/{combat,morale,queries}.rl and named Orks cards at
# https://wahapedia.ru/wh40k11ed/factions/orks/; core attack/destruction pp16-24/87.

# Tell core to retain this battlefield casualty for faction destruction
# processing (Surly or Flyboyz Aircraft). Pure trigger-presence query: does not
# resolve the effect or establish a whole-unit destruction event (core p87).
fun faction_has_destruction_trigger(Board board, Model model) -> Bool:
    return orks_has_destruction_trigger(board, model)

# Tell core that losing the last living model requires a unit-destruction
# event for this faction source (Flyboyz Aircraft). Core detects last-model loss
# and issues that event once; this query neither removes models nor pays CP.
fun faction_unit_destruction_trigger(Board board, Unit unit, Model model) -> Bool:
    return orks_unit_destruction_trigger(board, unit, model)

# Retain an offboard casualty for an unmeasured own-unit destruction effect,
# currently Surly. Excludes battlefield-only Aircraft reactions; does not grant
# range/visibility to reserves or passengers (appendix01.02.04).
fun faction_offboard_destruction_trigger(Model model) -> Bool:
    return orks_offboard_destruction_trigger(model)

# Contribute package/effect weapon rules for the actual equipped slot on
# source[bearer] (both indices zero-based). Appends instances and can increment
# existing numeric instances in result; core later selects duplicate abilities
# (Orks detachment rules; core p78). Does not mutate equipment.
fun append_faction_package_weapon_rules(Board board, UnitID source, Int bearer, Int slot, WeaponAbilitySet result):
    append_orks_package_weapon_rules(board, source, bearer, slot, result)

# Explicit-profile variant for borrowed Firing Deck weapons: source/bearer
# are the carrier, selected/name identify the borrowed profile/weapon family.
# Apply carrier package/effect rules without indexing its equipment; may append
# or increment result instances as above (core Firing Deck p81).
fun append_faction_package_weapon_rules(Board board, UnitID source, Int bearer, Weapon selected, WeaponCode name, WeaponAbilitySet result):
    append_orks_package_weapon_rules(board, source, bearer, selected, name, result)

# Append faction numerical contributions for kind on this declared weapon
# before grouping/resolution. Resolve its actual bearer/provenance; do not
# change the stored weapon or apply final rounding/caps here (Orks options).
fun append_faction_declaration_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_declaration_modifiers(board, source, declaration, kind, result)

# Gather source/target-dependent grants into info for this declared weapon:
# modifier lists, reroll flags, hit provenance and cover exceptions. Core then
# classifies rolls/applies caps; this hook neither rolls dice nor spends CP.
# Caller supplies initialized common attack facts and a resolved bearer; this
# augments that attack group rather than clearing/rebuilding the whole record.
fun append_faction_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo info):
    append_orks_attack_effects(board, source, target, weapon, info)

# Add a conditional bearer-only ability using attachment context, unlike the
# unit-wide grant hook. Kill Kommanda supplies Infiltrators/Stealth to its
# attached bearer while the required original component remains active.
fun faction_model_grants_ability(Unit unit, Model model, AbilityKind kind) -> Bool:
    return orks_model_grants_ability(unit, model, kind)

# Return whether the unit currently has Lone Operative: its own ability or
# conditional grants (Dreadherder/datasheet support). Adapter checks each grant's
# attachment/proximity clauses; core applies range/detection/target checks.
fun faction_lone_operative(Board board, Unit unit) -> Bool:
    return orks_lone_operative(board, unit)

# Return the minimum D6 result for this casualty's Fight on Death, or 0 for
# no permission. Chooses applicable datasheet/package/effect threshold; no die
# is rolled. A unit already selected to fight cannot gain another attack
# (One Last Kill/Brute Bosses and cards; supplied Fight on Death definition).
fun faction_fight_death_threshold(Board board, Unit unit, Model model) -> Int:
    return orks_fight_death_threshold(board, unit, model)

# Return the battlefield unit index of a live Grot Shield recipient, or -1
# if none. This is a lookup, not a hit count; the interception action below
# rechecks the shield between wounds (Runt Swarm/Grot Shields).
# Index 0 is valid; test >= 0 rather than treating the result as a Boolean.
fun faction_hit_interceptor(Board board, Unit unit) -> Int:
    return orks_grot_shield(board, unit)

# Before ranged weapon/target declarations, resolve Shokk Attack Gun table
# choices/results and install their bearer grants. Runs inside the selected
# attack; it does not itself declare weapons or gather attack dice.
fun faction_pre_declaration_options(Board board, UnitID source) -> OrksShokkaSelection:
    return orks_shokka_selection(board, source)

# At this shooting activation's end, resolve Rokkit Barrage, Enhanced
# Runt-maw's actually-hit target choice and pending Shokka bearer destruction.
# Uses the activation's hit ledger; common damage/destruction handles deaths.
fun faction_shooting_finished(Board board, UnitID source) -> OrksShootingOptionEnd:
    return orks_shooting_option_end(board, source)

# Offer optional Dreadherder support at Shooting selection: choose a nearby
# Walker and grant turn-long rerolls of hit rolls of 1, consuming a phase use.
# Does not consume the bearer's shooting; also usable via the phase peer menu.
fun faction_shooting_support(Board board, UnitID source) -> OrksDreadherderShooting:
    return orks_dreadherder_shooting(board, source)

# Test that engagement is exclusively with enemy Fortifications. Core uses
# this specific exception for shooting and unshocked escape handling; it does
# not waive restrictions for ordinary engaged enemies (Fortification rules).
fun faction_engagement_exception(Board board, Unit unit) -> Bool:
    return orks_engaged_only_fortifications(board, unit)

# Test partial cover contributed by an intervening Ramshackle model between
# observer and target. Intentional circular-base proxy for model obscuration;
# true adds cover, never blocks physical visibility (Orks Ramshackle rule).
fun faction_intervening_cover(Board board, Model observer, Model target) -> Bool:
    return orks_ramshackle_obscures(board, observer, target)

# Test whether the observer's Wobbled effect gives its targets cover,
# independent of terrain or a particular target. False removes no cover from
# other sources (Mek Gunz/Madcap Artillery).
fun faction_observer_grants_cover(Board board, Model observer) -> Bool:
    return orks_wobbled_observer(board, observer)

# After attack hits and before weapon Hazardous, choose an actually-hit
# enemy and apply Madcap Artillery/Bust Em/Squig Barrage effects. Uses current
# ledger weapon provenance; declaring or missing a target is insufficient.
fun faction_hit_results(Board board, UnitID source) -> OrksHitEffects:
    return orks_resolve_hit_effects(board, source)

# Offer Warpath when selected to fight, before Pile In/Overrun and weapon
# selection. Resolves the shared psychic budget/test and phase grant; this
# does not execute melee attacks (Weirdboy/Kill Rig cards).
fun faction_datasheet_fight_selection(Board board, UnitID source) -> OrksDatasheetFightSelection:
    return orks_datasheet_fight_selection(board, source)

# Resolve optional Rokkit-driven melee selection effects before choosing
# weapons, within the selected Fight. Installs the source's attack grants;
# ordinary weapon declaration and attack resolution remain core.
fun faction_melee_weapon_selection(Board board, UnitID source) -> OrksRokkitSelection:
    return orks_rokkit_selection(board, source)

# Append datasheet-granted instances for this selected profile to result.
# No equipment changes or duplicate selection occur here; core combines the
# result with intrinsic/package grants and preserves distinct sources (p78).
fun append_faction_datasheet_weapon_rules(Board board, UnitID source, Weapon selected, WeaponAbilitySet result):
    append_orks_datasheet_weapon_rules(board, source, selected, result)

# Append datasheet arithmetic for kind on this declaration, using the real
# bearer/weapon context. Mutates only result; common characteristic processing
# owns modifier ordering, rounding and bounds (appendix Modifiers).
fun append_faction_datasheet_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_datasheet_modifiers(board, source, declaration, kind, result)

# After source/target and attack mode are known, resolve applicable paid
# attacker/defender choices before the attacks. Can spend CP/install effects;
# normal targeting/payment/usage checks still govern each selected card.
fun faction_attack_targeted(Board board, UnitID source, UnitID target, Bool melee) -> OrksAttackTargeted:
    return orks_attack_targeted(board, source, target, melee)

# Cancel up to count original rolled hits against target, one at a time.
# Each cancellation inflicts one mortal on the current live Grot Shield unit;
# return intercepted for core subtraction. Generated Sustained Hits are not
# included in count; common damage/FNP/destruction handles shield casualties.
fun intercept_faction_hits(Board board, UnitID target, CombatCounter count) -> OrksHitInterception:
    return intercept_orks_hits(board, target, count)

# Return the absolute InSv target for allocating this attack to model,
# starting from its effective save (above 6 means none). Unit KFF improves it
# to 4+ only for ranged attacks; this is not an additive save modifier.
fun faction_allocation_invulnerable(Unit unit, Model model, AttackSequenceInfo info) -> Int:
    return orks_allocation_invulnerable(unit, model, info)

# Resolve own-unit responses after subject becomes Battle-shocked, using a
# stable identity across battlefield/reserve/passenger banks. Breakin Heads
# can spend CP/inflict damage; resolve the identity again after nested changes
# (Orks morale cards; appendix01.02.04).
fun faction_became_shocked(Board board, EntityIdentity subject) -> OrksBecameShocked:
    return orks_became_shocked(board, subject)

# Battlefield-slot convenience overload of the same shocked-unit response.
# Converts target to stable identity for the shared all-bank implementation;
# does not introduce a separate offboard rule or roll Battle-shock itself.
fun faction_became_shocked(Board board, UnitID target) -> OrksBecameShocked:
    return orks_became_shocked(board, target)

# Offer Mob Mentality before the Command Battle-shock step establishes its
# test/recovery eligibility snapshot. This is the pre-step boundary, not the
# Command-phase start; the child owns its selections/usage (Orks cards).
fun faction_before_battle_shock(Board board) -> OrksMobMentalityStep:
    return orks_mob_mentality_step(board)

# Before removing a retained casualty, offer Flyin Headbutt and resolve its
# payment/target/dice. Outputs suppress_demise, headbutt_recipient and
# crash_mortals; core applies the resulting mortal jobs/removal in order.
# event supplies the real bank/unit; casualty is the caller's retained model.
# Read outputs after completion. headbutt_recipient identifies a mortal-job
# target only when crash_mortals > 0; suppress_demise can be true with no mortals.
fun faction_before_destruction(Board board, Model casualty, PendingDestruction event) -> OrksBeforeDestruction:
    return orks_before_destruction(board, casualty, event)

# Return additional Hazardous uses, not wounds, beyond selected physical
# weapons. Da Button contributes one while active; common Hazardous rolling,
# allocation and destruction resolve it (Dread Mob; core p81).
fun faction_extra_attack_hazards(Board board, Unit unit) -> Int:
    return orks_extra_attack_hazards(board, unit)

# Read a source-owned automatic Battle-shock success permission.
# Does not perform recovery or clear existing shock by itself; core decides
# test/recovery timing using its frozen eligibility (Orks cards; core p30).
fun faction_automatic_shock_success(Board board, Unit unit) -> Bool:
    return orks_automatic_shock_success(board, unit)

# Return the nonnegative penalty subtracted from the Leadership roll total,
# not a change to Ld characteristic. Enhanced Runt-maw contributes its active
# Snotling penalty before core's comparison (Orks enhancement).
fun faction_leadership_roll_penalty(Board board, Unit unit) -> Int:
    return orks_leadership_roll_penalty(board, unit)

# Peer menu offering Dreadherder support beside ordinary Shooting choices.
# started is set on the first accepted input; core completes this child before
# reopening the menu. It does not select/consume ordinary shooting by itself.
# Construction must leave Board unchanged; an unavailable menu simply offers
# no enabled input, allowing the core peer to remain selectable.
fun faction_shooting_phase_choice(Board board) -> OrksShootingPhaseChoice:
    return orks_shooting_phase_choice(board)

# After all declarations, resolve Unpredictable Genius only when ranged
# attacks share one target. Returns effect, the scoped source key core must
# expire after this activation; does not prohibit multi-target declarations.
# effect == 0 means no scoped grant to remove. Read it after completion and
# preserve it until the attack's remove_scoped_source_effect cleanup boundary.
fun faction_declarations_complete(Board board, DeclaredWeapons declarations, UnitID source, Bool melee) -> OrksDeclarationsComplete:
    return orks_declarations_complete(board, declarations, source, melee)

# Peer choice for one pending Mobbed/Impetus charge-end effect, interleaved
# with core Crushing Impact. Mutates the original progress flags and sets
# started on acceptance; crushing_pending is borrowed common-menu context,
# not this adapter's flag to clear (user Rules Sequencing; Orks cards).
# Construction must leave Board/progress unchanged. Accepted resolution or
# decline clears its own pending flag before the child resolves nested effects.
fun faction_charge_choice(Board board, FactionChargeProgress progress, Bool crushing_pending, UnitID source) -> OrksChargeChoice:
    return orks_charge_choice(board, progress, crushing_pending, source)

# Snapshot Mobbed/Impetus eligibility for source after its completed charge.
# Returns pending flags without resolving effects/rolling dice; the common
# ordered menu consumes this snapshot one effect at a time (Orks cards).
fun faction_charge_progress(Board board, UnitID source) -> FactionChargeProgress:
    return orks_charge_progress(board, source)

# Return whether any faction charge-end flag in progress is still pending.
# Does not inspect core Crushing Impact or other charge legality; callers
# combine their own pending work before allowing the sequence to finish.
fun faction_charge_effects_remaining(FactionChargeProgress progress) -> Bool:
    return orks_charge_effects_remaining(progress)

# Read whether Dodge Dis contributes a separately selectable +1 hit term.
# This is neither final modifier arithmetic nor WS/BS improvement; core keeps
# the term individually ignorable and applies hit caps (Squighog Boyz).
fun faction_innate_hit_bonus(Unit unit) -> Bool:
    return orks_innate_hit_bonus(unit)

# At attack selection, snapshot Wrecka objective presence and resolve free
# Ammo Runt/paid attack choices before declarations. melee selects the actual
# mode; accepted choices consume their own tokens/CP and install source grants.
fun faction_attack_selection_options(Board board, UnitID source, Bool melee) -> OrksAttackSelectionOptions:
    return orks_attack_selection_options(board, source, melee)

# Append inherent unit contributions before the remaining faction arithmetic.
# Brutal Impact adds Damage to all attacks after charging. Mutates only result;
# kind filters the requested characteristic and core owns final ordering/caps.
fun append_faction_intrinsic_modifiers(Board board, UnitID source, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_intrinsic_modifiers(board, source, kind, result)

# Augment record's optional tagged-hit counts for the current weapon group,
# currently Squig Launcha provenance. Core already recorded count ordinary
# hits; never add them again to totals or infer actual damage from these tags.
fun record_faction_hit_tags(Board board, AttackResultRecord record, Int count):
    record_orks_hit_tags(board, record, count)

# Resolve eligible after-attack cards in current-player/opponent order,
# including payment and nonattack effects. Returns reaction, a typed request
# for core's flat attack runner; never nests the shared Attack frame. Uses the
# completed activation ledger and restores decision ownership (Orks cards).
# After completion, inspect reaction.available before reading its actor/target
# fields; copy the request before reusing the shared reaction frame.
fun faction_post_attack(Board board, UnitID attacker, Bool melee) -> OrksPostAttack:
    return resolve_orks_post_attack(board, attacker, melee)
