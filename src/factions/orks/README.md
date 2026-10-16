# Orks rule modules

All54 included Orks datasheets use one [datasheets.rl](datasheets.rl) module.
Runtime mechanics are organized by responsibility, independent of the order
in which cards were implemented. Read the [datasheet guide](../../../doc/factions/orks/orks-datasheets.md)
and [faction documentation index](../../../doc/factions/orks/README.md).

| Module | Responsibility |
| --- | --- |
| `datasheets.rl` | Every current model/unit factory, equipment choice, composition validator and printed attachment permission list |
| `army.rl` | Waaagh!, riled-up, War Cry, Da Boss and live army-rule queries |
| `roster.rl` | Custom/starter roster data, detachment choices, Orks inputs to shared Warlord/copy rules and roster labels |
| `detachments.rl` | Selected-package and named unit-group predicates |
| `enhancements.rl` | Enhancement/Upgrade metadata, selection, recipients and attachment restrictions |
| `stratagems.rl` | Support-card eligibility, timing choices and CP-cost adapters; combat/movement effects live in their own domains |
| `queries.rl` | Extracted bearer/army/permission properties and finite catalog exceptions; core accesses these through neutral composition |
| `types.rl` | Orks enums, records and stable source rule codes |
| `effects.rl` | Orks payload/label/lifetime policy; shared effect lookup, installation and cleanup live in core |
| `sources.rl` | One datasheet registration path, source lifecycle/availability adapters and timing-source dispatch |
| `combat.rl` | Attack selection, modifiers, live support, tagged-hit contributions and post-attack policy |
| `movement.rl` | Move/charge permissions, reactions, redeployment and formations |
| `recovery.rl` | Repair/healing/revival eligibility and source-specific decisions |
| `transports.rl` | Cargo effects and embark/disembark eligibility/reactions; shared transport code owns seat accounting |
| `psychic.rl` | Psyker eligibility, shared spending/testing and psychic abilities |
| `morale.rl` | Mobbed, Runtherd, Breakin' Heads and other Battle-shock reactions |

Use `import factions.orks.army` and the existing `-i src` include root; the
public game entrypoint remains `src/full_game.rl`. Exported `orks_*` functions
and `Orks*` types remain faction-qualified because modules are not declaration
namespaces. Do not add categories named after implementation batches.

`make_orks_model` initializes common Orks model metadata. Each concrete factory
adds its actual printed keywords/equipment. `finalize_orks_unit` configures
attachment permissions and captures starting strength after composition is
complete; it serves single- and multi-model units. Shared `equip_weapon` installs actual catalog profiles, a bounded reference to
an earlier primary slot for alternates and an optional Hunter condition.
Allowed per-unit lists contain actual Weapon values; there are no separate
Orks equipment-choice or named-weapon/profile enums.

Use the shared `make_source_usage`/`source_use_limits` helpers for use
specifications; identities, scope and interval limits are explicit. Only
`commit_source_usage` spends a use. Shared movement, damage, source effects,
healing and model return remain in common modules. No custom init/drop is used.

The engine is jointly compiled: core phases call the
[neutral composition layer](../README.md), which selects these adapters. Shared
state still contains explicit faction catalog/storage types. This folder is not a
standalone library. State/observation46 protects renamed internal frame fields;
public action payload compatibility is checked separately. Source display names
are hidden enum values; the UI derives text only when presenting a choice.


General grant, attack-result, reaction execution, replacement, muster and
transport mechanisms are documented in [the shared guide](../../../doc/shared-rule-mechanisms.md).
Do not add parallel faction implementations of those engines. This adapter
supplies Orks status choices, tagged hits, metadata and eligibility; common
status kinds and data lifetimes are owned by the shared modules.
