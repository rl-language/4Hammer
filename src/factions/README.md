# Faction behavior boundary

Core functions and actions use the neutral contracts in
[dispatch.rl](dispatch.rl). These composition modules select the concrete
adapters; the current adapters live under [orks/](orks/README.md). Shared
Weapon, Keyword, datasheet and other enums may contain Orks entries. This
boundary separates behavioral ownership, not catalog storage or independent
binary libraries.

| Module | Contract responsibility |
| --- | --- |
| [dispatch_properties.rl](dispatch_properties.rl) | Model keywords/abilities, characteristic contributions, intrinsic weapon rules and component army-rule metadata |
| [dispatch_combat.rl](dispatch_combat.rl) | Selection/target/hit/destruction hooks, modifiers, defensive permissions and faction combat choices |
| [dispatch_movement.rl](dispatch_movement.rl) | Source movement events, mode/Advance choices, traversal, charge contributions, passenger permissions/costs, arrival and completed-move reactions |
| [dispatch_sources.rl](dispatch_sources.rl) | Source registration/availability, typed faction grant lifecycle, validation, timing-source resolution and faction timing choices |
| [dispatch_permissions.rl](dispatch_permissions.rl) | Action, detection, stratagem, attachment and other source-specific eligibility queries |
| [dispatch_setup.rl](dispatch_setup.rl) | Existing roster menu, selected detachments/options/Warlord, formations and setup policy |
| [types.rl](types.rl) | Explicit bounded extension progress used by neutral action controllers |

## Calling a hook

Queries must not spend CP, consume a use or register an effect merely because
Godot enumerates a legal input. Modifier appenders contribute to the provided
result without replacing other sources. Commands and action constructors are
called at the actual gameplay boundary, with stable source/model identities and
the original Board/bank contexts. Faction code may invoke the existing common
movement, damage, healing and source primitives; it must not copy those engines.

Routing follows the actual rule context, not just the target owner's selected
army. The current static composition calls the Orks adapter whose existing
metadata/permissions establish applicability. It also supports direct datasheet
fixtures whose Board army has not been selected. An Orks rule can therefore
apply to a recipient in another army without guessing that recipient's faction.
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
again. This keeps a Bomb Squig roll or selected Advance atomic while allowing
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
state/observation45, action27 and next-state bound46. Use the source boundary
audit and frame-storage audit;
[ROADMAP.md](../../ROADMAP.md) records executed validation and current schemas.
