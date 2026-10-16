# Ability hooks in the running engine

The faction-specific army-building action is the catalog. This boundary starts
with the army/model/equipment data that its actions and constructors installed.
It defines ordinary passive calculations and concrete triggered-action windows.
There is no universal ability dispatcher or additional army-description API.

## Modules and ownership

| Module | Contract and implementation responsibility |
| --- | --- |
| [dispatch_properties.rl](../src/factions/dispatch_properties.rl) | Model-local characteristic arithmetic, base-save permission, keywords and ability/component conferral |
| [dispatch_combat.rl](../src/factions/dispatch_combat.rl) | Weapon/attack/allocation calculations and concrete shooting, fighting, rolled-hit, shock and destruction events |
| [dispatch_movement.rl](../src/factions/dispatch_movement.rl) | Movement/charge policy, Advance/charge/escape rolls, selection/completion/arrival/disembark events and marker-specific cargo OC |
| [dispatch_timing.rl](../src/factions/dispatch_timing.rl) | Separate round, turn, phase and Command-abilities-step actions and mandatory/optional pending predicates |
| [dispatch_sources.rl](../src/factions/dispatch_sources.rl) | Register actual sources and validate remaining adapter-owned state; standard effect lifecycle is core |
| [dispatch_permissions.rl](../src/factions/dispatch_permissions.rl) | Independent action, targeting, detection and card-access legality checks |
| [ability_hook_types.rl](../src/ability_hook_types.rl) | Bounded calculation outputs without Board, action or concrete-faction imports |
| [Orks modules](../src/factions/orks/README.md) | Actual named ability conditions, target choices, rolls, costs and effects |
| [legacy/combat.rl](../src/factions/legacy/combat.rl) | Original-roster model-destruction compatibility abilities; this does not certify current-edition datasheets |

Core calls the particular hook where its calculation/event actually occurs.
The composition function forwards to installed adapters. Core interprets common
mechanics and output fields, never an army's rule-code ranges or named status.
The Orks implementation may organize private helpers by datasheet/package;
those implementation layers are not separate interfaces core must understand.

## Passive calculations

These are actual runtime signatures; parameters after `board` are concrete
contexts, not an event-kind enum or a dictionary. An appender preserves earlier
entries and changes only its supplied output. Godot legal-action enumeration
may repeat pure calculations without spending, rolling or registering anything.

```text
append_model_modifiers(Model, ModifiedCharacteristic, RuleModifiers)
append_model_save_permissions(Model, InvulnerableSavePermission)
append_weapon_rules(Board, UnitID, bearer, Weapon, WeaponCode, WeaponAbilitySet)
append_weapon_modifiers(Board, UnitID, DeclaredWeapon, ModifiedCharacteristic, RuleModifiers)
append_unit_hit_modifiers(Unit, RuleModifiers)
append_attack_effects(Board, UnitID, UnitID, DeclaredWeapon, AttackSequenceInfo)
append_allocation_effects(Unit, Model, AttackSequenceInfo, InvulnerableSavePermission)
append_charge_roll_effects(Board, Unit, ChargeRollEffects)
append_advance_roll_effects(Board, Unit, AdvanceRollEffects)
append_battle_shock_roll_effects(Board, Unit, BattleShockRollEffects)
append_escape_roll_effects(Board, Unit, EscapeRollEffects)
append_hazardous_roll_effects(Board, Unit, HazardousRollEffects)
append_selected_move_permissions(Board, Unit, MovementKind, SelectedMovePermissions)
append_objective_control_effects(Board, Objective, Model, Bool, ObjectiveControlEffects)
append_hit_resolution_policy(Board, Unit, HitResolutionPolicy)
```

The unit-only charge overload contributes only local terms; it cannot measure an
aura. The Board-aware overload includes live external sources. Core applies
modifier order/rounding/caps after rerolls. It retains each hit term for optional
ignoring; a unit ability supplies its actual operation and amount, not a Boolean
whose hidden meaning is a fixed bonus. Selected-move permissions are captured
at the relevant selection boundary and cannot be rewritten by later expiry.

`InvulnerableSavePermission.target` is seeded from the printed/common save.
Contributors may improve that base permission. Characteristic modifiers follow;
permission is not replacement arithmetic. Allocation-specific permission sees
the actual incoming attack and recipient, so a ranged-only save stays scoped.

`EscapeRollEffects` separates ordinary/additional batches, their modifiers and
hazard bypass. It grants no shooting exception. `HazardousRollEffects` counts
extra physical uses, never automatic wounds. `HitResolutionPolicy` determines
whether rolled-hit processing must precede critical-hit conversion; generated
hits remain a distinct core result. `ObjectiveControlEffects` adds cargo OC for
the actual queried marker. Overlapping another home marker cannot authorize OC
at an unassigned or enemy marker.

## Triggered actions and their boundaries

Action-returning composition functions construct the actual typed child frame.
They borrow the original contexts; they do not allocate another Board or add a
generic action interpreter. Read results after completion and before frame reuse.

| Hook | Core call boundary |
| --- | --- |
| `on_unit_selected_to_move` | Movement selection, before subsequent kind choices |
| `before_move_kind_selection`, `before_charge_declaration` | Distinct ordinary-movement and charge selection windows |
| `on_move_kind_selected` | The chosen mode before its roll/hazard/placement work |
| `before_advance_roll`, `after_advance_roll` | Before the roll / after final rerolls, before final distance evaluation |
| `before_fall_back` | Selected retreat before escape-hazard policy is reevaluated |
| `on_move_permissions_selected` | Commit selection-specific grants/history; does not invent move completion |
| `on_move_committed` | Common movement record has committed the actual kind |
| `on_move_attempt_finished` | Clear selection-only state even on a cancelled/failed attempt |
| `on_move_finished` | Completed ordinary Movement activation; the installed post-activation reactions use this boundary |
| `on_reserve_arrival` | Actual newly placed unit/location |
| `before_disembark` | Passenger/carrier choices before placement or decline |
| `during_movement_phase`, `during_shooting_phase` | Voluntary phase peers, independent of ordinary unit activations |
| `on_unit_selected_to_shoot` | Support selection before core marks the unit as having shot |
| `on_unit_selected_to_fight` | Before Pile In/Overrun |
| `before_fight_weapon_selection` | Further selected-to-fight choices before the melee movement/declarations |
| `on_shooting_attack_start`, `on_fight_attack_start` | Actual attack activation before source events/declarations; melee follows Pile In |
| `before_weapon_declarations` | Shooting selection effects have finished; profiles/targets are not declared yet |
| `on_targets_declared` | All declarations exist, before the first resolved group |
| `on_attack_target_selected` | One selected declared target, before refreshed group calculations/rolls |
| `on_hit_rolls_resolved` | Identified original rolled-hit batch, excluding generated hits |
| `on_successful_attacks_finished`, `on_shooting_attacks_finished` | Own Shooting completion effects, before selected-weapon Hazardous checks |
| `on_charge_finished` | One atomic pending charge-end choice, interleaved with common effects |
| `after_charge_effects` | After the ordered charge-end menu, before restoring caller roles |
| `on_battle_shock_step_start` | After Command CP, before test/recovery eligibility freezes |
| `on_unit_became_battle_shocked` | Actual transition, using a stable subject identity across banks |
| `on_unit_destroyed` | Actual last-model destruction, retained before removal; may return standard jobs/demise replacement |
| `on_model_destroyed` | Retained model/killer compatibility reactions; shared source triggers separately cover all permitted banks |

Actual signatures and detailed preconditions are above the functions in the
linked dispatch modules. Existing argument records are reused where sufficient:
`DeclaredWeapon`, `DeclaredWeapons`, `PendingDestruction`, stable identities and
resolved carrier locations already carry the needed facts. No new empty event
wrapper is required simply to give each hook a different type name.

The movement kernel separately emits common `move_start`/`move_end` source
events, including for granted moves. The present `on_move_finished` action is
called by ordinary Movement activation post-processing, not recursively inside
every `granted_move`. An army must not assume broader delivery from that hook.
A new ability requiring further completion reactions needs an explicit flat
continuation at the actual boundary, with regression coverage; calling the
shared Move/GrantedMove frame recursively is not a supported shortcut.

Timing has separate `on_round_start/end`, `on_turn_start/end`,
`on_command_phase_start/end`, `on_command_abilities_step`, and start/end hooks
for Movement, Shooting, Charge and Fight. Each takes the original Board,
core/faction progress, pending sources and controller. Each corresponding
`*_abilities_pending` predicate applies to that same fixed boundary. The shared
core timing controller routes its finite window to these explicit contracts;
an army does not receive an arbitrary event payload to decode.

Phase-start hooks run before the phase body, and phase-end hooks before core's
boundary objective/mission processing. Command start is distinct from its CP
step. `on_battle_shock_step_start` runs after that CP step but before recovery
eligibility is frozen; `on_command_abilities_step` runs after Battle-shock.
The hook cannot advance to another phase or perform those common steps itself.

The user-supplied sequencing remains current player's effects in their chosen
order, then the opponent's. A chosen action finishes atomically. Peer
constructors change no shared state before acceptance; `started` is set on the
first accepted input. Required abilities block finishing. Targets, costs, usage,
rerolls and cancellation retain their actual rule-specific order, with shared
payment/use services preventing duplicate expenditure.

## Results, source ownership and lifetime

`on_targets_declared` returns `ScopedEffectKeys`: multiple independent effects
can share the enclosing operation's lifetime. Core removes each exact key after
all declared groups, without deleting unrelated sources. Destruction abilities
return `DestructionAbilityEffects`: optional demise suppression and an ordered
list of standard `DamageJob` values. Core inserts those jobs above removal on
its work stack; the ability cannot recursively enter the active damage frame.

Riled-up is now an adapter-interpreted `RuleEffectKind` carried by ordinary
`RuleEffectGrant` entries. Core stores/removes/validates keys and extends grants
to eligible returned members without interpreting that named effect. There is
no separate RiledUpGrant union case, model status-key vector or faction-specific
install/remove/presence/handle-validation callback. Equal grants from different
origins expire independently across battlefield, reserve, embarked and archive
storage. Existing source machinery retains its explicit lifetime policies.

## Scope and remaining work

This migration implements the active boundaries and generalizes their narrow
outputs. It does not claim every proposed event in the broader
[design](army-api.md) already has an active consumer. New printed rules may need
additional concrete boundaries; implement them at the exact stage rather than
reusing an approximate window or adding unused stubs.

Seven named model fields, captured component metadata, globally qualified
source/use identities and remaining legacy behavior still need their separately
tracked extraction. The Orks source-boundary audit does not certify every army.
No faction-neutral constructor catalog, rendering integration, coordinate
migration, custom init/drop or valid-action discovery optimization is included.
[ROADMAP.md](../ROADMAP.md) owns completed validation and these follow-ups.
