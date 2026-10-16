# Static composition boundary: core imports neutral domain hooks from here;
# dispatch modules select the concrete faction adapters. Catalog enums and
# typed frame storage may contain faction names without making core interpret
# their private rule codes. This is implementation infrastructure, not a rule.
# Action-returning hooks construct the actual child frame, with borrowed caller
# contexts; they add neither a wrapper frame nor a copied Board. See each
# domain header for query/mutation, selector-bank and result conventions.
# Queries can run repeatedly during valid-action discovery; commands run only
# at the named gameplay boundary. Peer-menu constructors are a stricter case:
# both peers are initialized, so neither may change shared state before input.
# Current dispatch is static: the adapter checks source metadata/applicability,
# rather than selecting an army from the recipient's owner alone.
# A bounded selector is not proof that its slot exists in the current bank.
# Except for predicates that explicitly validate selectors, callers supply
# in-range IDs and keep the borrowed contexts alive until the child completes.
import factions.types
import factions.dispatch_combat
import factions.dispatch_movement
import factions.dispatch_permissions
import factions.dispatch_properties
import factions.dispatch_setup
import factions.dispatch_sources
