# Game state and property reference

Read the [engine guide](engine-guide.md) first for scope and the tabletop mental
model. This reference explains the properties you encounter when inspecting the
native game from Godot. Code names, including historical spellings such as
`battle_socked`, `starting_strenght` and `strenght`, are written exactly as they
appear in the bindings.

## Contents

- [Conventions and bounds](#reading-the-tables)
- [Game](#game), [selectors/identity](#selectors-and-identity), [Board](#board)
- [Army configuration](#armyconfiguration), [Unit](#unit), [Model](#model),
  [attachment components](#attachmentcomponent)
- [Positions](#boardposition), [geometry](#modelgeometry), [computed queries](#useful-computed-queries)
- [Timing](#timingstate), [unit history](#unithistory), [model history](#modelhistory),
  [mission actions](#unitactionprogress), [movement paths](#modelpath)
- [Declarations](#declaredweapon), [attack context](#attacksequenceinfo),
  [allocation](#allocationgroup), [damage](#damagejob), [pending death](#pendingdestruction)
- [Characteristic modifiers](#characteristicmodifier), [incoming modifiers](#incomingattackmodifier),
  [ignore permissions](#attackmodifierpermission), [resource budget](#roundresourcebudget)
- [Ability sources](#sourceinstance), [events](#sourceevent), [pending events](#pendingsourceevent),
  [use records](#sourceuserecord), [lasting effects](#sourceeffect)
- [Printed data](#printed-profiles-weapons-and-stat), [payload companions](#modifier-and-source-payload-companions),
  [shared frames](#shared-procedure-frames), [other nested state](#other-nested-state-encountered-in-the-tables)
- [Godot access](#finding-a-property-in-godot)

## Reading the tables

Each heading identifies the owning type, its source declaration and its main
writers/readers. Every table row is a **stored property** unless marked as a
computed query. A row describes its game meaning and the event that changes it.
An exposed field is not permission to change it directly during play: use the
current legal action so that histories, use limits, effects and notifications
advance together.

Defaults follow generated initialization: Bool is false; bounded integers start
at their lower bound; enums start at their first alternative; vectors are empty;
arrays initialize each element. Thus ordinary identity/stamp fields start at 0,
`StateSchema` starts at the current schema, and `transport_space` starts at 1.
A zero/default `Model` or `Board` is not automatically a valid army or mission.
Factories, identity assignment and the relevant setup procedure establish those
invariants. For enum-valued fields, check the named enum rather than assuming
that ordinal zero means 'none'.

`CheckedVector<T,N>` stores at most N entries and asserts on unsupported growth;
N is an engine capacity, not a tabletop roster limit. `T[N]` is a fixed array.
`Hidden<T>` still owns real state used by rules/saves; it excludes the value from
the normal ML observation, not from the opponent through a fog-of-war system.

### Numbers, units and sentinels

| Type or notation | Values and interpretation |
| --- | --- |
| `LinearlyDistributedInt<a,b>`, `BInt<a,b>` | Half-open integer range: a through b−1. Both are bounded; their ML encodings differ |
| `UnitID`, `ModelID` | Indices 0–31; only legal if that entry exists in the action's actual collection. Zero is a valid index |
| `EntityIdentity`, `SourceEffectKey` | Zero is unassigned; positive values identify an entity/effect. They are not vector indices |
| `FixedStat`, `Toughness`, `StatModifier` | 0–256 stored integer; a particular characteristic may impose tighter rules |
| `Wounds`, `CombatCounter` | 0–4096; wound loss/attack counts, not printed maxima imposed by the rules |
| `StartingStrength` | 0–32; starting model count, including supported attached components |
| `CommandPoints`, `VictoryPoints` | 0–256 CP; 0–200 VP. Modified costs and awards still require rule checks |
| `PhaseSerial`, `TurnSerial` | 0–63 and 0–15 engine sequence numbers, not phase/round enum values |
| `PhaseStamp`, `TurnStamp` | 0–64 and 0–16; histories commonly store serial+1 so zero can mean 'never' |
| Source effect/use stamps | Store the raw phase/turn/round serial. Unlike history stamps, zero can describe the first interval |
| `RoundResourceBudget.round_stamp` | Round index+1. Its own sentinel convention differs from source-use records |
| `MovementOverride` | 0 means no override; positive N encodes a distance/characteristic of N−1 inches |
| `Dice`, `Stat` | `Dice` is an integer 1–6; `Stat` is a fixed value, a die or a compound dice expression |
| Player Bool/array indices | false maps to player index 0; true maps to index 1. Historical `owned_by_player1` uses this convention |
| `UnitVector`, `ModelVector`, `WeaponsVector` | Up to 32 units per bank, 32 current models per unit, 13 equipped profile slots per model |
| `Abilities`, `Keywords`, `WeaponAbilitySet` | Up to 16 ability kinds, 32 keywords, 32 selected weapon rules respectively |
| `RuleModifiers`, `CharacteristicModifiers` | Up to 16 arithmetic operations/characteristic records in each collection |
| `IncomingAttackModifiers`, `AttackModifierPermissions` | Up to eight recipient reductions/ignore-permission records respectively |
| `SourceInstances`, `SourceUseRecords`, `PendingSourceEvents`, `SourceEffects` | Up to 512 entries in each corresponding collection |
| `DatasheetCode`, `WeaponNameCode`, `WeaponProfileCode` | Codes 0–67, 0–139, 0–176; zero is unknown/unrestricted where the owning field specifies it |

For exact aliases and capacities see [state_types.rl](../src/state_types.rl),
[units.rl](../src/units.rl) and [geometry.rl](../src/geometry.rl). Do not interpret
zero as 'unset' for every bounded field: source indices, positions and player
indices legitimately use zero.

The nonnegative `StatModifier` alias is used for selected allowances/increments;
it is not the signed arithmetic record. Use `RuleModifier`'s operation/magnitude/
sign representation for an actual negative modifier.

## Game

Source: [full_game.rl](../src/full_game.rl). Owner: `GlobalRules.state` in Godot.
Created by `library.play()`; advanced through generated Game actions. Saving
only its Board would lose which choices have already been made.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `board` | `Board` | Battle state plus shared child-procedure storage; survives every input |
| `battle` | `Battle` | Root battle continuation, entered after both roster selections; inspect only in its active context |
| `resume_index` | generated `Int` | Procedure progress, not a tabletop turn number. Treat as opaque; use `is_done` and `can_*` |

Generated action frames also have an opaque resume index. A wrapper's `.make()`
constructs storage; the matching procedure factory starts that procedure with
its contexts and arguments. For the complete application, start with `play()`.

## Selectors and identity

| Type/property | Stored type | Meaning and safe use |
| --- | --- | --- |
| `UnitID.id` | `BInt<0, MAX_UNIT_COUNT>` | Selects a unit in the bank required by the current action; not globally unique |
| `ModelID.id` | `BInt<0, MAX_UNIT_MODELS>` | Selects a current or archived model in the collection required by that input |
| `EntityIdentity.value` | bounded integer 0–16384 | Assigned once by Board identification; use lookup to find the entity's current location |

Unit and model identities share a monotonically allocated namespace. For
example, `Unit.embarked_transport` is the carrier **model identity**, whereas
`Board.moving_unit` is a current battlefield **unit index**. A missing lookup
is not permission to use slot zero. Re-resolve after a transfer or casualty.

## Board

Source: [board.rl](../src/board.rl).

The global battle container, including offboard state. Owned by Game. Phase,
setup, combat, source and transport procedures update it; Godot reads it to
present the current decision. Transient selectors are meaningful only while
that decision is active. A bare Board has no scoring mission; public `play()`
selects the legacy four-marker fixture.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `shared_actions` | `SharedActionFrames` | Reusable procedure storage; a completed slot can be overwritten by a later invocation. It is not a list of independent active abilities. |
| `pending_weapon_abilities` | `CheckedVector<WeaponRule, 32>` | Choices shown while resolving duplicate/selectable weapon abilities; replaced for each such decision. |
| `schema_version` | `StateSchema` | Save-layout marker, initialized to the current state schema; not an edition number. |
| `next_identity` | `IdentitySequence` | Number of identities allocated so far; identification increments it rather than recycling dead entities' handles. |
| `phase_serial` | `PhaseSerial` | Phase-cleanup epoch advanced by clear_phase_modifiers, including phase entry; history stamps compare against it, not modulo-five phase arithmetic. |
| `turn_serial` | `TurnSerial` | Engine turn counter advanced by turn entry; expiry and turn-limited use compare against it. |
| `battle_points_limit` | `LinearlyDistributedInt<0, 10001>` | Explicit roster-limit metadata for configured point-aware fixtures; public point-free play does not invent costs. |
| `moving_unit` | `UnitID` | Battlefield unit being manipulated by the movement context; restored after nested movement. |
| `damage_bank` | `SourceBank` | Bank supplying current damage/death model choices; restored after nested resolution. |
| `allow_destroyed_attack` | `Bool` | Explicit permission for the retained destroyed attacker; scoped by its controlling procedure. |
| `destroyed_attack_unit` | `UnitID` | Battlefield slot allowed to attack while destroyed when the preceding permission is active. |
| `surge_target` | `UnitID` | Closest-enemy unit selected for the current Surge; restored when the granted move finishes. |
| `expired_reserves` | `Hidden<Vector<Unit>>` | Retired reserve bookkeeping kept outside the normal observation after expiry/destruction. |
| `prebattle_scouts` | `Bool` | True during prebattle Scout resolution; distinguishes it from ordinary in-battle movement. |
| `timing` | `TimingState` | Phase/window/controller progress; see TimingState. |
| `units` | `UnitVector` | Battlefield unit slots, including retired slots; an array entry is not proof that the unit is alive. |
| `reserve_units` | `UnitVector` | Units currently in reserves. Arrival transfers the real unit and preserves its identity/history. |
| `embarked_units` | `UnitVector` | Passenger units currently embarked; their carrier link is stored on each unit. |
| `selected_passenger_bank` | `UnitID` | Despite the name, an index into embarked_units for the current Firing Deck selection, not a SourceBank enum. |
| `selected_passenger_model` | `ModelID` | Passenger model index in that selected unit; context for borrowed weapon choices. |
| `terrain_geometry` | `TerrainGeometryVector` | Configured grid-aligned solid supports/blockers used by movement geometry; separate from area visibility categories. |
| `terrain_areas` | `TerrainAreaVector` | Terrain-area bounds and category flags used by cover/partial-obscuring rules. |
| `objectives` | `Objective[4]` | Four marker/area configurations with boundary-updated control and securing state. |
| `mission_scoring` | `MissionScoringMode` | none on a bare Board; public play explicitly enables legacy_four_markers. |
| `oath_of_moment_target` | `UnitID` | Target unit slot for the retained legacy Oath rule; not a general source-effect target field. |
| `has_used_insane_bravery` | `Bool[2]` | Per-player battle-long use; a new turn does not refund it. |
| `has_used_shadow_in_the_warp` | `Bool[2]` | Per-player battle-long use of that retained faction rule. |
| `selected_warlord_unit` | `UnitID` | Unit-selection context during Warlord choice; the persistent result is armies[player].warlord. |
| `pending_modifier_choice` | `AttackModifierChoice` | Modifier currently offered for Apply/Ignore; label/context while that decision is suspended. |
| `pending_modifier_kind` | `ModifierSelectionKind` | What the pending modifier changes, such as skill or hit roll; restored with its context. |
| `active_source_events` | `PendingSourceEvents` | Frozen candidate event list currently presented to a controller; candidates are rechecked when chosen. |
| `source_instances` | `SourceInstances` | Registered abilities with source identities, conditions and limits; a disabled slot can remain present. |
| `source_uses` | `SourceUseRecords` | Usage ledger keyed by rule, owner, scope and subject; interval changes reset applicable counts. |
| `source_effects` | `SourceEffects` | Continuing effects with recipient identities and expiry; refresh removes expired or unsupported grants. |
| `next_source_effect` | `SourceEffectKey` | Allocator for unique effect keys; prevents a later effect being mistaken for an old one. |
| `next_source_generation` | `SourceEffectKey` | Allocator for source generations; pending events cannot resolve a newly reused source slot accidentally. |
| `attack_info` | `AttackSequenceInfo` | Context for the attacks currently being resolved; replaced as gathered groups change. |
| `orks_attack_records` | `OrksAttackRecords` | Orks per-attack hit/loss provenance used by post-attack reactions; not the unit's battle-long history. |
| `orks_attack_serial` | `LinearlyDistributedInt<0, 1025>` | Bounded attack-selection sequence stamp used to associate those records with an activation. |
| `move_requires_objective` | `Bool` | Temporary granted-move destination restriction; not a condition on all ordinary moves. |
| `constrained_mover` | `UnitID` | Unit whose endpoint is constrained by move_requires_objective; restored after the grant. |
| `orks_reaction_target` | `EntityIdentity` | Stable subject identity for a current Orks reaction; nested reaction runners restore it. |
| `orks_attack_active` | `Bool` | Marks the active attack context for Orks attack-dependent source checks. |
| `orks_support_bank` | `SourceBank` | Actual storage bank for current Orks own-unit support choices. |
| `orks_selected_unit` | `UnitID` | Selected unit index within the current Orks support/bank context; not a persistent identity. |
| `active_allocation_groups` | `AllocationGroups` | Current defender model-group choices for saves/allocation; rebuilt for the attack context. |
| `active_allocation_target` | `UnitID` | Battlefield target slot whose model groups are displayed for current allocation. |
| `obtained_extra_cp_this_round` | `Bool[2]` | Per-player cap bookkeeping for extra CP; reset at round start, separate from ordinary Command CP. |
| `command_points` | `CommandPoints[2]` | Two CP pools; cost commitment spends before the accepted effect resolves. |
| `current_round` | `LinearlyDistributedInt<0, MAX_ROUNDS>` | Zero-based battle-round index 0–4 during play; reaches 5 at the public battle's end. |
| `current_player` | `Bool` | Owner of the current turn, including while the opponent allocates damage or reacts. |
| `starting_player` | `Bool` | Player taking the first turn in each round of the public sequence. |
| `current_decision_maker` | `Bool` | Owner of the current ordinary decision; public current-player query additionally recognizes chance/terminal states. |
| `players_faction` | `Faction[2]` | Legacy roster-selection identifiers; do not infer current faction permissions from them. |
| `armies` | `ArmyConfiguration[2]` | Two explicit army configurations: faction, selected detachments, Warlord and army use. |
| `score` | `VictoryPoints[2]` | Two VP totals; awards come from the configured scoring fixture, not automatic mission discovery. |
| `phase_info` | `PhaseInfo` | Per-player used-stratagem lists for the current phase; phase cleanup resets the lists. |
| `attack` | `Attack` | Shared ordinary Attack continuation; callers preserve results before another attack can reuse it. |
| `current_roll` | `RerollableDice` | Shared one-die reroll continuation; a later roll overwrites it after completion. |
| `current_pair_roll` | `RerollableDicePair` | Shared summed-pair roll/reroll continuation; distinct from current_roll. |
| `current_state` | `CurrentStateDescription` | UI description enum for the current question; use actual legal actions to determine availability. |

## ArmyConfiguration

Source: [army_configuration.rl](../src/army_configuration.rl).

Owned by Board.armies[player]. Roster/detachment/Warlord selection writes it;
faction and source queries read it. It is separate from legacy Faction roster
IDs. The current detachments collection is specifically Orks data.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `faction` | `ArmyFaction` | Chosen army faction; unspecified by default, not inferred from unit display names. |
| `detachments` | `CheckedVector<OrksDetachment, 3>` | At most three distinct non-none Orks packages, recorded by validated selection; no detachment prices. |
| `reserve_budget` | `ReserveBudgetMode` | points_required by default for explicit fixtures; public selection uses point_free under the user's policy. |
| `warlord` | `EntityIdentity` | Selected model's stable identity; zero until selected, retained through transport/attachment/casualty changes. |
| `war_cry_used` | `Bool` | Army-long War Cry expenditure; source commitment sets it, ordinary phase/turn resets do not refund it. |

## Unit

Source: [units.rl](../src/units.rl).

A battle instance, owned by one Board bank. The model collection may include
bodyguards and attached characters. Roster/attachment/transport/movement/combat
procedures own changes; use has_live_model/eligibility queries rather than
assuming that a vector entry is usable. History and archived original models
are part of the unit, including when offboard.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `shokk_boosta_move` | `Bool` | Temporary Big Mek Advance mode; enabled for that selected move and cleared afterward. |
| `battle_start_models` | `Hidden<ModelVector>` | Original equipment/model snapshot for an identical replacement unit; distinct from the casualty archive used for revival. |
| `psyker_level` | `FixedStat` | Printed/combined resource capacity for psychic use, supplied by actual source data. |
| `orks_psychic_usage` | `OrksPsychicUsage` | Shared round budget plus Roar/Visions phase stamps; persists across banks and attachments. |
| `is_generated_replacement` | `Bool` | Marks a generated replacement so original-unit-only replacement effects cannot loop indefinitely. |
| `orks_destroyed_attack` | `LinearlyDistributedInt<0, 1025>` | Attack serial associated with this unit's destruction for eligible Orks reactions. |
| `orks_destroyed_phase` | `PhaseStamp` | Phase stamp for destruction-dependent Orks rules. |
| `off_battlefield` | `Bool` | State flag synchronized with reserve/embarked placement; visibility/range helpers also check actual bank membership. |
| `embarked_transport` | `EntityIdentity` | Carrier model identity; zero means not linked to a transport, even if the unit is otherwise offboard. |
| `has_return_slot` | `Bool` | Whether return_slot is a valid retained battlefield slot; the index alone has no unset sentinel. |
| `return_slot` | `UnitID` | Battlefield slot to restore after an offboard round trip when has_return_slot is true. |
| `shooting_kind` | `ShootingKind` | Selected shooting mode, normal by default; snap is permission-controlled rather than freely selected in the Shooting phase. |
| `snap_target` | `UnitID` | Target slot belonging to a constrained Snap Shooting invocation. |
| `lone_operative_range` | `FixedStat` | Explicit range override in inches; zero leaves the default 12-inch Lone Operative handling. |
| `models` | `ModelVector` | Current models, including any temporarily retained destroyed fighters; model indices can compact on removal. |
| `owned_by_player1` | `Bool` | Legacy-named ownership Bool: false is engine player 0, true is player 1; not the active-decision role. |
| `name` | `Hidden<String>` | Display label, outside normal ML observation; never use it to determine datasheet eligibility. |
| `has_moved` | `Bool` | Legacy-facing movement-selection flag maintained by movement/reset procedures; finer distinctions are in history. |
| `movement_override` | `MovementOverride` | Selected random-M snapshot encoded as M+1; zero uses ordinary characteristic calculation. |
| `movement_distance_limit` | `MovementOverride` | Temporary absolute allowance encoded as inches+1 for granted movement; zero means no such override. |
| `move_takes_to_skies` | `Bool` | Selected Fly movement mode; affects route rules and is restored after reactive movement. |
| `pending_move_kind` | `MovementKind` | Movement mode to be executed by the current core Move; not proof the move completed. |
| `has_run` | `Bool` | Legacy-facing Advance flag; maintained together with the relevant turn history. |
| `has_fought` | `Bool` | Fight-selection/completion state used by fight eligibility and phase cleanup. |
| `has_shoot` | `Bool` | Legacy-named shooting-selection flag used to prevent another ordinary selection in that phase. |
| `battle_socked` | `Bool` | Battle-shocked state; affects OC and permissions. Recovery follows the Command-step snapshot, not arbitrary passed shock rolls. |
| `has_charged` | `Bool` | Completed charge state used by fight/weapon rules, not just a charge declaration. |
| `can_shoot` | `Bool` | Current shooting permission; full eligibility also checks movement, engagement, mode and timing. |
| `can_charge` | `Bool` | Current charge permission; full eligibility additionally checks timing, range and history. |
| `starting_strenght` | `StartingStrength` | Original/combined starting model count; not recalculated downward when a model dies. |
| `identity` | `EntityIdentity` | Stable unit identity; a combined attached unit retains its bodyguard identity. |
| `destroyed_models` | `Hidden<Vector<Model>>` | Archived original models with equipment, identity, weapon use and death provenance; not live battlefield members. |
| `roster_datasheet` | `DatasheetCode` | Explicit current unit/card identity; zero is unknown legacy data, not an inferred display-name match. |
| `attachment_role` | `AttachmentRole` | bodyguard by default; data marks leader/support explicitly before attachment. |
| `permitted_bodyguards` | `BodyguardPermissions` | Allowed bodyguard datasheet codes from supplied source data, not inferred from CHARACTER alone. |
| `unit_abilities` | `Abilities` | Unit/component-scoped rules queried alongside model abilities; not a keyword copy to each member. |
| `bodyguard_waaagh` | `Bool` | Retained bodyguard component's Waaagh applicability in an attached unit. |
| `bodyguard_starting_strength` | `StartingStrength` | Original bodyguard component count, separate from the combined starting_strenght. |
| `attached_units` | `CheckedVector<AttachmentComponent, 2>` | Up to two provenance records: one Leader and one Support. Records survive component casualties. |
| `history` | `UnitHistory` | Phase/turn/battle eligibility and mission-action progress; reset only at the appropriate boundaries. |
| `retired` | `Bool` | Battlefield slot no longer contains an active unit. Explicit original-model return may reactivate it. |
| `unit_destruction_event_issued` | `Bool` | Prevents emitting the same whole-unit destruction event repeatedly. |
| `must_supply_warlord` | `Bool` | Unit-level mandatory-Warlord requirement; model-level prohibitions still take precedence. |
| `points_known` | `Bool` | Explicit metadata validity for point-aware fixtures; public point-free construction does not fabricate values. |
| `points` | `LinearlyDistributedInt<0, 10001>` | Configured point cost where points_known is true; not calculated by the current public roster. |
| `phase_modifiers` | `PhaseModifiers` | Phase-scoped charge modifiers, protection and stratagem effects, cleared by phase cleanup. |

## Model

Source: [units.rl](../src/units.rl).

A particular miniature owned by Unit.models or its casualty archive. Model
identity and original_unit persist through compaction/attachment/return.
Factories supply printed data and equipment; combat changes wounds/death state;
source refresh installs/removes grants. These properties describe the model,
not its scene sprite. In particular a CHARACTER elsewhere in the same unit
does not make this model a Character.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `paired_krumpas` | `Bool` | Nobz equipment flag consumed by Kustom Krumpa rules; not a second independent weapon profile. |
| `orks_enhancement` | `OrksEnhancement` | Chosen source-backed enhancement/Upgrade option; none by default. |
| `orks_upgrade_origin` | `EntityIdentity` | Original selection/unit identity for Upgrade accounting through attachments and casualty changes. |
| `orks_effects` | `OrksEffectGrants` | Current typed Orks grants on this recipient; source ownership/expiry removes the corresponding entries. |
| `off_battlefield` | `Bool` | Model's placement flag; reserve/passenger membership also prevents external geometry queries. |
| `orks_transport_permissions` | `Bool` | Enables the Orks infantry passenger filter for this carrier model. |
| `beast_snagga_passengers_only` | `Bool` | Carrier's extra Beast Snagga passenger restriction. |
| `forbid_ghaz_passenger` | `Bool` | Carrier's explicit Ghazghkull exclusion; identity predicates, not name text, enforce it. |
| `blastajet_force_field` | `Bool` | Source equipment choice which alters the model's Smoke keyword handling. |
| `transport_permissions_known` | `Bool` | False until actual transport metadata is supplied; unknown legacy data cannot invent capacity permission. |
| `transport_capacity` | `LinearlyDistributedInt<0, 33>` | Carrier seats, 0–32; zero does not permit passengers. |
| `transport_space` | `LinearlyDistributedInt<1, 33>` | Ordinary seat requirement, 1–32, default 1; effective accounting includes source exceptions such as paired Gretchin seats. |
| `permitted_passenger_keywords` | `Keywords` | Allowed passenger keyword alternatives; read together with the carrier's other filters. |
| `forbidden_passenger_keywords` | `Keywords` | Explicit passenger keyword exclusions; these can reject an otherwise permitted passenger. |
| `firing_deck` | `LinearlyDistributedInt<0, 33>` | Number of supported borrowed weapon selections for this carrier, 0–32; zero gives no Firing Deck. |
| `has_random_movement` | `Bool` | Whether random_movement must be rolled when the unit is selected to move. |
| `random_movement` | `Stat` | Printed random M expression; read only with the preceding flag, then store the selected unit allowance. |
| `scout_distances` | `CheckedVector<FixedStat, 8>` | Printed Scouts values; supported duplicate values must agree under the user's assertion policy. |
| `position` | `BoardPosition` | Whole-inch battlefield anchor; old coordinates of an offboard model do not authorize measurements. |
| `geometry` | `ModelGeometry` | Elevation, rotation, explicit circular proxy and unsupported-footprint gate. |
| `profile` | `Profile` | Printed model-characteristic catalog entry; it does not store current wounds remaining. |
| `datasheet` | `DatasheetCode` | Explicit per-model source identity; can differ between attached members of one unit. |
| `weapon_names` | `WeaponNameCode[MAX_WEAPONS]` | Named physical weapon-family identity for each slot, distinct from its numeric Weapon profile. |
| `weapon_profile_names` | `WeaponProfileCode[MAX_WEAPONS]` | Named profile identity for each slot; standard/supercharge are distinct profiles of a potentially shared weapon. |
| `characteristic_modifiers` | `CharacteristicModifiers` | Source-tagged changes to the model or its weapons; effective queries apply order and limits. |
| `incoming_attack_modifiers` | `IncomingAttackModifiers` | Recipient-specific incoming AP/D changes; apply to the allocated model, not every weapon on that model. |
| `attack_modifier_permissions` | `AttackModifierPermissions` | Source-scoped permission to ignore supported skill/hit modifiers; choices retain individual provenance. |
| `has_waaagh` | `Bool` | Actual army-rule applicability from data; do not infer it just from a legacy Ork-looking name. |
| `painboss_mounted_attachment` | `Bool` | Painboss's attached movement/keyword exception; changes this bearer's effective keywords only. |
| `has_da_boss` | `Bool` | Actual Da Boss army-rule applicability from the current source. |
| `must_be_warlord` | `Bool` | Model-level mandatory Warlord candidate; selection also considers faction and unit requirements. |
| `cannot_be_warlord` | `Bool` | Model-level prohibition, which overrides a mandatory requirement. |
| `grants_unit_riled_up` | `Bool` | Live bearer can confer riled status to its unit under its source rule. |
| `riled_source_effects` | `CheckedVector<SourceEffectKey, 8>` | Keys of continuing riled grants so expiry/removal does not erase another source's grant. |
| `suffered_wounds` | `Wounds` | Cumulative wounds lost, initially 0. Damage increases it; healing reduces it. It is not wounds remaining. |
| `has_damaged` | `Bool` | Whether an explicit Damaged threshold was supplied by this datasheet. |
| `damaged_threshold` | `Wounds` | Remaining-wounds threshold; use is_damaged, not suffered_wounds >= threshold. |
| `weapons` | `WeaponsVector` | Equipped profile entries, at most 13; per-slot identity/group arrays refer to this collection. |
| `additional_weapon_rules` | `CheckedVector<WeaponRule, 8>[MAX_WEAPONS]` | Extra source-owned rules for each equipped slot; selected/gathered rules use effective queries. |
| `abilities` | `Abilities` | Model's ability kinds from data/source handling; presence is distinct from current activation eligibility. |
| `keywords` | `Keywords` | Model's own stored keywords; effective has_keyword can account for sourced exceptions. |
| `state` | `ModelState` | normal, fight_on_death or pending_destruction; a retained corpse is not a living recipient. |
| `identity` | `EntityIdentity` | This miniature's stable handle; revival preserves it rather than issuing a new one. |
| `original_unit` | `EntityIdentity` | Original component unit identity; preserves attachment, token and equipment provenance. |
| `has_deadly_demise` | `Bool` | Whether the source supplied Deadly Demise; no explosion is inferred from model size. |
| `deadly_demise` | `Stat` | Printed random/fixed mortal-wound expression, used only when the ability applies. |
| `destruction_pending` | `Bool` | Death has pending processing; do not equate this with immediate removal from Unit.models. |
| `destroyed_phase` | `PhaseStamp` | History stamp of destruction, used by later source timing and return rules. |
| `attachment_abilities_retained` | `Bool` | An attack-destroyed attached source temporarily retains applicable conferred rules until attack-end processing. |
| `destroyed_whole_unit` | `Bool` | This casualty carries the combined unit's whole-unit destruction event; not a separate event for each original component. |
| `destruction_released` | `Bool` | Delayed destruction can now resolve its effects/removal after fighting or phase-end release. |
| `destruction_attack_suppressed` | `Bool` | Prevents an otherwise available destruction attack when its release policy requires suppression. |
| `destroyed_by_attack` | `Bool` | Distinguishes attack-caused destruction from direct removal/non-attack effects. |
| `destroying_unit_known` | `Bool` | Whether destroying_unit and its identity contain an actual source; a zero slot alone is not evidence. |
| `destroying_unit` | `UnitID` | Destroying unit's battlefield slot snapshot where the source is known. |
| `destroying_unit_identity` | `EntityIdentity` | Stable killer provenance when later slot movement/replacement would make an index ambiguous. |
| `destruction_fight_roll` | `Dice` | Source-supplied threshold for the retained legacy destruction-fight roll; meaningful only with that pending rule. |
| `history` | `ModelHistory` | Movement path totals/setup and Epic Challenge state for this model. |
| `weapon_profile_groups` | `LinearlyDistributedInt<0, MAX_WEAPON_SCOPES>[MAX_WEAPONS]` | Zero leaves a slot independent; equal nonzero values associate alternative profiles with one physical copy. |
| `simultaneous_ranged_profiles` | `Bool[MAX_WEAPONS]` | Explicit per-slot exception to choosing only one profile of a physical weapon; not a general rule for all models. |
| `hunter_profile_conditions` | `WeaponRule[MAX_WEAPONS]` | Per-profile target-keyword condition checked when that profile is declared. |
| `used_once_per_battle_weapon` | `Bool[MAX_WEAPONS]` | Per-slot One Shot expenditure; grouping logic shares use across profiles of the same physical copy and revival preserves it. |

## AttachmentComponent

Source: [state_types.rl](../src/state_types.rl).

Owned by Unit.attached_units. Attachment records the original component;
casualties do not erase its identity or original strength. Component queries
use these records together with surviving/temporarily retained source models.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `identity` | `EntityIdentity` | Original Leader/Support unit identity before joining the bodyguard. |
| `starting_strength` | `StartingStrength` | Original component's starting model count, retained after casualties. |
| `name` | `Hidden<String>` | Original component display name, not an eligibility predicate. |
| `role` | `AttachmentRole` | Explicit leader or support role in a combined unit; bodyguard is the enum default before setup. |
| `datasheet` | `DatasheetCode` | Original component datasheet code for exact permission/source checks. |
| `abilities` | `Abilities` | Unit-scoped abilities contributed by that component; live/retained source rules govern applicability. |
| `psyker_level` | `FixedStat` | Original component psychic capacity, retained for combined-unit accounting. |
| `waaagh` | `Bool` | Original component's actual Waaagh applicability, not inherited from every attached model. |

## BoardPosition

Source: [vector2d.rl](../src/vector2d.rl).

Owned by model positions, configured objectives and action payloads. It is
an input/storage position on the retained inch grid, not a Godot pixel position.
Movement/placement procedures validate every relevant base before committing.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `x` | `CoordinateX` | Whole-inch x anchor, 0–43; boundaries still have to accommodate the circular base. |
| `y` | `CoordinateY` | Whole-inch y anchor, 0–29; translate display pixels through the grid interaction layer. |

## ModelGeometry

Source: [geometry.rl](../src/geometry.rl).

Owned by Model.geometry. Queries reconstruct physical base distances from
the stored anchor and metadata. Factories set the supported footprint/proxy;
movement changes supported elevation/rotation. This does not enable fractional
player position inputs or sculpted-model visibility.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `proxy_diameter_mm` | `LinearlyDistributedInt<0, 1001>` | Explicit circular diameter, 0–1000 mm; zero uses the profile's base data. A supplied hull proxy is intentionally approximate. |
| `elevation` | `GridElevation` | Whole-inch model elevation, 0–30; used in vertical engagement/coherency and movement checks. |
| `rotation` | `Rotation` | Integer thousandths of a degree, 0–359999; whole-degree movement choices convert into this representation. |
| `unsupported_footprint` | `Bool` | True rejects unsupported placement/distance cases rather than silently guessing unknown geometry. |

### Useful computed queries

These are results, not extra stored fields. Godot calls methods through the
library, for example `library.wounds_left(model)`.

| Query | What the result means | Example |
| --- | --- | --- |
| `Model.wounds_left()` | Printed profile W minus suffered_wounds | A 6W model with 2 suffered wounds has 4 remaining |
| `Model.is_alive()` | Normal model state and positive remaining wounds | A retained Fight on Death model can be present but not alive |
| `Model.is_damaged()` | Explicit Damaged ability and remaining wounds at/below its supplied threshold | Low health alone does not grant a Damaged rule |
| `Model.effective_toughness()` / `effective_save()` | Printed value plus applicable model modifiers and characteristic limits | A Sv change is not a modifier to a saving throw |
| `Model.effective_invulnerable_save()` | Applicable profile/source permission and modifiers | A profile sentinel above 6 means no usable InSv until an actual grant supplies one |
| `Model.effective_movement(base)` | Effective M from a supplied selected base plus applicable grants | Random M selection and a granted move's absolute distance are different inputs |
| `Model.effective_leadership()` / `effective_objective_control()` | Model characteristic values before unit-level status handling | For scored OC, use the unit/board query that also accounts for Battle-shock |
| `Unit.model_objective_control(index)` | Model's contribution under the current unit's status | Battle-shock can make the contribution zero |
| `Unit.get_unit_toughtness()` | Attack-facing effective T with the attached-bodyguard policy | Do not average the Leader and bodyguards' printed T |
| `Unit.has_keyword(kind)` / `Model.has_keyword(kind)` | Effective keyword membership at the requested scope | A combined unit can qualify while a particular bearer does not |
| `Unit.is_coherent()` | Living models satisfy the supported neighbour, distance and connected-group policy | A corpse cannot bridge two live clusters |

For setup/visibility use the board-aware helpers in
[movement_rules.rl](../src/movement_rules.rl) and
[terrain_rules.rl](../src/terrain_rules.rl). A raw model coordinate or an
isolated distance calculation cannot establish all setup/targeting permissions.

## TimingState

Source: [state_types.rl](../src/state_types.rl).

Owned by Board.timing. Phase and timing-window runners write these values;
eligibility/source dispatch read them. The turn owner remains Board.current_player
when an enemy reaction changes the active role or decision owner.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `active_player` | `Bool` | Player whose active rule role is being resolved; nested movement/attacks restore the previous role. |
| `phase` | `BattlePhase` | none/command/movement/shooting/charge/fight; entered by the turn runner, cleared between phases. |
| `window` | `TimingWindow` | Current named boundary such as movement_end; use it with open/stage, not on its own as proof of an offered decision. |
| `stage` | `TimingStage` | closed, current_player_rules, opposing_player_rules or mission_rules; follows controller sequencing. |
| `open` | `Bool` | Whether a timing window is currently resolving; opening an already-open window is rejected. |
| `controller` | `Bool` | Controller group being resolved in that window; separate from the turn owner and any nested choice owner. |

## UnitHistory

Source: [state_types.rl](../src/state_types.rl).

Owned by Unit.history in every bank. Board phase/turn entry, movement,
shooting, transport, fighting and mission-action helpers are the writers. A
phase stamp normally means serial+1; zero means not recorded. Some flags are
turn-local, others preserve deployment/battle history as noted below.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `phase_start_members` | `CheckedVector<EntityIdentity, MAX_UNIT_MODELS>` | Stable identities of live members at phase start; ordinary returning models cannot use a newly returned model as a phase-start anchor. |
| `phase_start_engagements` | `CheckedVector<EntityIdentity, MAX_UNIT_COUNT>` | Enemy unit identities engaged at phase start; ordinary returns cannot create a new enemy engagement. |
| `embarked_phase` | `PhaseStamp` | Embarkation phase stamp used by disembark eligibility; updated on embark rather than each turn. |
| `ingress_turn` | `TurnStamp` | Turn stamp of battlefield arrival; retains when that arrival happened. |
| `ingress_used_deep_strike` | `Bool` | Whether the recorded arrival used Deep Strike; supports setup-specific restrictions. |
| `disembarked_this_turn` | `Bool` | Turn-local disembark history, reset at the turn boundary. |
| `tactical_move_required` | `Bool` | Tactical disembarkation still requires its prescribed move; cleared only by completion/appropriate cleanup. |
| `deck_shooting_locked` | `Bool` | Borrowed Firing Deck shooting prevents the passengers' prohibited later shooting in the turn. |
| `last_move_phase` | `PhaseStamp` | Phase stamp of an actual completed move, including a granted out-of-phase move; a declined move does not set it. |
| `selected_move_phase` | `PhaseStamp` | Phase stamp of movement selection; differs from a completed move and prevents duplicate selection. |
| `declared_charge_phase` | `PhaseStamp` | Phase stamp of a charge declaration; not evidence that the charge move succeeded. |
| `charge_move_phase` | `PhaseStamp` | Phase stamp of a completed charge move. |
| `pile_in_phase` | `PhaseStamp` | Phase stamp of this unit's resolved Pile In selection. |
| `consolidation_phase` | `PhaseStamp` | Phase stamp of its Consolidation selection. |
| `engaged_fight_start_phase` | `PhaseStamp` | Whether/when engaged at Fight-phase start, preserving that eligibility after other units move. |
| `fight_eligible_phase` | `PhaseStamp` | Frozen Fight eligibility stamp used alongside live engagement/status checks. |
| `consolidation_fight_pending` | `PhaseStamp` | Fight eligibility granted by the specific consolidation follow-up; consumed by the fight runner. |
| `move_kind` | `MovementKind` | Recorded movement mode; stationary is the enum default, but actual eligibility also checks setup and path history. |
| `made_move_this_turn` | `Bool` | Completed movement history for turn-local effects; reset each turn. |
| `advanced_this_turn` | `Bool` | Advance history for turn-local shooting/charge restrictions. |
| `advance_allows_charge` | `Bool` | Permission captured when that Advance was selected, even if a grant later changes. |
| `fell_back_this_turn` | `Bool` | Fall-back history; separate source permissions may waive particular restrictions. |
| `fallback_allows_charge` | `Bool` | Captured charge exception for that retreat; not permission for every other restricted operation. |
| `fallback_allows_shooting` | `Bool` | Captured shooting exception for that retreat. |
| `selected_move_allows_action` | `Bool` | Explicit action-start permission associated with the selected movement rule. |
| `ingress_locked` | `Bool` | Arrival locks ordinary movement; the turn runner releases the battlefield lock after Shooting-end resolution, before Charge. |
| `strategic_reserve` | `Bool` | The unit actually has Strategic Reserve status; ordinary offboard placement alone does not infer it. |
| `repositioned` | `Bool` | History of leaving/repositioning after battle start; distinguishes original reserve-expiry handling. |
| `has_ingressed` | `Bool` | Whether an arrival has already occurred; retained across later reserve round trips. |
| `scouts_resolved` | `Bool` | Prebattle Scouts choice already resolved; not reset to give another Scout move each turn. |
| `last_ranged_attack_turn` | `TurnStamp` | Turn stamp of actual ranged attacks, not merely selecting or declining shooting; preserves previous-turn Hidden checks. |
| `was_set_up_this_turn` | `Bool` | Setup/arrival history used by Heavy, movement and target rules; reset at a turn boundary. |
| `used_stratagem_this_phase` | `Bool` | Unit-level use restriction for that phase; distinct from army/player card usage. |
| `stratagem_targeted_by_player` | `Bool[2]` | Two per-player targeting flags, so a different payer does not accidentally bypass that player's limit. |
| `shot_this_phase` | `Bool` | Actual shooting history used by current phase permissions/after-effects. |
| `wrecka_objective_selection` | `Bool` | Wreckas' objective proximity snapshot for the relevant selection; not a permanent objective-control flag. |
| `action_started` | `Bool` | A mission action has been started this turn; does not mean a Rulebook input/coroutine has started. |
| `action_completed` | `Bool` | Summary of the last resolved mission-action completion result. |
| `action_records` | `CheckedVector<UnitActionProgress, MAX_TURN_STAMP>` | Distinct mission-action starts/completions, allowing cross-turn pending work without overwriting an earlier record. |
| `action_pending` | `Bool` | At least one mission-action record is unresolved. |
| `action_failed` | `Bool` | Current/last mission-action failure summary; interruption also marks the relevant unresolved records. |

## ModelHistory

Source: [state_types.rl](../src/state_types.rl).

Owned by Model.history. Movement records path segments and turn entry clears
turn-local distance/setup history; Epic Challenge is scoped by its rule/cleanup.
The path representation stores bounded integers, not a persistent floating sum.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `horizontal_segments` | `CheckedVector<HorizontalSquare, MAX_MOVEMENT_SEGMENTS>` | Up to 128 squared whole-grid horizontal lengths, each 0–2690; summing square roots recovers travelled horizontal distance. |
| `vertical_distance` | `VerticalDistance` | Accumulated vertical inch distance, 0–3840; added to horizontal path lengths by distance_moved_this_turn. |
| `was_set_up_this_turn` | `Bool` | This miniature's setup history; affects per-bearer conditions even in a mixed unit. |
| `epic_challenge` | `Bool` | The selected CHARACTER model's current melee Precision permission; not inherited by every model in its unit. |

## UnitActionProgress

Source: [state_types.rl](../src/state_types.rl).

Owned by UnitHistory.action_records. Mission-action helpers create and resolve
records; interruption marks failure. This describes a tabletop mission action,
not an arbitrary generated input or a unit's ordinary activation.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `started_turn` | `TurnStamp` | Turn stamp identifying this particular action start, not its completion deadline supplied by a mission. |
| `failed` | `Bool` | An interruption/invalid completion has made this record unsuccessful. |
| `resolved` | `Bool` | Completion was evaluated; repeated completion cannot award the result again. |
| `completed` | `Bool` | The resolved record completed successfully; unresolved/default false is not itself a failure. |

## ModelPath

Source: [movement_geometry.rl](../src/movement_geometry.rl).

Temporary staged movement owned by a movement procedure. Waypoints are
validated before committing the final model position; finishing a model and
finishing the complete unit move are separate choices.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `model` | `ModelID` | Index of the original model being moved in this staged unit context. |
| `points` | `CheckedVector<StoredGridPoint, 16>` | Up to 16 stored grid waypoints; physical geometry is reconstructed for route checks. |
| `final_rotation` | `Rotation` | Staged rotation in thousandths of a degree; does not change the live model until the relevant commit. |

## DeclaredWeapon

Source: [attack_declarations.rl](../src/attack_declarations.rl).

Owned by the attack declaration collection, not by the equipped-model catalog.
Selection freezes the physical bearer/profile and per-target declaration facts;
gathering refreshes the facts that the rules require live. Arrays are indexed by
battlefield target UnitID. Do not reuse a casualty-compacted ModelID without
resolving model_identity.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `model` | `ModelID` | Bearer model index at declaration; retained for context, with identity used to recover its current location. |
| `model_identity` | `EntityIdentity` | Persistent identity of the firing/fighting model used by the attack pipeline. |
| `weapon_owner` | `EntityIdentity` | Original physical weapon owner's identity; Firing Deck can borrow a passenger weapon for a carrier attack. |
| `physical_group` | `LinearlyDistributedInt<0, MAX_WEAPON_SCOPES>` | Selected physical weapon's group; nonzero values link its alternative profiles. |
| `slot` | `BInt<0, MAX_WEAPONS>` | Equipped profile slot, 0–12; not a global Weapon enum ordinal. |
| `weapon` | `Weapon` | Chosen printed numeric Weapon profile; selecting it commits that profile for this declaration. |
| `borrowed_weapon` | `Bool` | True for a borrowed profile such as Firing Deck; carrier slot-specific grants must not leak onto it. |
| `weapon_name` | `WeaponNameCode` | Physical weapon-family code used by named-family predicates. |
| `profile_name` | `WeaponProfileCode` | Named profile code used by profile-specific predicates. |
| `hunter_condition` | `WeaponRule` | Selected Hunter profile's target-keyword condition. |
| `selected_rules` | `WeaponAbilitySet` | Effective/selectable rules captured for the selected weapon. |
| `current_target_rules` | `WeaponAbilitySet` | Rule choice set for the target currently being resolved; target-conditioned duplicate choices may differ. |
| `made_attacks` | `Bool` | Whether this declaration actually made attacks; mere selection is different for after-effects/use history. |
| `target_model_counts` | `CombatCounter[MAX_UNIT_COUNT]` | Per-target live-count snapshot at declaration, including Blast-relevant facts. |
| `half_range` | `Bool[MAX_UNIT_COUNT]` | Per-target range snapshot, not recalculated solely because later casualties change the nearest model. |
| `targeted` | `Bool[MAX_UNIT_COUNT]` | Which targets were declared for this weapon/profile. |
| `resolved` | `Bool[MAX_UNIT_COUNT]` | Which declared target shares have been processed or discarded. |
| `shares` | `AttackShare[MAX_UNIT_COUNT]` | Fixed melee attack shares assigned to each target; random-A melee is explicitly unsupported/asserted by user policy. |
| `melta_bonus` | `LinearlyDistributedInt<0, MAX_STAT_MODIFIER>[MAX_UNIT_COUNT]` | Per-target declared Melta amount associated with half-range/rule selection. |

## AttackSequenceInfo

Source: [board.rl](../src/board.rl).

Owned by Board.attack_info for the active attack context. Configuration and
declared-group gathering write it; hit/wound/save/damage queries consume it.
It is not a battle log or a substitute for declarations. Group snapshots must
not be confused with a printed Weapon or with a target's current live state.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `squig_launcha_weapon` | `Bool` | Tracks Squig Launcha hit provenance through grouping for its actual source ability. |
| `shooting_kind` | `ShootingKind` | Mode of this attack, including source-granted Snap/Indirect restrictions. |
| `weapon_rules_known` | `Bool` | Whether selected_weapon_rules is the authoritative selected set; direct legacy fixtures can fall back to profile rules. |
| `selected_weapon_rules` | `CheckedVector<WeaponRule, 32>` | Applicable chosen weapon rules for the gathered group, at most 32. |
| `indirect_stationary_visible` | `Bool` | Snapshot enabling the printed improved Indirect gate when stationary and a friendly unit sees the target. |
| `heavy_bonus` | `Bool` | Whether the bearer meets Heavy's actual movement/phase conditions for this group. |
| `damaged_hit_penalty` | `Bool` | This group's bearer-local Damaged contribution, before the cumulative hit modifier cap. |
| `engaged_hit_penalties` | `LinearlyDistributedInt<0, 3>` | 0–2 applicable engaged Monster/Vehicle penalties, combined with other hit terms before capping. |
| `source_unit_id` | `UnitID` | Battlefield attacker slot in this attack context. |
| `target_unit_id` | `UnitID` | Battlefield target slot; nested damage temporarily installs/restores the appropriate context. |
| `penetration_bonus` | `Bool` | Legacy/core AP-improvement contribution; effective penetration applies it with the correct AP direction. |
| `melta_damage_bonus` | `LinearlyDistributedInt<0, MAX_STAT_MODIFIER>` | Applicable additional damage for this group, a characteristic contribution rather than a second damage event. |
| `precision_visibility_known` | `Bool` | Whether the per-target-model Precision visibility snapshot has been established. |
| `precision_visible_targets` | `Bool[32]` | Which target model slots satisfy the current Precision visibility selection condition. |
| `dodge_dis_hit_bonus` | `Bool` | Beastboss unit-rule hit contribution, distinct from a BS/WS characteristic modifier. |
| `hit_roll_bonus` | `Bool` | Retained generic/legacy positive hit contribution; combine it with other terms before the +/-1 cap. |
| `orks_hit_modifiers` | `RuleModifiers` | Source-owned Orks hit arithmetic for this attack group. |
| `orks_unit_hit_modifiers` | `CheckedVector<RuleModifier, MAX_DATASHEET_HIT_MODIFIERS>` | Separately retained unit/repair hit contributions so optional ignoring can distinguish sources. |
| `orks_wound_modifiers` | `RuleModifiers` | Source-owned Orks wound arithmetic for the group. |
| `orks_fail_hits_three` | `Bool` | Rule-specific unmodified low-hit failure gate; not just a -1 arithmetic modifier. |
| `target_has_cover` | `Bool` | Cover snapshot used by the current edition's BS handling, not a copied armour-save bonus. |
| `plunging_fire` | `Bool` | Printed Plunging Fire condition; current handling affects BS and excludes Aircraft as required. |
| `hit_roll_malus` | `Bool` | Retained negative hit contribution; does not bypass the cumulative modifier cap. |
| `profile_hit_roll_bonus` | `CheckedVector<Profile, 8>` | Legacy selective hit bonuses keyed by source model Profile; not all models in a mixed unit qualify. |
| `temporary_weapon_abilities` | `CheckedVector<WeaponRule, 8>` | Attack-local granted weapon rules, distinct from permanent equipped profile data. |
| `wound_roll_malus` | `Bool` | Retained negative wound contribution, combined before the wound modifier cap. |
| `wound_roll_bonus` | `Bool` | Retained positive wound contribution. |
| `profile_wound_roll_bonus` | `CheckedVector<Profile, 8>` | Legacy selective wound bonuses keyed by source model Profile. |
| `reroll_hits` | `Bool` | Permission for eligible full hit rerolls in this attack context. |
| `reroll1_hits` | `Bool` | Permission for eligible unmodified hit rolls of 1; replacement dice cannot be rerolled again. |
| `only_hits_on_6` | `Bool` | Explicit unmodified-six hit requirement for the granting rule. |
| `reroll_wounds` | `Bool` | Permission for eligible full wound rerolls. |
| `reroll1_wounds` | `Bool` | Permission for eligible wound rolls of 1. |
| `greater_strenght_wound_protection` | `Bool` | Legacy protection when incoming strength exceeds target toughness; enters the wound arithmetic. |
| `fight_on_death` | `Bool` | Accepted attack-context permission for the recipient's delayed destruction attack. |
| `fight_on_death_roll` | `Dice` | Supplied threshold for that permission; not the current hit/wound die. |
| `target_toughness` | `Toughness` | Gathered effective target T; attached-bodyguard selection and earlier group casualties are handled before setting it. |
| `source` | `Weapon` | Selected Weapon profile for the group; not the source Unit/Model object. |
| `characteristics_known` | `Bool` | Whether gathered characteristic snapshots/modifier operations are authoritative rather than direct-fixture fallback. |
| `weapon_strength` | `FixedStat` | Gathered effective S when characteristics_known is true. |
| `skill_modifiers` | `RuleModifiers` | WS/BS characteristic operations; kept separate from modifications to the hit roll itself. |
| `may_ignore_skill_modifiers` | `Bool` | Bearer permission to choose which supported skill operations apply. |
| `may_ignore_hit_modifiers` | `Bool` | Bearer permission to choose which supported hit operations apply. |
| `ap_modifiers` | `RuleModifiers` | Outgoing AP arithmetic, combined with actual recipient-scoped incoming modifiers at allocation. |
| `damage_modifiers` | `RuleModifiers` | Outgoing D arithmetic, applied with the allocated recipient's modifiers after any random damage determination. |
| `source_profile` | `Profile` | Model Profile of the actual group bearer for profile-scoped rules. |
| `current_round` | `BInt<0, MAX_ROUNDS>` | Retained attack-context round metadata; not the authoritative battle clock, which is Board.current_round. |

## AllocationGroup

Source: [state_types.rl](../src/state_types.rl).

Owned by the current damage/allocation procedure and exposed through Board
for defender controls. Groups describe compatible recipients, not new units.
Rebuild/recheck as casualties change the target.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `members` | `CheckedVector<EntityIdentity, 32>` | Stable identities of candidate models, avoiding accidental retargeting after vector compaction. |
| `wounds` | `FixedStat` | Printed maximum W shared by these candidates; wounded allocation priority is tracked separately. |
| `save` | `FixedStat` | Effective armour-save grouping value. |
| `invulnerable` | `FixedStat` | Effective invulnerable-save grouping value; an unavailable save is not made usable by its numeric sentinel. |
| `character` | `Bool` | Whether this group contains Character recipients under the allocation policy. |
| `wounded` | `Bool` | Whether the recipients already have suffered wounds, relevant to allocation priority. |
| `precision_visible` | `Bool` | Whether the group's Character selection meets the current Precision visibility condition. |

## DamageJob

Source: [damage_rules.rl](../src/damage_rules.rl).

Owned by a pending damage-job list and consumed by the common damage runner.
It identifies real storage and provenance. Amount is an input to that stage;
it is not a license to subtract that many wounds without prevention/allocation.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `kind` | `DamageKind` | DamageKind chooses the required damage/direct-destruction behavior; interpret amount with that kind. |
| `bank` | `SourceBank` | battlefield by default, or reserves/embarked for an actual offboard recipient. |
| `target` | `UnitID` | Target unit index in bank, not necessarily Board.units. |
| `source` | `UnitID` | Source unit slot when source_known; an unknown source does not become unit 0. |
| `source_known` | `Bool` | Whether source provenance is supplied and may be queried. |
| `from_attack` | `Bool` | Whether this job is caused by an attack; attack-end destruction timing depends on it. |
| `amount` | `CombatCounter` | Bounded requested amount of the job's kind; the runner performs the corresponding rules processing. |
| `recipient` | `EntityIdentity` | Persistent model recipient where the job specifies one; zero leaves the applicable selection policy to the runner. |

## PendingDestruction

Source: [damage_rules.rl](../src/damage_rules.rl).

Returned by the common destruction scan. The indices refer to the current
scan result, not a permanent handle; another resolution can change them.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `found` | `Bool` | Whether the scan found an eligible pending death; false makes the other selectors non-authoritative. |
| `bank` | `SourceBank` | Actual collection containing that pending model/unit. |
| `unit` | `UnitID` | Unit index within bank for the current result. |
| `model` | `ModelID` | Model index within that unit for the current result. |

## CharacteristicModifier

Source: [modifiers.rl](../src/modifiers.rl).

Owned by model.characteristic_modifiers or used as a source payload.
Effective characteristic/declaration queries consume it; keyed source refresh
removes only the entries associated with that effect.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `source_effect` | `SourceEffectKey` | Effect ownership key; zero denotes intrinsic/manual metadata rather than a timed owned grant. |
| `characteristic` | `ModifiedCharacteristic` | Which model/weapon characteristic changes; distinct from changing a dice result. |
| `modifier` | `RuleModifier` | Operation, magnitude and sign, applied in the common modifier order. |
| `weapon_scope` | `LinearlyDistributedInt<0, MAX_WEAPON_SCOPES>` | Zero covers the applicable equipped weapons; positive value is representative slot+1. |
| `weapon_name` | `WeaponNameCode` | Optional physical-family filter; zero means unrestricted by family. |
| `profile_name` | `WeaponProfileCode` | Optional named-profile filter; zero means unrestricted by named profile. |
| `physical_scope` | `Bool` | When true, the representative slot can cover linked profiles of the same physical weapon. |

## IncomingAttackModifier

Source: [modifiers.rl](../src/modifiers.rl).

Owned by the allocated recipient Model, not by the incoming weapon's bearer.
Save/damage processing combines applicable recipient operations with outgoing
operations. This is how recipient-specific AP/D reduction keeps its scope.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `source_effect` | `SourceEffectKey` | Owner effect key; zero is an intrinsic/manual entry. |
| `characteristic` | `ModifiedCharacteristic` | Incoming AP or D being modified; constructors reject unrelated characteristics. |
| `modifier` | `RuleModifier` | Arithmetic operation and signed amount, not an already capped final result. |
| `scope` | `IncomingAttackScope` | any_attack, ranged or melee; does not silently turn ranged protection into melee protection. |

## AttackModifierPermission

Source: [modifiers.rl](../src/modifiers.rl).

Owned by Model.attack_modifier_permissions. Choice collection tests its scope;
the Apply/Ignore procedure selects individual operations before resolving them.
Permission does not itself alter a characteristic.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `source_effect` | `SourceEffectKey` | Owner effect key for expiry; zero denotes intrinsic/manual permission. |
| `scope` | `IncomingAttackScope` | Attack scope for this permission: any, ranged or melee. |
| `skill` | `Bool` | May choose supported WS/BS characteristic modifiers. |
| `hit_roll` | `Bool` | May choose supported hit-roll modifiers, separately from the skill permission. |

## RoundResourceBudget

Source: [state_types.rl](../src/state_types.rl).

Owned by a source's usage state; currently the Orks psychic usage record embeds
one. Sources supply capacity. available checks the interval/capacity;
roll_spent_round_resource spends before accepting the die and rerolls do not
spend again. A budget alone grants no psychic ability.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `round_stamp` | `LinearlyDistributedInt<0, MAX_ROUNDS>` | Round index+1 of the last spend; zero is unused. A different requested stamp makes the prior count inapplicable. |
| `spent` | `FixedStat` | Uses committed in that stamped round; a spend in a new round resets the count to 1. |

## SourceInstance

Source: [source_effect_types.rl](../src/source_effect_types.rl).

Owned by Board.source_instances. Registration allocates a slot/generation;
event collection freezes candidates and resolution rechecks conditions/use.
A registered source is an ability definition tied to actual game identities,
not the continuing buff produced by using it.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `generation` | `SourceEffectKey` | Assigned registration generation; a pending event must match it before reusing a source slot. |
| `required_embarked_model` | `EntityIdentity` | Optional dependent passenger identity for cargo-granted rules; zero means no such dependency. |
| `required_carrier_model` | `EntityIdentity` | Optional carrier dependency identity; moving/destroying the carrier can invalidate the source. |
| `rule` | `SourceRuleCode` | Explicit source rule code 1–512 on registration; shared use is determined by code/scope, not name equality. |
| `label` | `Hidden<SourceLabel>` | Finite presentation ID for source choices; zero is no label. Text is derived on demand, outside normal ML observation; this is not the source-use key. |
| `source_unit` | `EntityIdentity` | Original source/component unit identity, including a component later attached into another unit. |
| `source_model` | `EntityIdentity` | Specific bearer identity where applicable; zero denotes a unit/component source. |
| `owner` | `Bool` | Controlling player for this source and its usage/effect ownership. |
| `trigger` | `SourceEventKind` | Core event kind which can trigger the ability, such as move_end or model_destroyed. |
| `window` | `TimingWindow` | Named timing boundary for timing-window sources. |
| `phase` | `BattlePhase` | Phase condition where the source specifies it; none denotes no specific phase restriction. |
| `own_turn_only` | `Bool` | Restricts activation to the owner's turn. |
| `opposing_turn_only` | `Bool` | Restricts activation to the opponent's turn; not a change of source ownership. |
| `requires_unengaged` | `Bool` | Requires the relevant unit to be outside enemy engagement when checked. |
| `restrict_movement` | `Bool` | Whether the movement kind filter is active. |
| `movement` | `MovementKind` | Required movement kind when restrict_movement is true. |
| `subject` | `SourceSubject` | Relationship of the event subject to the source, such as own/friendly/enemy/target unit. |
| `use_scope` | `SourceUseScope` | Army/unit/model scope for the explicit rule's shared use key. |
| `limits` | `SourceUseLimits` | Per-phase/turn/round/battle limits; zero in an interval means unlimited for that interval. |
| `disabled` | `Bool` | Source slot no longer active; keeping the slot prevents stale pending references being reassigned silently. |
| `aura` | `Bool` | Source has continuously refreshed recipients rather than only a one-off event grant. |
| `own_unit_passive` | `Bool` | Source-bound own-unit passive, including permitted offboard own-unit use. |
| `requires_leading` | `Bool` | Source applies under its actual while-leading condition, not merely because the model is a CHARACTER. |
| `model_specific_rule` | `Bool` | Use the bearer-specific live-source policy rather than retained conferred unit rules. |
| `recipient_condition` | `KeywordPredicate` | ALL/ANY/NONE keyword predicate for recipient selection. |
| `optional` | `Bool` | Whether the controller can decline this source; false is the default, not an automatic consent choice. |
| `allow_retained_source` | `Bool` | Explicitly permits the rule's retained-source handling during the appropriate death lifecycle. |
| `offboard_allowed` | `Bool` | Permitted source context can be offboard; this does not create external visibility/range. |
| `trigger_range` | `FixedStat` | Range in inches for ranged source checks; interpret zero with the source's own subject/eligibility policy. |
| `grant` | `SourceGrant` | Typed payload, e.g. characteristic modifier, weapon rule, riled state or current Orks effect. |
| `recipient` | `SourceTarget` | Which source/event/target unit or source model receives the payload. |
| `duration` | `SourceDuration` | Expiry policy, phase by default; actual source adapters supply their printed duration. |
| `requires_live_source` | `Bool` | Continuing grant depends on the source remaining eligible to confer rules; retained attack-end exceptions remain explicit. |

## SourceEvent

Source: [source_effect_types.rl](../src/source_effect_types.rl).

A core event value supplied to source collection. It records what happened;
it is not an installed ability or a player action payload.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `movement` | `MovementKind` | Move kind accompanying a movement event, where applicable. |
| `kind` | `SourceEventKind` | Event kind, such as attack_targeted, shock_end or unit_destroyed. |
| `window` | `TimingWindow` | Named boundary for a timing-window event. |
| `unit` | `EntityIdentity` | Stable identity of the event's subject unit. |
| `target` | `EntityIdentity` | Stable identity of the event's target where applicable; zero when absent. |
| `model` | `EntityIdentity` | Stable identity of the event's subject model where applicable; zero when absent. |

## PendingSourceEvent

Source: [source_effect_types.rl](../src/source_effect_types.rl).

Owned by a controller's candidate list. Earlier effects can remove a bearer,
change a condition or spend a shared limit, so selection always revalidates it.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `generation` | `SourceEffectKey` | Generation captured when this candidate was collected; must still match its source slot. |
| `source` | `LinearlyDistributedInt<0, MAX_SOURCE_INSTANCES>` | Index into Board.source_instances, not a SourceEffectKey or EntityIdentity. |
| `event` | `SourceEvent` | The original core event being resolved. |
| `resolved` | `Bool` | This candidate has already been processed; it cannot be selected a second time. |

## SourceUseRecord

Source: [source_effect_types.rl](../src/source_effect_types.rl).

Owned by Board.source_uses. Commitment finds the explicit rule/owner/scope/
subject key; interval changes reset the relevant count. Phase/turn/round stamps
here are raw serial values, not the history serial+1 convention.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `rule` | `SourceRuleCode` | Rule whose usage is counted; compatible explicit keys can intentionally share a limit. |
| `owner` | `Bool` | Player whose army/unit/model use is being charged. |
| `scope` | `SourceUseScope` | army, unit or model, determining the subject key. |
| `subject` | `EntityIdentity` | Zero for army scope, current containing-unit identity for unit scope, bearer identity for model scope. |
| `phase_stamp` | `LinearlyDistributedInt<0, MAX_PHASE_STAMP>` | Raw phase serial associated with phase_uses. |
| `turn_stamp` | `LinearlyDistributedInt<0, MAX_TURN_STAMP>` | Raw turn serial associated with turn_uses. |
| `round_stamp` | `LinearlyDistributedInt<0, MAX_ROUNDS>` | Raw round index associated with round_uses. |
| `phase_uses` | `FixedStat` | Committed uses in the stamped phase. |
| `turn_uses` | `FixedStat` | Committed uses in the stamped turn. |
| `round_uses` | `FixedStat` | Committed uses in the stamped round. |
| `battle_uses` | `FixedStat` | Committed battle-long uses; phase/turn changes do not reset them. |

## SourceEffect

Source: [source_effect_types.rl](../src/source_effect_types.rl).

Owned by Board.source_effects. Recipient models carry the actual typed grants
keyed to this effect. Refresh/expiry can remove one effect without erasing a
second source's matching bonus. The payload itself is not duplicated in this
record. Raw serial stamps locate the interval in which it began.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `identity` | `SourceEffectKey` | Unique owned-effect key, not an entity/model identity. |
| `source` | `LinearlyDistributedInt<0, MAX_SOURCE_INSTANCES>` | Index of the registered conferring source; source-slot reuse waits while an effect still references it. |
| `target_unit` | `EntityIdentity` | Stable recipient unit identity for unit-scoped effect maintenance. |
| `unit_scope` | `Bool` | Whether refreshed unit membership determines the recipient set. |
| `recipients` | `CheckedVector<EntityIdentity, MAX_UNIT_MODELS>` | Stable model identities carrying this effect; includes the appropriate lifecycle/archived recipients for cleanup. |
| `duration` | `SourceDuration` | Actual phase/turn/round/next-own-boundary/battle expiry policy. |
| `requires_live_source` | `Bool` | Remove when the source can no longer confer the rule, subject to its explicit retained-source timing. |
| `owner` | `Bool` | Player used to interpret next-own-turn/phase boundaries. |
| `phase_stamp` | `LinearlyDistributedInt<0, MAX_PHASE_STAMP>` | Raw phase serial when installed, used for phase-duration expiry. |
| `turn_stamp` | `LinearlyDistributedInt<0, MAX_TURN_STAMP>` | Raw turn serial when installed, used for turn and next-turn expiry. |
| `round_stamp` | `LinearlyDistributedInt<0, MAX_ROUNDS>` | Raw round index when installed, used for round expiry. |

## Printed profiles, weapons and Stat

Sources: [stats.rl](../src/stats.rl) and [weapons.rl](../src/weapons.rl).
These catalogs describe printed data. A stored `Profile`/`Weapon` value selects
an entry; the attributes below are **computed catalog accessors**, not mutable
per-miniature fields. Factory equipment choices select entries and populate
the model's slot/provenance arrays.

| Profile accessor | Result type | Meaning |
| --- | --- | --- |
| `movement()` | `Int` | Printed M in inches; zero represents an unmodifiable M- source |
| `thoughness()` | `Int` | Printed T; use effective/attached-unit queries for an actual attack |
| `save()` | `Int` | Printed Sv threshold, e.g. 3 means 3+ |
| `invuln_save()` | `Int` | Printed InSv threshold; values above 6 are legacy no-save sentinels |
| `feel_no_pain()` | `Int` | Profile FNP threshold/sentinel; actual wound-loss prevention also checks current grants and scope |
| `wounds()` | `Int` | Printed maximum W; subtract the model's suffered_wounds for remaining wounds |
| `leadership()` | `Int` | Printed Ld threshold, before applicable modifiers |
| `control()` | `Int` | Printed OC, before effective characteristics and unit status |
| `base_size()` | `Float` | Source/default base diameter in millimetres; float is calculated/static catalog data, not a persisted model coordinate |

| Weapon accessor | Result type | Meaning |
| --- | --- | --- |
| `range()` | `Int` | Printed inches; zero is Melee, not a zero-inch ranged weapon |
| `attacks()` | `Stat` | Printed A expression; random A is generated per selected weapon at gathering |
| `skill()` | `Int` | Printed BS/WS threshold; range determines which characteristic applies |
| `strenght()` | `Int` | Printed S before group-effective strength |
| `penetration()` | `Int` | Signed AP; improving -1 by 1 produces -2 |
| `damage()` | `Stat` | Printed D expression; random D is determined per damaging attack after recipient allocation |
| `rules()` | `WeaponRules` | Printed weapon rules; selected/granted/target-conditioned rules require the effective selection pipeline |

`Stat` has three alternatives: `FixedStat`, `Dice`, and `CompoundDice`.
`raw_stat(N)` constructs a fixed value; `dice_stat(3)`/`dice_stat(6)` describe
one D3/D6; `compound_stat(count, sides, constant)` describes supported compound
expressions. A D3 still receives its result through the bounded die input,
with the actual expression limiting the accepted faces. Never infer a random
expression's value from the default storage of its alternative.

| CompoundDice field | Type | Meaning and lifecycle |
| --- | --- | --- |
| `count` | `LinearlyDistributedInt<1, 4>` | Number of dice, 1–3, supplied at construction |
| `d3` | `Bool` | true uses three-sided results; false uses six-sided results |
| `constant` | `FixedStat` | Intrinsic +N part of the characteristic; it is not an extra modifier and is not rerolled |

`WeaponRule` is either printed metadata or a source-owned granted rule:

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `source_effect` | `SourceEffectKey` | Owner of a granted rule; zero denotes intrinsic/manual metadata |
| `parameter_increment_source` | `SourceEffectKey` | Separate owner of a temporary increase to an existing rule's magnitude |
| `parameter_increment_amount` | `FixedStat` | Increment to exclude again when that increasing source is no longer active |
| `kind` | `WeaponRuleKind` | Ability such as Blast, Lethal Hits or Sustained Hits |
| `parameter` | `LinearlyDistributedInt<0, MAX_CHARACTERISTIC>` | Rule magnitude where relevant; presence-only rules need no positive magnitude |
| `target_condition` | `KeywordPredicate` | Target keyword restriction where supplied |

`KeywordPredicate` combines ALL, ANY and NONE groups. It stores
`required_count`, `alternative_count` and `excluded_count`, each a
`LinearlyDistributedInt<0, KEYWORD_TERM_BOUND>`, and a fixed
`keywords: LinearlyDistributedInt<0, 128>[MAX_KEYWORD_TERMS]` array. The counts
identify contiguous groups of keyword codes; the combined capacity is nine
terms, not nine independent terms per clause. Empty groups impose no extra
condition. A family/profile code is an exact named selector, not string
comparison against a display name.

## Modifier and source payload companions

These small records explain the nested values in the complete tables above.
See [modifiers.rl](../src/modifiers.rl) and
[source_effect_types.rl](../src/source_effect_types.rl).

| Record/property | Type | Meaning |
| --- | --- | --- |
| `RuleModifier.operation` | `ModifierOperation` | replace, multiply, add, divide, subtract, in that application order |
| `RuleModifier.amount` | `LinearlyDistributedInt<0, MAX_RULE_MODIFIER>` | Magnitude 0–4096; not a signed field |
| `RuleModifier.negative` | `Bool` | Sign of the operand; `signed_amount()` reconstructs it |
| `SourceUseLimits.phase` | `FixedStat` | Maximum uses in a phase; zero is unlimited in this interval |
| `SourceUseLimits.turn` | `FixedStat` | Maximum uses in a turn; zero is unlimited |
| `SourceUseLimits.round` | `FixedStat` | Maximum uses in a round; zero is unlimited |
| `SourceUseLimits.battle` | `FixedStat` | Maximum uses in the battle; zero is unlimited |
| `SourceWeaponGrant.rule` | `WeaponRule` | Granted weapon ability and any condition/parameter |
| `SourceWeaponGrant.weapon_scope` | `LinearlyDistributedInt<0, MAX_WEAPON_SCOPES>` | Zero is unrestricted by slot; a positive value identifies representative slot+1 |
| `SourceWeaponGrant.weapon_name` | `WeaponNameCode` | Optional named-family filter, zero means none |
| `SourceWeaponGrant.profile_name` | `WeaponProfileCode` | Optional named-profile filter, zero means none |
| `SourceWeaponGrant.physical_scope` | `Bool` | Extend the representative slot to linked profiles of that physical copy |
| `RiledUpGrant.enabled` | `Bool` | Installs the source-owned riled state when enabled; source keys preserve overlapping grants |
| `OrksEffectGrant.source_effect` | `SourceEffectKey` | Owner key of the installed faction effect; supports keyed expiry |
| `OrksEffectGrant.kind` | `OrksEffectKind` | Which current Orks effect the explicit consumer interprets |
| `OrksEffectGrant.amount` | `FixedStat` | That effect's magnitude where relevant; not a universal characteristic modifier |
| `OrksEffectGrant.associated_unit` | `EntityIdentity` | Related unit identity where that particular effect requires one |

All modifiers accumulate through the shared arithmetic policy. Round up after
the ordered operations, then enforce the characteristic's own limits. Roll
modifiers apply after rerolls; a WS/BS characteristic change and a hit-roll
modifier are different operations. Optional ignoring chooses individual
supported operations, rather than erasing every negative number wholesale.

`SourceGrant` is a typed alternative of `CharacteristicModifier`,
`IncomingAttackModifier`, `SourceWeaponGrant`, `AttackModifierPermission`,
`RiledUpGrant` or the current `OrksEffectGrant`. Source conditions and timing
do not make every payload faction-independent yet. The existing Orks adapters
still own unique effects and permissions.

## Shared procedure frames

Sources: [ability_procedures.rl](../src/ability_procedures.rl),
[healing_rules.rl](../src/healing_rules.rl) and [rules.rl](../src/rules.rl).
These are a procedure's saved progress, not additional tabletop entities.
Every frame also has the opaque generated `resume_index` described under Game.
Fields can be provisional until the frame is done. Do not set them to make an
unavailable input legal.

`ctx` in a source declaration means a borrowed caller-owned context. The Board
and Unit contexts of healing/return are supplied again when calling its input;
they are not copied into the frame. `frm` values are retained progress or
results. Shared completed frames are reusable storage, so copy a needed result
before a later operation can overwrite the same slot.

### GrantedMove

Stored in `Board.shared_actions.granted_move`. Normal reactions and Surge use
the same core Move; the source still supplies the actual trigger/permission.
The `reactive_move` factory supplies a normal granted move.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `source` | `UnitID` | Battlefield mover |
| `distance` | `StatModifier` | Supplied allowance in inches; not a newly calculated M characteristic |
| `kind` | `MovementKind` | Supported normal or surge mode |
| `objective_required` | `Bool` | This grant requires an objective-range endpoint |
| `permitted` | `Bool` | Caller-validated invocation permission; false finishes without offering movement |
| `previous_owner` | `Bool` | Decision owner restored on completion |
| `previous_kind` | `MovementKind` | Mode to restore; Surge deliberately leaves ordinary normal-mode state |
| `previous_limit` | `MovementOverride` | Prior absolute movement limit, using the +1 encoding |
| `previous_skies` | `Bool` | Prior flight-mode selection |
| `previous_target` | `UnitID` | Prior Surge-target context |
| `previous_objective` | `Bool` | Prior endpoint-restriction flag |
| `previous_mover` | `UnitID` | Prior constrained-mover context |
| `target` | `UnitID` | Chosen closest enemy for a Surge; not used by a Normal reaction |
| `completed` | `Bool` | Actual completed move, as opposed to declining/skipping; read after completion |

### UnitHealing

Stored in `Board.shared_actions.heal_unit`; contexts are the actual Board and
Unit in the selected bank. It accepts the complete bounded wound allowance,
heals wounded living models before returning eligible non-Character casualties,
and delegates any return to ModelReturn.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `bank` | `SourceBank` | Location of the real unit |
| `count` | `FixedStat` | Remaining wound allowance, decremented one wound at a time |
| `previous_owner` | `Bool` | Caller decision owner restored when healing ends |
| `available` | `Bool` | Current scan found a legally returnable casualty; provisional loop state |
| `casualty` | `ModelID` | Chosen archive index, not a live-model index |
| `target` | `UnitID` | Resolved battlefield slot where battlefield placement is required |

### ModelReturn

Stored in `Board.shared_actions.return_model`; contexts are the actual Board
and receiving Unit. Explicit Character-returning rules can call it directly;
ordinary healing's Character exclusion is enforced before that call. The source
chooses `phase_start` or `nearest_unengaged` placement and restored wound count.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `bank` | `SourceBank` | Receiving unit's real location |
| `source` | `UnitID` | Battlefield slot supplied explicitly, even for a retired unit that identity lookup skips |
| `archive` | `ModelID` | Original casualty's index in destroyed_models |
| `policy` | `ReturnPlacementPolicy` | Phase-start anchors or an explicitly permitted nearest-unengaged return |
| `restored_wounds` | `FixedStat` | Wounds to restore, bounded by the model's printed W through the reset calculation |
| `returned` | `Model` | Owning staged copy of the original casualty, including identity/equipment/use history |
| `placed` | `Bool` | Provisional capacity/placement feasibility; after completion indicates that restoration was committed |

On success, death-only flags are cleared, provenance is restored, the model is
appended, the original archive entry is erased and source effects are refreshed.
It is an original-model return, not creation of a fresh identity. Offboard
returns have no battlefield-position choice; embarked returns still require
actual carrier permission/capacity. Failure does not create another death-event
chain. The granting rule owns its own roll and expenditure.

### RerollableDice

Stored for common one-die rolls in `Board.current_roll`; it can also be returned
to a caller as its active child. A result remains a `Dice` wrapper in Godot:
read `frame.get_result().get_value()`.

| Property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `reroll` | `Bool` | Free full reroll permission supplied by the caller |
| `reroll_1s` | `Bool` | Free reroll permission restricted to an original 1 |
| `cp_rerollable` | `Bool` | Whether this type of roll may offer the CP reroll after target/cost checks |
| `current_player` | `Bool` | Controller of this roll's ordinary reroll decision; not necessarily the turn owner |
| `strat_target` | `UnitID` | Real friendly unit target for Command Re-roll where target_known is true |
| `target_known` | `Bool` | Targetless compatibility cannot invent a valid CP stratagem target |
| `original_decision_maker` | `Bool` | Caller role restored after the die/decision sequence |
| `result` | `Dice` | Current die result; replaced by the one permitted reroll |
| `is_non_cp_rerollable` | `Bool` | Original result qualifies for a supplied free reroll; the decision uses this captured fact |

## Other nested state encountered in the tables

These records have no separate scene representation. Their containing Unit or
Board owns their lifetime.

| Record/property | Type | Meaning and lifecycle |
| --- | --- | --- |
| `PhaseModifiers.greater_strenght_wound_protection` | `Bool` | Unit's current phase-scoped wound protection |
| `PhaseModifiers.charge_roll` | `RuleModifiers` | Current phase's charge-roll operations |
| `PhaseModifiers.smokescreen` | `Bool` | Current Smokescreen permission/effect, cleared with phase modifiers |
| `PhaseModifiers.counteroffensive` | `Bool` | Pending Counteroffensive effect consumed by the fight-order policy |
| `PhaseInfo.already_used_stratagems` | `AlreadyUsedStratagems[2]` | Each player's used cards in the phase; each list is a CheckedVector of at most 32 Stratagem entries |
| `OrksPsychicUsage.budget` | `RoundResourceBudget` | Shared level-based round expenditure for the unit's supported psychic abilities |
| `OrksPsychicUsage.roar_phase` | `PhaseStamp` | Last Roar use, with zero/serial+1 history convention |
| `OrksPsychicUsage.visions_phase` | `PhaseStamp` | Last Visions use under the same convention |
| `Objective.home` | `ObjectiveHome` | Explicit mission designation: none/army_0/army_1; not inferred from marker number |
| `Objective.position` | `BoardPosition` | Configured whole-inch marker position where custom_position is true |
| `Objective.custom_position` | `Bool` | Use the stored point instead of the legacy default marker point |
| `Objective.terrain_objective` | `Bool` | Objective range is linked to an agreed terrain area rather than the bare-marker test |
| `Objective.area_id` | `BInt<0, 16>` | Actual terrain-area index when terrain_objective is true; zero is a valid area |
| `Objective.controller` | `ObjectiveController` | Stored control at the relevant boundary, not a continuously recalculated display score |
| `Objective.secured_by` | `ObjectiveController` | Securing state retained according to the objective-control rules |

Sources: [units.rl](../src/units.rl), [board.rl](../src/board.rl) and
[types.rl](../src/factions/orks/types.rl). Use
`objective_range_definition`/`model_in_objective_range` for a query against the
configured/default marker or linked area. Reading a raw position alone omits
that policy. Both terrain collections use lower/upper `StoredTerrainPoint`
corners; terrain areas have exposed/light/dense flags, while movement geometry
has a blocks_movement flag. These are distinct uses of terrain data.

## Finding a property in Godot

A stored property `field_name` normally has a generated `get_field_name()`
getter. A bounded value/enum is usually another wrapper with `get_value()`;
an ID selector instead exposes its bounded `id` field. Growable native
collections are accessed through `library.size(collection)` and
`library.get(collection, index)`. Fixed-array getters may take an element index
or require a typed accessor; check their generated signature rather than assuming
the vector API applies to every array field.
The [engine guide](engine-guide.md) contains executable, checked examples.

Use this reference to understand state, then follow the linked source's actual
writer/query before changing a rule. A display-only field, an archived identity,
a current selector and an effective characteristic serve different purposes even
when they all ultimately contain small integers.

