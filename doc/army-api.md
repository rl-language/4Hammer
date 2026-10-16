# Army API specification

Status: **approved architecture and naming, concrete interface specification;
runtime implementation and migration are pending**. This document defines the
APIs to implement. The current game still uses the
[dispatch modules](../src/factions/README.md). No declarations below are claimed
to be callable in the current library.

The six families are **Army catalog, Abilities, Passive effects, Available
abilities, Use ability, and Army state**. These names describe different jobs:
an entity has an ability, that ability can supply passive effects, and an
activated ability can become available and be used. A stratagem retains its
tabletop name and category while sharing activation/payment machinery.

The objective is a core that executes common game mechanics without
interpreting named faction rules. Shared catalog entries may name factions.
Use adequate bounded, explicit storage; reducing bounds or memory is not a
prerequisite. Preserve the current grid, circular geometry policy and generated
initialization/destruction. Do not optimize valid-action discovery.

## Game rules that determine the boundary

Use the [core reference](11th-edition-core-rules-procedural.txt) and
[supplied appendix](11th-edition-supplied-appendix.md), with original wording
taking precedence over editorial summaries.

| Rule requirement | Consequence for the API |
| --- | --- |
| Weapon/target selection precedes attack gathering; some conditions use target-selection facts (pp.16–19,79). | Keep declaration snapshots separate from current facts. Include the actual bearer, physical weapon, chosen profile and target in attack contexts. |
| Rerolls precede modifiers; modifiers retain operation order and ignore permissions (appendix01.05.02/02.02.01–02). | Return individual modifiers/permissions, not a final number or Boolean hit bonus. Dice attempts and final results have distinct boundaries. |
| Abilities trigger at particular steps, selections and completed events (pp.28–42/54–58). | Open precise windows; do not substitute phase start/end for selection or completion. |
| User-supplied sequencing gives the current player their simultaneous effects first, then the opponent. | Core groups choices by controller and keeps each selected effect atomic until it reaches a permitted interruption. |
| Attached models retain their own keywords and bearer-only rules; conferred abilities have source/component lifetime (pp.66–67). | Record the conferring entity, original recipient and grant scope separately. Retain required conferral through the attacking unit's attacks. |
| Persisting effects continue through transport/reserve transfers (appendix01.02.02–04). | Bank changes do not create a new recipient or reset effect duration/use. No external range or visibility is measured from offboard units. |
| Destruction/removal can be deferred, including Fight on Death and transport passengers (pp.65/80/87; supplied Fight on Death). | Separate wound loss, destruction, pending removal and completed removal. Core owns their order and common damage work. |
| A previously eligible target can become ineligible (appendix04.03.03). | Preserve declared facts but revalidate where required; offer replacement targets for unresolved effects without replaying resolved attacks. |
| Upgrades/options have original recipients; revival and replacement have different identity rules (pp.66–67/88 and supplied muster rules). | Keep selected-option provenance. Revived models keep identity/equipment/use; replacements use explicit identity remapping. |

These requirements define reusable mechanisms. They do not grant an ability to
an army unless its supplied rules say it has that ability.

## Ownership and types

The signatures below are **interface notation**, not executable Rulebook
examples. An implementation uses ordinary `fun`/`act` declarations, typed
contexts and static composition; Rulebook does not need a runtime interface,
callback registry or another scripting language.

`ReadContext` provides access to the real game state and already resolved facts.
It is a read-only contract; current Rulebook reference semantics do not by
themselves enforce constness. Tests must establish that repeated queries leave
state unchanged. Action contexts borrow the real Board; no child owns a copied
Board. All retained values use enums, Bool, bounded integers and typed bounded
collections. Transient calculations may use floats.

| Type | Required meaning |
| --- | --- |
| `AbilityId` | Globally unique finite definition ID. Core treats army-specific values as identities, not instructions. Current unqualified local numeric rule codes need explicit translation. |
| `AbilityInstanceId` | Stable identity of a particular conferring army/unit/model/item/option instance. Reconciliation must not recreate it or reset its use. |
| `EntityRef` | Tagged army, original component, unit or model reference using stable identities; never an unqualified mutable bank index. |
| `AbilityDescription` | Definition ID/category, implementing provider, controller policy, conferring entity, original component, scope, source requirements, timing and usage specification. |
| `GrantScope` | Bearer, original component, combined unit or army. Recipient scope is separate from what keeps the conferring source active. |
| `SelectedEnhancement` | Shared catalog ID, original recipient identity and bearer/component scope. Scope distinguishes a bearer option from a unit Upgrade without checking its faction in core. |
| `GameEvent` | A uniquely identified committed fact, its cause, actor/affected identities and the snapshots needed by its triggers. Repeated polling does not create another event. |
| `WindowContext` | Exact decision boundary, parent operation, triggering event if any, phase/turn roles and immutable relevant snapshots. |
| `AvailableAbility` | Instance ID, window/event ID, required controller, optional/compulsory status and acceptance context. This is not a use record or payment. |
| `AbilityUse` | One selected activation, its committed-cost status, typed progress, chosen identities and pending operation/result. Core owns its activation identity. |
| `EffectBundle` | Independently sourced standard grants sharing recipient policy and explicit lifetime. Each installed bundle has an effect identity; equal grants from different bundles remain independent. |
| `EffectTermId` | Finite identity of one grant/modifier within its continuous ability or installed bundle. Distinguishes intentional separate terms from accidentally evaluating the same term twice. |

Core registers/reconciles descriptions and assigns instance identities. The
registration identity includes the definition and actual conferring entity;
display labels and equal effect values do not identify the same ability.
Core may recycle arena slots only with generation checks for pending references.

Composition selects the implementing provider by definition/instance, not by
the recipient's faction. A rule from one army can affect another army. Core
stratagems can use the same ability protocol through the core provider.

## 1. Army catalog

The army provides selectable content and construction data. Core supplies the
muster sequence and common validation. Proposed entry points:

```text
get_army_catalog(faction) -> ArmyCatalog
get_unit_choices(catalog, roster) -> UnitChoices
get_equipment_choices(catalog, unit_draft) -> EquipmentChoices
get_detachment_choices(catalog, army_configuration) -> DetachmentChoices
get_enhancement_choices(catalog, roster, recipient) -> EnhancementChoices
get_attachment_choices(catalog, joining_unit, roster) -> AttachmentChoices
make_unit(catalog, unit_selection, owner) -> Unit
```

Choice queries are pure and return actual catalog IDs/constraints. A unit
selection records composition and physical equipment, including alternative
profiles and nonattacking items. `make_unit` constructs complete model data;
core assigns runtime identities before abilities are registered.

Core enforces shared copy counts, Character/Epic Hero and option limits,
Warlord requirements and attachment roles. Catalog-specific recipient/loadout
requirements are supplied by the army. An accepted enhancement records its
original recipient, which is not replaced with the current combined unit ID.

Current user policy permits at most three detachments and excludes army points
and detachment-price calculations. Battle CP costs remain fully represented.
Missing catalog/provider support rejects the unsupported selection explicitly;
an empty implementation must not silently certify an incomplete army.

## 2. Abilities

```text
get_abilities(read_context, entity, output_descriptions)
```

Enumerate the abilities actually conferred by the supplied entity's printed
data, equipment, selected options or army configuration. This is a pure
description query. Core scans entities across all banks and reconciles the
result with registered instances; the army does not implement separate reserve
and passenger registration paths.

Every description specifies whether its conferring entity is a particular
bearer, an original component or the army. It also distinguishes bearer-only
effects from effects conferred to a combined attached unit. Requirements such
as having started attached and remaining a live/retained source are explicit
policy interpreted by common lifecycle code.

Continuous effects and activated lasting effects have different policies.
A continuous grant can depend on its source remaining active. An accepted
lasting effect persists independently until its stated expiry unless its rule
explicitly requires a continuing source. Neither bank transfer nor model death
automatically implies both kinds end.

No ability is inferred from a display name or faction keyword.
Legacy/direct test fixtures must explicitly supply their ability metadata.

## 3. Passive effects

There is one typed overload per mechanical domain, rather than one Boolean
callback per named rule:

```text
get_passive_effects(read_context, ability_instance, model_context, output)
get_passive_effects(read_context, ability_instance, unit_context, output)
get_passive_effects(read_context, ability_instance, movement_context, output)
get_passive_effects(read_context, ability_instance, attack_context, output)
get_passive_effects(read_context, ability_instance, allocation_context, output)
get_passive_effects(read_context, ability_instance, roll_context, output)
get_passive_effects(read_context, ability_instance, objective_context, output)
get_passive_effects(read_context, ability_instance, stratagem_context, output)
```

| Context | Essential inputs | Permitted output |
| --- | --- | --- |
| Model/unit | Actual model/component, intrinsic data, current retained/live membership and established grants | Characteristic modifiers, scoped keyword/standard ability grants and removals, save permissions |
| Movement | Actor, selected kind, ordinary/reactive/prebattle mode, selection snapshot and relevant target | Distance/roll modifiers, independent permissions, traversal/setup policy |
| Attack | Attacker, actual bearer, physical weapon/profile, target, step, shooting mode, declaration snapshots and current facts | Weapon-rule instances, characteristic/roll modifiers, reroll/ignore permissions, cover and targeting policy |
| Allocation | Actual recipient model, incoming attack, damage cause and current allocation context | Save/prevention permissions and recipient-specific incoming modifiers |
| Roll | Roll kind, roller/subject, identified dice/attempts, reroll state and current raw/final-unmodified stage | Roll modifiers, reroll/ignore permissions and eligibility for explicit replacement choices |
| Objective | Queried objective identity, scoring player, contributing model/unit and current cargo/control facts | Scoped OC contributions and objective permissions for that marker |
| Stratagem | Card, payer, source/target, selected mode and use context | Cost modifiers, access and separately identified target restrictions/permissions |

All outputs carry the originating instance/effect identity. No applicable
effect appends nothing. The output starts with earlier contributions; preserve
them. Reapplying an appender to the same output is not an idempotent query.
No query pays, rolls, registers effects or changes the Board.

Each term has one evaluation path. An installed standard grant must not also
be emitted as the same extra passive term by its provider. Preserve the parent
instance/effect identity and term identity so duplicate production can be
detected within one query. Identical terms from different instances/effects
remain separate; this does not replace the game's duplicate-ability selection.

Core evaluates the resulting common mechanics: modifier order/caps, duplicate
weapon-rule selection, per-die ignore choices, save priority and final legality.
Save grants establish a usable save before arithmetic; they are not just a
modifier to a missing save. Weapon rule parameters remain explicit.

Permissions name the restriction they waive. Permission to charge after Advance
does not waive a distinct prohibition on charging. Engaged-target shooting and
escape-hazard bypass are separate permissions. No general `allowed = true`
result bypasses all core conditions, and no invented universal conflict policy
replaces a specific rule's precedence.

Contexts distinguish frozen facts from live facts. Read dependencies are
ordered: intrinsic/established state, model properties, unit aggregation, then
action/attack-specific evaluation. An implementation must not recursively
request the same effective property it is currently defining. A needed cyclic
dependency must be diagnosed and given an explicit supported interpretation.

## 4. Available abilities

```text
get_available_abilities(read_context, window, controller, output)
ability_available(read_context, available_ability) -> Bool
```

Core opens named mechanical windows: phase/step boundaries, unit selection,
movement-kind selection, declaration completion, attack target/group steps,
roll boundaries, completed movement/setup, Battle-shock and destruction/removal.
Committed events describe what happened; windows describe where an ability can
intervene. An effect cannot rewrite an already committed fact by pretending it
ran at an earlier boundary.

The first query lists available activations for this window/controller. The
second revalidates one before acceptance. Both are pure. A returned activation
must have a legal resolution path; a mandatory ability with no eligible target
must follow its actual no-target rule rather than strand the game.

The ability instance, event/window identity and captured conditions distinguish
one trigger from repeated polling. Core owns pending/resolved/declined status.
Trigger-time qualification must not be silently replaced with use-time checks:
the description identifies what remains live and what was already established.
Invalidated targets receive the core's required replacement-target handling;
already resolved effects are not replayed.

Core gives the current player's simultaneous effects their chosen order, then
the opponent's. Optional effects may be declined; unresolved compulsory work
blocks completion. Turn owner, controller, payer, subject and chance owner are
explicit. Source ownership alone does not decide all of them.

General reroll windows distinguish a rolled attempt, reroll decision, final
unmodified result and modified result. A rerolled die is another roll attempt
but not another permission to reroll the same die. Command Re-roll's stated
single-die/full-charge exception remains a core rule.

## 5. Use ability

```text
start_ability(board, available_ability) -> AbilityUse
use_ability(board, army_state, ability_use, last_operation_result)
    -> UseAbilityStep frame
```

`start_ability` is a core acceptance operation: revalidate the selected window/
instance, allocate its activation identity and reject invalid acceptance without
payment or gameplay mutation. It does not universally pay immediately; the
compiled ability action commits its required costs at the rule's acceptance
point. Common cost/use services make that commit atomic and prevent paying
again on rerolls or later stages. Declining before commitment spends nothing;
cancellation after commitment follows the rule and does not imply a refund.

`use_ability` is an interactive Rulebook action selected through static
composition. It performs the army's target choices, ability-specific dice and
control flow. It may change its own typed progress/private army data and request
common operations. Battlefield state changes use core services; an adapter does
not copy the movement/damage/attack engines.

Each completed step returns either:

- **Finished**, with its accepted/declined/cancelled outcome; or
- **Operation requested**, with a typed core operation and retained continuation.

Core completes the requested operation, then calls the next step with its typed
result (`NoOperationResult` for the initial step). Requests/results carry the
activation identity and step identity so a stale result cannot advance another
use or apply an operation twice. Required target choices can occur before or
after a test as the actual ability specifies. Core must not impose one fixed target/pay/roll order on every
ability. Querying availability does not construct these interactive children.

The continuation retains choices and stage in explicit typed state. It does not
retain another Board or recursively enter an already active shared action frame.
The ordinary step frame completes before reuse. Unhandled definition IDs are
rejected explicitly; they must not silently consume an activation as a no-op.

### Core operations available to abilities

| Operation | Core responsibility/result |
| --- | --- |
| Grant effects | Install an `EffectBundle` with separate grant instances, stable recipients and one explicit lifetime; return its identity |
| Change resource / commit cost | Apply authorized CP/resource changes and required use accounting atomically |
| Move / set up / charge | Execute ordinary paths, distance, placement, coherency and selection restrictions; return completion and resulting identities |
| Embark / disembark | Check permissions/capacity and perform the real bank transfer with persistent identity/effects |
| Attack | Execute declarations, grouping, hit/wound/save/damage and restrictions; return completed attack facts |
| Inflict damage | Execute allocation, prevention and destruction with damage kind and attack/psychic/source provenance |
| Destroy | Apply direct destruction without treating it as preventable wound damage, then use common destruction timing |
| Heal / return model | Restore the permitted living member/original casualty with identity, physical equipment and use history; report placement/capacity outcome |
| Create replacement | Construct a new unit from its permitted template with fresh identities and explicit remapping |
| Adjust pending roll/results | Apply authorized replacements, rerolls or cancellations to the identified unresolved result, preserving already committed facts |
| Adjust pending destruction | Supply mechanically named demise/removal directives and additional common damage jobs |

These are typed requests to common procedures, not bytecode or a second rule
language. Named conditions and branching stay in compiled army actions.
Results distinguish completed, declined, ineligible and failed placement where
those outcomes are meaningful; a valid slot index is never used as a Boolean.

An interrupting reaction must finish before its suspended parent proceeds when
the game requires that order. Core retains the parent's typed operation progress
and resumes it after the child result. After-attack reactions can use the existing
flat runner; genuine mid-operation interruptions need explicit continuations.
Deferring every reaction until attack/phase end would violate the contract.
Scheduling is core-owned and must pass the shared-frame non-re-entry audit.

## 6. Army state

```text
make_army_state(army_configuration) -> ArmyState
validate_army_state(read_context, army_state) -> Bool
remap_army_state(army_state, entity_remap)
```

Use shared effect, selected-option, resource and usage records for common state.
Genuine additional army state has a composition-owned finite tagged type whose
fields remain visible to generated serialization/ML layout. An army with no
additional state uses an empty alternative. Core passes it to its provider and
does not inspect that army's private values. No strings, opaque byte storage or
custom `init`/`drop` are introduced.

`make_army_state` is an ordinary construction function using generated field
lifecycle. Validation is pure and accepts valid retained history even when an
ability cannot currently activate. `entity_remap` distinguishes a newly created
replacement from ordinary transfer/revival and supplies old/new component/model
identities. Never replace all provenance with the current combined unit ID.
Apply replacement remapping to the new copy's metadata; it must not retarget
the original unit's active effects, historical references or spent-use records.

Core owns effect expiry, source-activity refresh, returning-member inheritance,
bank transfer, generic usage periods and common identity remapping. Additional
army lifecycle behavior uses these services and the normal available/use-ability
protocol where it is an actual game effect.

## Migration from the current implementation

This specification replaces army-specific policy channels with common mechanics;
it does not require renaming every existing shared primitive.

1. Implement shared identities, typed contexts, contribution packets, effect
   bundles and activation/result state. Reuse existing modifier, weapon-rule,
   source/effect, damage-job and reaction-request primitives where their
   semantics match. Add source-independent contract tests.
2. Implement catalog/ability descriptions and core reconciliation. Move Model's
   eight named fields into abilities, nonattacking equipment, shared selected
   options and effect data; generalize captured component conferral metadata.
3. Implement passive-effect overloads and change core consumers. Retire fixed
   Sustained Hits1/Boolean+1 channels, split bundled engagement permissions,
   consolidate selected-move permissions and pass the queried objective to OC.
4. Implement precise windows and available/use-ability handling, with common
   cost/use services and multiple scoped effects per activation. Introduce
   continuation support before enabling any genuinely interrupting nested rule.
5. Migrate Orks actions, then extract legacy factions' remaining behavior from
   core. Remove superseded hooks only after their consumers are migrated and
   covered; do not keep forwarding layers as the finished abstraction.
6. Rebuild matching bindings/schemas, validate native semantics and sanitizer/
   replay/fuzzer behavior, and broaden boundary audits to every army provider.

Each concern belongs in a focused commit. Existing public Godot inputs should
retain compatibility where possible; necessary action/layout changes require
explicit schema updates and matching generated clients. No rendered integration
or valid-action-discovery optimization is added to this work.

## Acceptance checks for the implemented API

- A small independent test army implements all six families using shared core
  mechanics; it is a test fixture, not invented official faction data.
- Passive/availability queries can be repeated without changing state; invalid
  acceptance/payment is atomic and no nonterminal mandatory window stalls.
- Opposing armies' effects apply through their real source/provider, including
  cross-army targets and different payer/controller/subject roles.
- Overlapping equal grants expire independently. Offboard transfers preserve
  duration/use without granting external measurement or visibility.
- Component/bearer loss, retained conferral, Fight on Death, revival and new
  replacements follow distinct lifecycle and identity contracts.
- Target/selection snapshots stay frozen where required; live targeting can
  change and unresolved effects can select replacements when permitted.
- Two-objective cargo OC, separate engagement permissions, modifier provenance,
  physical-weapon profiles and multi-die rerolls have native regressions.
- Required interruptions finish before parent continuation, without recursively
  entering a live shared frame. Operation results survive shared-frame reuse.
- Core functions/actions contain no named faction-condition/effect branches;
  negative controls prove the broadened audit detects such dependencies.

The [roadmap](../ROADMAP.md) tracks implementation separately from this completed
specification. Current dispatch contracts and older runtime validation remain
descriptions/evidence for the existing implementation until migration occurs.
