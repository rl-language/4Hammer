# Faction behavior boundary

The [passive/triggered ability specification](../../doc/army-api.md) defines the
replacement mechanism. Existing selection actions/constructors remain in charge
of armies and equipment; no catalog, discovery or army-state provider layer is
introduced. The dispatch modules below remain the current runtime implementation
until their consumers are migrated.

Core functions and actions use the neutral contracts in
[dispatch.rl](dispatch.rl). These composition modules select the concrete
adapters; the current adapters live under [orks/](orks/README.md). Shared
Weapon, Keyword, datasheet and other enums may contain Orks entries. This
boundary separates behavioral ownership, not catalog storage or independent
binary libraries.

The comments above dispatch hooks specify the **core-facing contract for any
implementation**: call boundary, supplied context, required result/mutation,
neutral result and sequencing obligations. They must stand without knowledge of
the current faction's datasheets. Named rule eligibility, effects and tabletop
citations belong above the implementing adapter functions. A forwarding body
selects an implementation; its current behavior is not the definition of the
interface. The [contract review](../../doc/faction-contract-review.md) records
remaining interfaces that still restrict what another faction can express.

| Module | Contract responsibility |
| --- | --- |
| [dispatch_properties.rl](dispatch_properties.rl) | Model keywords/abilities, characteristic contributions, intrinsic weapon rules and component army-rule metadata |
| [dispatch_combat.rl](dispatch_combat.rl) | Selection/target/hit/destruction hooks, modifiers, defensive permissions and faction combat choices |
| [dispatch_movement.rl](dispatch_movement.rl) | Source movement events, mode/Advance choices, traversal, charge contributions, prebattle formations/redeploy, cargo choices/OC, arrival/reactions and replacement metadata |
| [dispatch_sources.rl](dispatch_sources.rl) | Source registration/availability, typed faction grant lifecycle, validation, timing-source resolution and faction timing choices |
| [dispatch_permissions.rl](dispatch_permissions.rl) | Action, detection, stratagem, attachment and other source-specific eligibility queries |
| [dispatch_setup.rl](dispatch_setup.rl) | Existing roster menu, selected detachments/options/Warlord and muster/attachment policy |
| [types.rl](types.rl) | Explicit bounded extension progress used by neutral action controllers |

## Calling a hook

Queries must not spend CP, consume a use or register an effect merely because
Godot enumerates a legal input. Modifier appenders contribute to the provided
result without erasing other sources; weapon-rule appenders can also increment
existing numeric instances while preserving their provenance. These are
cumulative operations: applying them twice to the same result can duplicate a
contribution. Commands and action constructors are called at the actual gameplay
boundary, with stable source/model identities and
the original Board/bank contexts. Faction code may invoke the existing common
movement, damage, healing and source primitives; it must not copy those engines.

The comments over each hook define its timing, output and mutation contract.
In particular, a permission may waive one restriction, while a veto's `true`
only permits further validation. Neither establishes complete legality. A bounded
`UnitID` still needs an existing slot in the correct bank; it is not a persistent
identity. Predicates may reject invalid selectors, but action constructors that
immediately read a pending event require the caller to validate it first.

Read result fields after completion and before reusing their frame. The `started`
routing flag is deliberately read earlier, after forwarding one input, to choose
which peer to finish. Check each result's guard: `reaction.available` before its
actor/target fields,
`crash_mortals > 0` before using the death-reaction recipient, and a selected,
completed special-move peer before using `kind`/`extra`. A zero source-effect key
means no scoped effect to remove; an interceptor unit index of zero is valid and
its absence sentinel is `-1`. Never infer these meanings from integer truthiness.

Routing follows the actual rule context, not just the target owner's selected
army. Each implementation must check the source metadata/permissions that
establish applicability, including direct datasheet fixtures whose Board army
has not been selected. A rule can affect a recipient in another army without
guessing that recipient's faction. The current static composition selects one
installed adapter; that implementation choice is not a portable interface type.
There is no dynamic name lookup, callback pointer or universal rule interpreter.
Before adding another faction with overlapping local source rule numbers,
qualify the source/use identity and implement its composition policy explicitly.

Timing flags passed as contexts use the typed `CoreTimingProgress` record;
fixed arrays remain fields inside that record, avoiding raw array-pointer ABI
assumptions in generated host methods.

Properties without a Board use the actual Model/Unit data and installed grants.
For keyword overrides, a transient integer means negative: remove; zero: retain
ordinary keyword membership; positive: grant. Stored state remains bounded,
Bool or enum. Generic arithmetic and its limits remain in core.

## Selecting an action alternative

Core owns the simultaneous controller groups and mandatory finish gates. A
faction owns its actual ability inputs, target eligibility, rolls and effects.
The timing, charge, phase and move-kind menus initialize a common child and a
faction child, then forward one step from either:

```text
frm core_choice = core_timing_choice(...)
frm faction_choice = faction_timing_choice(...)
subaction(board, core_progress, progress, pending) core_choice, faction_choice
if core_choice.started:
    subaction*(board, core_progress, progress, pending) core_choice
else:
    subaction*(board, core_progress, progress, pending) faction_choice
```

A peer-menu constructor may initialize its private frame before the first
input, but must not spend resources, install rules or otherwise mutate Board
before one of its inputs is selected. Both children are constructed even when
the player chooses only one of them.

Each child sets its bounded Bool `started` immediately after accepting its
first input. The selected child then completes before siblings are offered
again. This keeps an ability's roll/target sequence or selected Advance atomic while allowing
the player to order complete core/faction effects freely. Construct children
before the single-step alternative; a constructor placed inside an `actions:`
branch does not expose that child's initial inputs.

The ordinary forwarding functions return existing typed faction frames. They
do not add wrapper action frames or own another Board copy. Contexts are passed
back to the same parent-owned values, including pending-event queues. Private
frame types and progress storage remain explicit for save/ML layout inference.
Keep one active copy of every shared procedure, copy results before reuse and
check the action graph for nested re-entry after changing the call tree.

Public input names/payloads remain the Godot contract. Moving a private action
body or changing saved frame layout requires matching generated bindings and a
state schema update. Reordered action tags also require a matching action schema,
even when input field shapes are preserved. The current versions are
state/observation46, action27 and next-state bound47. Use the source boundary
audit and frame-storage audit;
[ROADMAP.md](../../ROADMAP.md) records executed validation and current schemas.


## Shared mechanisms beneath the boundary

Use [the shared-mechanism guide](../../doc/shared-rule-mechanisms.md) before
adding another hook. Generic source reuse/cleanup, status grants and common
permission consumers, attack-result bookkeeping, flat reaction execution,
replacement construction, Warlord/roster restrictions and passenger metadata
belong in common modules. Keep actual faction triggers, catalog conditions,
CP/use decisions and named rule tables in adapters. The post-attack hook returns
a `ReactionAttackRequest`; core executes it. Shared typed statuses retain source
keys across every bank and archive. Only shared mechanical meanings may be
interpreted by core; named faction meanings remain adapter policy.
