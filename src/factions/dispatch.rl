# Static composition boundary: core imports neutral domain hooks from here;
# dispatch modules select the concrete faction adapters. Catalog enums and
# typed frame storage may contain faction names without making core interpret
# their private rule codes. This is implementation infrastructure, not a rule.
# Action-returning hooks construct the actual child frame, with borrowed caller
# contexts; they add neither a wrapper frame nor a copied Board. See each
# domain header for query/mutation, selector-bank and result conventions.
import factions.types
import factions.dispatch_combat
import factions.dispatch_movement
import factions.dispatch_permissions
import factions.dispatch_properties
import factions.dispatch_setup
import factions.dispatch_sources
