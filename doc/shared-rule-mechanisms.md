# Shared mechanisms behind faction rules

The faction boundary separates rule ownership from execution. A datasheet or
faction adapter decides **when a rule applies**, who can choose it, its CP/use
cost and its targets. Shared modules implement the reusable state changes and
procedures. Start with the [composition map](../src/factions/README.md) and
[architecture guide](rulebook-architecture.md).

## Ownership map

| Shared module | Responsibility | What the faction still supplies |
| --- | --- | --- |
| [source_effects.rl](../src/source_effects.rl) | Source registration identity, reusable unit-grant prototypes, committed effect keys, expiry, bank/archive membership, temporary-grant cleanup | Rule ID, label, payload, recipient, duration, live/retained-source and offboard policy |
| [rule_effect_types.rl](../src/rule_effect_types.rl), [rule_effects.rl](../src/rule_effects.rl) | Finite typed effect storage, active model/unit lookup, common permission and save consumers | Which effects an ability grants and any named effect-specific interpretation |
| [attack_result_types.rl](../src/attack_result_types.rl), [attack_results.rl](../src/attack_results.rl) | Activation serial, stable-target hits, actual wounds lost, destruction and optional tagged hit counts | Tag contributions and reaction eligibility |
| [attack_reactions.rl](../src/attack_reactions.rl) | Flat execution of requested attacks using the single shared Attack frame | A `ReactionAttackRequest`, paid/accepted by the faction action |
| [replacement_rules.rl](../src/replacement_rules.rl), [board.rl](../src/board.rl) | Fresh identities, battle-start replacement templates, original-component remapping, reset histories and safe slot reuse | Replacement trigger/destination, private-data reset, registration and pending-return policy |
| [muster_rules.rl](../src/muster_rules.rl) | Warlord selection, three/six-copy limits, enhancement counts and general recipient/attachment exclusions | Faction keyword/enabling, catalog eligibility, Battleline overrides and actual option effects |
| [transport_rules.rl](../src/transport_rules.rl) | Keyword/datasheet passenger requirements, capacity and grouped seat calculation, whole-unit embark range | Required/excluded metadata, seat divisor, allowed timing and range |
| [weapons.rl](../src/weapons.rl) | Catalog properties for nonattacking equipment and simultaneous profiles | The literal property of each source weapon |

## Effect grants and provenance

`RuleEffectGrant` has a bounded kind and amount, its owning `SourceEffectKey`
and an optional associated stable unit identity. `Model.rule_effects` is a
bounded collection. The catalog can include named faction effects; putting a
kind in this shared enum does not make that faction's rule part of core. Only
common kinds have common consumers. The source-boundary audit rejects named
faction-effect interpretation in core functions/actions.

Shared consumers currently cover Fights First, Mobile, Deep Strike, charge/
action/flight prohibition and a parameterized granted invulnerable save. Other
entries, including Da Button, engine selection, borrowed Orks abilities and
Grot Shields, remain interpreted by Orks adapters.

A granted invulnerable save establishes a permission, including when the
printed profile has none. Choose the better printed/faction base or granted
save, then apply the ordinary characteristic-modifier pipeline. A worse grant
cannot overwrite a better save. A grant amount must be between2 and6; this
representation is separate from an arithmetic modifier to an existing save.

Reusing a source prototype does not merge its committed effects. Each committed
effect receives a distinct key, so removing one overlapping grant leaves the
others intact. `commit_reusable_unit_grant` deliberately uses rule/source-unit/
owner identity; `source_instance_registered` instead includes source-model and
trigger. These different identity policies must not be silently collapsed.
The caller explicitly sets offboard, retained-source and live-source policy.

Temporary cleanup removes positive-key grants while retaining intrinsic zero-key
arithmetic/equipment entries. New replacements use battle-start templates;
ordinary model return uses the existing healing/return procedure and retains
model identity and physical-weapon usage.

## Attack results and reaction requests

`AttackResultRecord` describes one actual target in one attack activation.
Successful hits, wounds actually lost after prevention, destruction and tagged
hits are distinct facts. Tagged counts cannot exceed total hits. The shared
ledger treats tag slots uniformly; the current catalog has one Squig Launcha
tag supplied by Orks. Extending that finite catalog requires a layout audit.

`ReactionAttackRequest` contains availability, source/target selectors, melee/
Overwatch mode and whether declaration is restricted to that target. It is a
request after eligibility, player decisions and payment have resolved. Core
executes it, then asks for the next reaction. It does not retain recursive
Attack frames. The caller's target constraint is restored afterward. Changing
this graph requires the shared-frame audit to establish non-re-entry.

## Construction and transport data

The shared Warlord action takes an explicit faction keyword and an enabling
flag. Its Character and required/prohibited-model rules work independently of
Orks. Existing legacy armies are not automatically enabled or certified by this
extraction; their adapters still need current metadata.

Enhancement counting uses a finite39-entry catalog envelope, four distinct
counted choices and up to three copies of an Upgrade. The adapter reads its
actual model option storage; the shared counter owns unique-count arithmetic.
General Character/Epic Hero checks are shared; source-card requirements remain
with the adapter. Prices and detachment costs remain outside the user's scope.

Passenger metadata distinguishes ALL required keywords from the existing ANY
permission list and excluded keywords. Named datasheet exclusions are explicit
bounded codes. Every passenger model must pass these tests before capacity can
authorize embarkation. Unknown carrier permissions remain unavailable.

`transport_space_divisor` is1 for ordinary seats or2 for grouped half-seats.
Half-seats are summed and rounded up once per passenger unit; ordinary members
retain their full seat weights. Orks Gretchin constructors select divisor2.
Keep It Runnin supplies its six-inch whole-unit embark range to the shared
range check; its Fight timing remains with the Orks ability.

## Compilation and compatibility

No custom `init`/`drop`, callback registry, opaque storage or new Python rule-test
runner is involved. Persistent numbers remain bounded; effects, counters and
requests remain visible to generated bindings and ML inference.

Keep low-level types free of action-graph imports. An attempted order imported shared effect behavior from `units.rl` and the
reaction runner ahead of the established composition imports; the compiler
crashed in action dependency resolution. Keeping effect behavior reachable
through composition and importing the reaction runner afterward resolves that
combined dependency problem. Types import their data dependencies.

State/observation and action compatibility are versioned separately. See the
latest [ROADMAP](../ROADMAP.md) completion entry for executed checks and exact
versions; older saves must not be parsed with stale field layouts. Another
sourced faction with colliding local rule IDs still needs qualified source/use
identities before those rules can be enabled.
