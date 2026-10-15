# Game state and property reference

Read the [engine guide](engine-guide.md) first for scope and the tabletop mental
model. This reference explains the properties you encounter when inspecting the
native game from Godot. Code names, including historical spellings such as
`battle_socked`, `starting_strenght` and `strenght`, are written exactly as they
appear in the bindings.

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

For exact aliases and capacities see [state_types.rl](../src/state_types.rl),
[units.rl](../src/units.rl) and [geometry.rl](../src/geometry.rl). Do not interpret
zero as 'unset' for every bounded field: source indices, positions and player
indices legitimately use zero.

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
| `phase_serial` | `PhaseSerial` | Engine phase counter advanced by phase entry; history stamps compare against it. |
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

