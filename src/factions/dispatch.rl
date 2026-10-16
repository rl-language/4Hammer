# Core-facing composition boundary. Each hook comment specifies what core
# supplies, when it calls, what any implementation must return/change, and how
# no applicable contribution behaves. Particular army rules and their source
# citations belong in adapters, not in these interface contracts.
# Queries must be repeatable without mutation; contribution hooks change only
# their supplied output; commands execute at the documented gameplay boundary.
# Action-returning functions construct the real child with borrowed contexts,
# without another Board copy. Peer menus must not mutate shared state until an
# input is accepted, because both core and faction peers are initialized.
# A bounded selector still needs an existing slot in the right bank. Callers
# validate selectors before commands and retain borrowed contexts through child
# completion; predicates explicitly documenting validation can reject bad IDs.
# Composition must route by rule/source applicability, including cross-army
# recipients. Core must not identify a faction from a recipient to interpret
# private state, rule codes or named effect policy. Finite catalogs/frame types
# remain explicit; see README.md and the contract review for remaining coupling.
import factions.types
import factions.dispatch_combat
import factions.dispatch_movement
import factions.dispatch_permissions
import factions.dispatch_properties
import factions.dispatch_setup
import factions.dispatch_sources
