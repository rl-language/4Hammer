# Passive and triggered abilities

The faction-specific army-building action **is the army catalog**. Its action
inputs, preconditions and control flow define the available units, equipment,
detachments and enhancements and construct the selected army. For Orks, this is
[`build_orks_roster`](../src/factions/orks/roster.rl), together with its delegated
selection actions. Do not duplicate that procedure with a catalog object,
listing API or a separate army-description interface.

This specification covers passive and triggered abilities only.

The mechanism separates **passive abilities** from **triggered abilities** so
core can apply the same mechanics for any army. The active calculation/event
hooks are now implemented in the [dispatch layer](../src/factions/README.md).
[The runtime guide](ability-hooks.md) gives their actual modules, signatures,
outputs and limits. The broader record/effect vocabulary below remains design
notation where that guide does not list a runtime implementation; it is not a
claim that every proposed event or all named model metadata has been migrated.

## The two mechanisms

| Mechanism | Army implementation | Core responsibility |
| --- | --- | --- |
| Passive ability | An ordinary function tests the ability's conditions and adds standard effects to the supplied calculation. | Supply the exact context, aggregate effects, apply ordinary arithmetic/permissions and return the effective game result. |
| Triggered ability | An event-specific action handles abilities at that exact boundary, with typed event data and normal action choices. | Call the correct boundary once, retain required activations, order controllers and run shared game procedures. |

A unit/model constructor or existing selection action writes its ability,
equipment and selected-option data as it already does. The army implementation
reads that data in its passive/triggered functions. No extra public process asks
the army to enumerate the rules its constructors just installed.

Named conditions and ability-specific control flow belong in army code.
Core understands modifiers, weapon rules, permissions, effect lifetime, costs,
movement, damage and other common procedures. It must not check a named army
status, private rule number or faction-specific Model field to decide an effect.

## Common references and scope

The mechanism uses typed, serializable values and adequate bounded storage.
No callback pointers, generated rule strings, opaque state or additional rule
interpreter is introduced. Ordinary Rulebook functions/actions remain the code
that implements abilities; generated initialization/destruction remains in use.

| Record | Required fields and meaning |
| --- | --- |
| `AbilityOrigin` | Finite globally qualified ability identity; owning player; actual conferring model, original unit/component or army; optional physical item/copy identity. Equal effects from different origins remain different. |
| `AbilityScope` | Bearer-only, original component, combined unit or army; source-life requirement; whether leading-at-start qualifies; any explicitly permitted retained-source window. Recipient scope and source lifetime are distinct. |
| `SelectedEnhancement` | Selected catalog entry, original recipient identity and bearer/component scope. Existing selection actions write this generic provenance. |
| `EffectOrigin` | Ability origin plus the particular accepted effect identity and term identity. Identifies one contribution for expiry, ignore choices and duplicate detection. |

Persistent references use entity identities, not bank slots. Public inputs may
still use UnitID/ModelID; resolve them to the correct entity when accepted.
An ordinary transfer or revival keeps identity. A replacement has an explicit
old/new component/model map; applying it to the new copy must not retarget the
original unit's effects or use history.

Attached-unit checks distinguish model keywords, the combined unit's keywords
and the original component conferring an ability. A bodyguard upgrade does not
automatically become the surviving Leader's upgrade. Source conferral retained
through the attacking unit's attacks is not equivalent to its bearer being alive.
[Core pp.66–67/88; supplied original-recipient and Fight on Death definitions.]

The concrete origin key is `(ability_id, conferring_entity, physical_copy)`;
`physical_copy` is absent for a non-item ability. Installed effects additionally
have a unique `effect_id`; each bundle term has its own `term_id`. Reusing the
same definition on another model does not merge the two origins. Labels are
presentation metadata, never identity or dispatch keys.

## Passive abilities

### Calculation-specific hooks

Each calculation has its own named function, concrete context and typed output.
There is no public catch-all passive function with a domain enum. Planned hooks
are:

| Hook | Concrete context and output |
| --- | --- |
| `append_model_properties` | Model/component and retained-source facts; model characteristic, keyword, ability and save effects |
| `append_unit_properties` | Combined membership and original components; unit-scoped properties |
| `append_weapon_rules` | Actual bearer, physical copy and selected/borrowed profile; weapon-rule instances |
| `append_weapon_modifiers` | Actual declaration and bearer; weapon characteristic modifiers |
| `append_movement_policy` | Mover, selected kind and movement purpose; distance, traversal and endpoint policy |
| `append_charge_policy` | Charger, targets and captured movement history; charge permissions and distance policy |
| `append_attack_effects` | Attacker, target and declaration; attack modifiers, reroll and cover policies |
| `append_allocation_effects` | Recipient model and incoming attack/damage; save, damage and prevention policies |
| `append_advance_roll_effects` | Advance roll and attempt; modifiers/reroll permissions |
| `append_charge_roll_effects` | Charge roll and attempt; modifiers/reroll permissions |
| `append_battle_shock_roll_effects` | Test subject and attempt; modifiers and permitted success/reroll rules |
| `append_escape_roll_effects` | Escaping unit and hazard batch; additional rolls, modifiers and bypass permissions |
| `append_hazardous_roll_effects` | Actual physical-weapon uses and hazard batch; additional rolls and permitted prevention |
| `append_objective_control_effects` | The queried marker, contributing unit/model and cargo; OC effects |
| `append_stratagem_cost_effects` | Card, payer, source/targets and use context; cost effects |
| `append_action_permissions` | Actor and proposed core action; specific permission/restriction effects |
| `append_targeting_permissions` | Proposed attack/card target and mode; detection, visibility and engagement exceptions |

The names omit a faction because the composition boundary is faction-neutral;
army implementations use their own prefixed names. Reuse existing appenders
where their contract already fits, rather than adding a parallel path. Roll
hooks are separate at distinct rule boundaries; hit/wound/save policies receive
their concrete attack/allocation context, not an unrelated roll-kind switch.

For example, in contract notation:

```text
append_weapon_rules(board, WeaponContext weapon, WeaponAbilitySet rules)
append_charge_roll_effects(board, ChargeRollContext charge, ChargeRollEffects effects)
append_objective_control_effects(board, ObjectiveControlContext objective, ObjectiveControlEffects effects)
```

Composition calls the relevant army functions. There is no hook for a particular
named army rule and no hook asking for an already computed final stat.

1. Core starts from printed/intrinsic data and established common effects.
2. Core supplies the calculation context and its current effect accumulator.
3. The army function checks each applicable passive and appends its effects.
4. Core finishes aggregation, required player choices and mechanical evaluation.

Only `effects` may be mutated. Reading the Board or validating legal actions
must not spend, roll, create sources or change models. No applicable passive
does nothing. Preserve earlier contributions. The same contribution must have
one evaluation path; an installed grant must not also be added again by its
army function. Different origins with identical effects remain independent.

### Contexts core must provide

| Context | Required information | Standard effects the function may add |
| --- | --- | --- |
| Model properties | Actual model, original component, printed/equipped facts, established effects and live/retained-source context | Characteristic modifiers, keyword changes, standard abilities, invulnerable-save grants |
| Unit properties | Actual combined membership, component identities and live/retained conferral | Unit-scoped modifiers and abilities, with bearer/component restrictions preserved |
| Weapon | Actual attacking bearer, physical weapon/copy, selected profile, original equipment owner when borrowed | Weapon-rule instances, numeric rule increments and weapon-characteristic modifiers |
| Movement/setup | Actor, selected move kind, ordinary/reactive/prebattle purpose, relevant carrier/targets and captured selection facts | Distance modifiers, independent move/charge/action permissions, traversal/setup policy |
| Attack | Attacker, bearer, weapon/profile, target, attack step/mode, selected declarations and current facts | Hit/wound/weapon modifiers, reroll/ignore permissions, target/cover policy |
| Allocation | Actual recipient model, incoming attack, damage kind and source/psychic/attack provenance | Save permissions, incoming AP/D modifiers and wound-prevention permissions |
| Roll | Roll kind, roller/subject, identified dice and attempts, current reroll/unmodified/modified stage | Roll modifiers, supported reroll/ignore permissions and permission for explicit replacement choices |
| Objective | The particular objective being scored, player, contributing model/unit, cargo and current control facts | OC contributions and objective-specific permissions |
| Stratagem | Card, payer, source/target, selected mode and usage context | Access restrictions, cost modifiers and distinct targeting permissions |

An argument absent from a context cannot be guessed from a faction-specific
global. In particular, objective effects receive the queried marker, and weapon
effects receive the actual profile and physical owner for Firing Deck.

### Effects have mechanical meaning

| Effect | Explicit data | Core interpretation |
| --- | --- | --- |
| Characteristic modifier | Characteristic, operation, signed amount and affected model/weapon scope | Apply replacement, multiplication, addition, division, subtraction and final rounding/limits |
| Roll modifier | Roll kind/stage, operation, amount, origin and ignore eligibility | Preserve individually selectable terms; rerolls occur first and ordinary caps apply |
| Keyword/ability grant or removal | Keyword or standard ability, recipient scope and explicit exception semantics | Apply at the proper model/unit scope without spreading a bearer-only property |
| Invulnerable-save grant | Save target and any attack/recipient condition | Establish a usable base permission before arithmetic; retain a better existing save |
| Weapon-rule grant | Kind, parameter, condition, physical/profile scope and origin | Include the actual instance in weapon selection; choose duplicates under core rules |
| Permission/restriction | The particular mechanical gate, granted/forbidden operation and scope | Change that gate only; preserve every independent requirement |
| Geometry/setup policy | Allowed traversal, distance/setup constraint or explicit mode permission | Change that part of the common procedure; retain its other endpoint/coherency checks |
| Resource/cost modifier | Resource/card context, operation and amount | Use common cost limits and payment; do not spend in the passive function |

This vocabulary contains common mechanics, not entries such as a named army's
“hit bonus” or a named vehicle's “special destruction.” A new mechanical effect
needs a documented common meaning, not a new army-specific branch in core.

The effect variants must have explicit payloads, not overloaded generic
`kind/amount` fields whose meaning changes by army:

```text
ModifyCharacteristic(characteristic, operation, amount, recipient, weapon_scope)
ModifyRoll(roll_kind, operation, amount, ignore_policy)
ChangeKeyword(keyword, add_or_remove, recipient_scope)
GrantAbility(standard_ability, parameters, recipient_scope)
GrantInvulnerableSave(threshold, attack_condition, recipient_scope)
GrantWeaponRule(kind, parameter, target_condition, physical_or_profile_scope)
ImproveWeaponRule(kind, increment, physical_or_profile_scope)
Permit(action_kind, waived_restriction, recipient_scope)
Prohibit(action_kind, recipient_scope)
AdjustMovement(traversal_or_setup_policy)
ModifyCost(resource_kind, operation, amount)
```

Every variant carries `EffectOrigin`. `action_kind` identifies the operation
and mode (for example Charge or a particular shooting mode), while
`waived_restriction` identifies its specific Advance, Fall Back, engagement,
disembarkation or other supported gate. Improving a numeric weapon rule retains
the original instance's conditions and the increment's separate provenance;
it is not necessarily a competing instance of that ability.

Roll policies also have typed forms:

```text
PermitReroll(roll_kind, eligible_dice, eligible_results, scope)
PermitIgnoringModifiers(affected_roll_or_characteristic, eligible_terms, scope)
GrantAutomaticSuccess(roll_kind, condition, scope)
AddRolls(roll_kind, count, batch_policy)
```

These affect the common roll plan; applying a passive never rolls the dice.
Additional escape-hazard rolls are a count, not automatic wounds. Prevention
uses the corresponding standard ability with its threshold and damage-kind
conditions. An optional replacement is executed by a triggered action; the
passive may permit that choice but cannot silently make it.

Permission to charge after Advance waives only the Advance restriction.
A separate no-charge effect can still prohibit charging. Engaged-target
shooting permission and escape-hazard bypass are separate effects. An ability
cannot return a blanket `allowed = true` that bypasses all other checks.
Conflicting exceptions follow their supplied rule semantics; there is no
invented universal precedence rule.

Movement policy carries an explicit allowance, either `effective M + addition`
or an absolute distance, plus traversal/vertical costs, permitted endpoint
exceptions and post-move restrictions. Core executes this plan; it must not
recognize a faction's special-move enum to invent its distance or consequences.
Any exception is limited to its stated part of the plan; remaining boundary,
overlap, coherency and engagement checks still run.

Contexts label which facts are frozen and which are current. Blast uses target
selection's model count; an ordinary later range check uses the required current
position. Effective-property dependencies have an explicit order. A passive
must not recursively ask for the same effective property it is defining.
[Core pp.16–19/67/78–85; supplied Modifiers, Ignore Modifiers and reroll rules.]

## Triggered abilities

### Event and pending activation

| Record | Required information |
| --- | --- |
| Event-specific records | Each boundary has its own type, such as `MoveFinishedEvent` or `ModelDestroyedEvent`. A shared header holds window identity, cause/parent operation and controller roles; each concrete payload defines its subjects, snapshots and before/after stage. No arbitrary event-kind/payload bag. |
| `PendingAbility` | Origin; triggering event; controller and payer policy; compulsory/optional status; established trigger-time facts; conditions still required at use; usage scope and cost; pending/accepted/declined/completed state. |

A window can permit a player's voluntary ability even without an earlier
committed event. For example, “in your Movement phase” is a legal player-action
window, while “after this unit ends a move” refers to that actual completed move.
Remaining stationary does not invent a move-start/end event.

### Event-specific action hooks

Core calls a separate action hook at each boundary. This is the public extension
surface, not a universal queue/validate/execute dispatcher. The event inventory follows; each name has its own typed event and action frame.

| Hooks | Boundary and permitted work |
| --- | --- |
| `on_battle_start`, `on_battle_end` | Before the first round / after required final-turn work; battle-boundary effects |
| `on_round_start`, `on_round_end` | The particular round boundary; resolve matching activations |
| `on_turn_start`, `on_turn_end` | The named player's turn boundary; preserve controller order and core end-turn gates |
| `on_command_phase_start`, `on_command_phase_end` | Actual Command-phase boundaries; not the Battle-shock-step boundary |
| `on_movement_phase_start`, `on_movement_phase_end` | Actual Movement-phase boundaries |
| `on_shooting_phase_start`, `on_shooting_phase_end` | Actual Shooting-phase boundaries |
| `on_charge_phase_start`, `on_charge_phase_end` | Actual Charge-phase boundaries |
| `on_fight_phase_start`, `on_fight_phase_end` | Actual Fight-phase boundaries; retained death work finishes before removal |
| `during_movement_phase`, `during_shooting_phase`, `during_charge_phase`, `during_fight_phase` | Separate ordinary peer actions for voluntary in-phase abilities; accepting one does not imply starting/ending the phase |
| `on_battle_shock_step_start` | After core Command CP work, before test/recovery eligibility is frozen |
| `on_battle_shock_test_resolved` | Final test result and attempt; result-triggered work |
| `on_unit_became_battle_shocked` | Actual state transition and stable subject identity; not merely a failed-test notification |
| `on_unit_selected_to_move` | Selected mover, before mode-dependent choices and placement |
| `on_move_kind_selected` | Committed kind and captured selection facts; mode-specific effects, no fabricated completed move |
| `before_advance_roll`, `after_advance_roll` | Before the roll / after final rerolls and evaluation; changes only at their permitted stage |
| `on_move_finished` | Committed mover, start/end facts and kind; same hook handles both players' matching reactions |
| `on_reserve_arrival` | Successfully placed unit and actual arrival location |
| `before_disembark`, `on_disembark_finished`, `on_embark_finished` | Separate transport boundaries with stable passenger/carrier identities and actual transfer facts |
| `on_unit_selected_to_shoot` | Selection before weapon/target declaration; all relevant abilities share this window |
| `before_weapon_declarations` | After selection effects, immediately before weapon/profile/target choices; do not collapse this into an earlier selection event if intervening state changes matter |
| `on_unit_selected_to_fight` | Selection before Pile In and melee declarations |
| `on_targets_declared` | Completed declarations with physical-weapon provenance and selection snapshots |
| `on_attack_target_selected` | Particular declared target/group before its attack rolls; distinguish group selection from the earlier declaration event |
| `on_hit_rolls_resolved` | Identified surviving original rolled hits, before critical-hit conversion; generated hits remain distinct |
| `on_wound_rolls_resolved` | Identified final wound-roll batch, before allocation |
| `before_wounds_lost` | Actual recipient and pending wound loss before committing it; explicit prevention/replacement only |
| `on_attacks_finished` | Operation-wide hit/damage ledger after all declared groups; ordinary Hazardous processing remains core-owned |
| `on_charge_declared`, `before_charge_roll`, `after_charge_roll` | Separate declaration and roll stages with the actual charger/targets/attempt |
| `on_charge_finished` | Completed charge and actual endpoints; simultaneous charge effects share one ordered window |
| `on_model_destroyed` | Retained casualty, bank, cause and pending demise; standard damage jobs and explicit demise replacement results |
| `on_unit_destroyed` | Actual last-model destruction, once; retained unit/component facts and source scopes |

Prebattle redeployment and formation actions remain separate existing actions.
Their mechanics must not be squeezed into phase-start hooks. Likewise, retain
separate callbacks for any further printed trigger whose timing is materially
different; do not dispatch it through an approximate existing event.

Illustrative contract notation:

```text
on_unit_selected_to_shoot(board, ShootSelectionEvent event, ShootSelectionProgress progress)
    -> ShootSelectionAbilities action
on_move_finished(board, MoveFinishedEvent event, MoveFinishedProgress progress)
    -> MoveFinishedAbilities action
on_model_destroyed(board, ModelDestroyedEvent event, DestructionProgress progress)
    -> ModelDestroyedAbilities action
```

These are normal Rulebook actions, composed with core's choices at that event.
Each event's progress/result record contains only that boundary's state. There
is no generic `execute_triggered_ability` hook or `AbilityEvent` switch repeated
inside every army. Eligibility is expressed in the appropriate action guards
and event-specific helpers.

### Changes to existing hooks

| Current hooks | Planned boundary |
| --- | --- |
| `faction_melee_sustained_rule_applies`, intrinsic/package/datasheet weapon appenders | `append_weapon_rules`; actual parameterized instances replace the Boolean special case |
| `faction_innate_hit_bonus`, attack modifier appenders | `append_attack_effects`; retain individually ignorable modifiers |
| `faction_charge_reroll`, `faction_charge_aura_bonus`, `faction_unit_charge_bonus` | `append_charge_roll_effects`; actual modifier/reroll terms |
| `faction_advance_charge_status`, `faction_move_charge_permission` | Movement/charge policy hooks with explicit selection-time capture |
| `faction_engagement_exception` | Independent targeting and escape-roll permissions |
| `faction_passenger_objective_control` | `append_objective_control_effects`, receiving the scored marker |
| `faction_movement_abilities`, `faction_move_selection` | `on_unit_selected_to_move`; preserve distinct later mode-selection boundaries |
| `faction_after_move` and movement-end source reactions | `on_move_finished`; both players' effects share the actual event |
| `faction_shooting_support`, `faction_pre_declaration_options` | `on_unit_selected_to_shoot` and `before_weapon_declarations`, respectively |
| `faction_became_shocked`, `faction_before_battle_shock` | `on_unit_became_battle_shocked` and `on_battle_shock_step_start`, respectively |
| `faction_timing_choice` | Separate named round/turn/phase boundary actions; shared sequencing underneath |
| `faction_before_destruction` and destruction-presence queries | Typed model/unit destruction actions and common retention handling; no named-faction death-presence flags |

Keep the existing contract when it is already correct. Consolidation is based
on the same calculation or event, never merely on both hooks being abilities.
Source installation/removal/expiry remains common lifecycle machinery, not
another event-dispatch API.

When a model is destroyed, core invokes the destruction boundary before
removal and retains it for required processing. Actual last-model loss invokes
the unit-destruction boundary once. The same bank-aware hooks serve battlefield,
reserve and embarked units, subject to the actual rule's permissions.

Each boundary specifies when it may change a pending result. An after-event
cannot rewrite an already completed move or resolved attack. Original rolled
hits, generated hits, actual wounds lost and destruction are distinct facts.
Rerolled attempts are identifiable without reopening spent rerolls.
[Core pp.16–24/28–42/54–58/64–67/87; supplied appendix definitions.]

### Shared obligations inside each event hook

The following are common implementation rules, not additional catch-all public
hooks. Reuse the existing queue/identity/usage machinery where a window needs
pending activations and simultaneous ordering; a simple event action does not
need a new queue merely to fit an abstraction.

**Queue.** Core opens the particular event window once. Where queuing is needed,
event-specific helpers append matching activations without mutating Board,
paying or rolling. Preserve earlier entries. An origin/event/activation identity
prevents duplicate queuing; separately permitted instances stay separate.
Record trigger-time qualification now. Core owns the queue and its lifetime.

**Validate.** Before offering or accepting an activation, revalidate its pending
identity, unresolved state, required current source/use conditions and legal
completion path. Preserve facts already established at the trigger. Losing a
source cancels an activation only where its rule requires that source to remain.
An invalid target follows the actual replacement/no-target rule, not a blanket
discard of every already-triggered effect. This predicate changes nothing.

**Execute.** After acceptance, run the ability's normal action function. It may
choose targets, ask for dice, branch and delegate common procedures. A rule can
select targets before or after its roll as stated. Commit required CP/resources
and usage at its specified acceptance point using shared services, before the
corresponding effect; a reroll never pays again. A free use still consumes any
specified use limit. Invalid acceptance is atomic. Declining before acceptance
spends nothing; later cancellation does not imply a refund.

On completion, mark that activation completed or declined exactly once. Preserve
other pending entries. Required decisions and effects finish before core moves
past the window; an optional action must have a legal decline path. A compulsory
ability with no valid target follows its rule without leaving a stalled window.

The lifecycle is `pending -> accepted -> completed`, or `pending -> declined`.
A rule-specific cancellation after acceptance is a completed activation with
that outcome and its actual cost/use consequences. An invalidated entry is
retired only under its specified eligibility policy. A stale event identity or
source-slot generation cannot activate a different source occupying that slot.

Queue construction and event snapshots are not repeated merely because the
player inspects valid actions. Separate legitimate activations get separate
identities even if their ability and target are equal. A roll/retry inside an
activation retains that activation's identity and committed-use record.

### Sequencing and action ownership

Core gives the current player their simultaneous effects in their chosen order,
then the opponent theirs, under the supplied sequencing ruling. Pending entries
record the controller explicitly: source owner, turn owner, payer, affected
unit and chance owner are not interchangeable. Core owns compulsory finish
gates and combines common and army effects in the same window.

Within the selected ability, normal action/subaction functions own the sequence
of choices. There is no additional public availability-list object, generic
ability-step interpreter or army-state protocol. Where peer menus remain in
use, construction must not change Board before input; the chosen child finishes
before another peer is offered.

Use common movement, placement, dice, attack, damage, healing, return and
replacement procedures. Do not duplicate them in an army. Do not re-enter an
already active shared frame: death effects return ordinary damage jobs; reaction
attacks use typed requests and the flat runner when appropriate. A genuine
mid-operation interruption must complete before its parent continues, using
core-owned retained progress. Deferring it until phase end is not equivalent.

Results that core must consume have mechanically named types. Hit cancellation
identifies the unresolved rolled-result batch and count, preserving generated
hits separately; its window precedes conversion of surviving critical hits into
automatic wounds. A destruction result can suppress/replace ordinary demise
and append standard damage jobs, rather than returning one named ability's
target and mortal count. Multiple attack-scoped effect identities are cleaned
up together at the actual attack boundary. Normal actions keep their own
choice/roll sequence; these result records do not encode that sequence.

## Lasting effects and use records

An accepted trigger may install an `EffectBundle`: mechanically typed grants,
recipient/scope, origin, explicit expiry and whether continued source activity
is required. Its grants enter the same passive-effect evaluation as continuous
abilities. A continuous aura depends on current source/range conditions;
an accepted “until next turn” effect does not become an aura by accident.

```text
EffectBundle:
    origin + effect_identity
    recipient_identity + recipient_scope
    terms: typed passive effects
    lifetime:
        while_source_active
        or until_boundary(kind, phase_if_needed, reference_player, occurrence)
        or until_operation_ends(operation_identity)
        or battle
    continued_source_requirement
```

A boundary deadline is fixed when the effect is accepted. It identifies the
actual start/end, phase and player occurrence; “next own Movement” and “end of
this phase” are not interchangeable. An operation lifetime can cover several
declared targets/groups. Expire it after that operation's required resolution,
not merely after the first group or the whole phase. Multiple bundle identities
can share the same deadline without sharing removal ownership.

Core owns exact-key installation/removal, expiry boundaries and shared usage
records keyed by the required army/unit/model/item scope. Equal effects from
different origins expire independently. Bank transfers preserve identities,
durations and spending; offboard own-unit effects do not grant external range
or visibility. Returned members inherit eligible current unit grants without
duplicates. Archived casualties cannot revive an expired grant.
[Core pp.66–67/88; appendix01.02.02–04.]

There is no separate Army state API. Use records, budgets, selected-option
provenance and ability/action progress use the existing shared typed state.
Extra state required by an actual ability is explicit and documented at that
ability's implementation, without named fields interpreted by core Model code.

## Mapping existing cases to these mechanisms

| Existing case | Passive/triggered implementation | What disappears from core |
| --- | --- | --- |
| A detachment grants melee Sustained Hits 1 | Passive weapon function appends an ordinary parameterized weapon-rule instance with its origin. | A special Boolean hook that causes core to manufacture this particular grant |
| An army activation grants a save, ranged Assault and charging after Advance | Triggered action uses its ordinary choice/counter, then installs one source-owned bundle of three standard grants. | Model flags/named status checks deciding those three benefits |
| A nearby ally grants +1 to charge rolls | Passive movement/roll function checks actual source range and appends one ordinary charge modifier. | A special aura-bonus channel for a named unit |
| Models intercept rolled hits | Triggered action runs at the pre-conversion hit boundary, cancels identified unresolved rolled hits and applies required damage through common procedures. | A named shielding-unit branch controlling Lethal Hits order |
| Passengers contribute OC only at a particular home marker | Passive objective function receives the scored marker and evaluates this carrier/cargo contribution for that marker only. | Guessing the queried objective from a scan for any qualifying marker |

Named abilities remain documented with their source citations in army code.
The passive/trigger contracts above describe the reusable mechanism, not the
eligibility of any particular faction's datasheet.

## Implementation work and validation

1. Define common passive contexts/effects and precise event/pending records,
   reusing existing modifier, source/effect, dice and damage-job primitives.
2. Wire passive evaluation into core calculations and replace the narrow
   fixed-bonus/permission hooks; pass the actual objective to cargo OC.
3. Implement separate typed action hooks at the actual event boundaries,
   sharing queue/usage/ordering helpers where needed and keeping common and
   army effects in the same windows. Do not add a universal ability dispatcher.
4. Migrate existing named model/component data to generic abilities, equipment,
   option provenance and common grants; remove superseded hooks and extract
   legacy faction behavior from core.
5. Validate with native regressions and an independent test-only implementation,
   broadened boundary checks, matching bindings/layouts and sanitized replays/
   fuzzing. Preserve all-bank behavior, source lifetime and shared-frame safety.

Required regression cases include pure repeated passive/queue validation,
cross-army targets, compulsory/optional sequencing, once-only cost/use,
overlapping expiry, offboard persistence, retained component abilities,
revival versus replacement, selection snapshots/retargeting, rolled versus
generated hits, two-marker cargo OC and genuine interruption order.

The [roadmap](../ROADMAP.md) distinguishes implemented active hooks from
remaining metadata, identity and legacy-faction work. Do not add empty hook
stubs for hypothetical rules: introduce a concrete event when a supplied rule
and core call site need it. Adequate bounds are permitted; valid-action discovery
and rendering remain outside this refactor.
