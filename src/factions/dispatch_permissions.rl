import factions.orks.detachments
import factions.orks.queries
import factions.orks.stratagems


# Read-only legality contributions. Veto filters return true to defer to core;
# additional permission queries return false when they grant no exception.
# Neither result establishes complete legality. Core retains phase, payment,
# usage and geometry checks. player denotes the supplied controller/payer,
# which may differ from Board.current_player. See README.md for conventions.

# Return whether core may consider unit Hidden. False vetoes Hidden; true
# leaves terrain/obscuration requirements to model_is_hidden. This does not
# grant visibility to an offboard unit or change any stored status.
fun faction_hidden_allowed(Board board, Unit unit) -> Bool:
    return orks_hidden_allowed(board, unit)

# Return signed inches added to detection range against target, or zero.
# Positive increases detection distance; negative reduces it. Core combines
# the contribution with its base and applies the shared detection limits.
# This is not a replacement range or a visibility decision.
fun faction_detection_modifier(Board board, Unit target) -> Int:
    return orks_detection_modifier(board, target)

# Return whether player has access to strat through their army selection.
# Return true for cards outside this composition filter's restrictions.
# Core separately checks timing, targets, CP and usage; merely enumerating
# this query must not select a card, pay or consume its use.
fun faction_stratagem_selected(Board board, Bool player, Stratagem strat) -> Bool:
    return orks_stratagem_selected(board, player, strat)

# Veto target-specific restrictions for strat and player: false rejects the
# target, true leaves common target/payment/shock checks in force. target may
# be a live unit, an offboard unit or retained destroyed-unit metadata according
# to the card's common target policy; do not assume a battlefield slot.
fun faction_stratagem_target_allowed(Board board, Bool player, Stratagem strat, Unit target) -> Bool:
    return orks_stratagem_target_allowed(board, player, strat, target)

# Validate the payer/recipient ownership relationship required by strat.
# Return true where no additional ownership restriction applies. Core handles
# recipient presence, shock and usage separately; this query must not assume
# that player is the turn owner or that every stratagem targets a friendly unit.
fun faction_stratagem_owner_allowed(Stratagem strat, Unit target, Bool player) -> Bool:
    return orks_stratagem_owner_allowed(strat, target, player)

# Validate model's extension metadata against its recorded original component
# in unit during attachment/save integrity checks. Core has checked ordinary
# component membership. Return true for models without additional constraints;
# this is not permission to form a new attachment or a repair command.
fun faction_attachment_origin_valid(Unit unit, Model model) -> Bool:
    return orks_attachment_origin_valid(unit, model)

# Return the absolute nonnegative CP cost of card for unit, starting from
# card.cost() when unchanged. Zero is a valid free cost, not a sentinel.
# Core uses this query for both affordability and payment; it must not spend,
# refund or consume use. Shared phase/target limits still apply to free uses.
fun faction_datasheet_stratagem_cost(Stratagem card, Unit unit) -> Int:
    return orks_datasheet_stratagem_cost(card, unit)

# Return a whole-unit grant of kind. Both Unit.has_ability and all_have_ability
# short-circuit to true on this result, so check all source/scope/lifetime
# conditions here; one bearer having a private ability is insufficient.
# Return false to continue common aggregation; do not mutate individual models.
fun faction_unit_grants_ability(Unit unit, AbilityKind kind) -> Bool:
    return orks_unit_grants_ability(unit, kind)

# Return an exception to the engagement gate for starting the common action.
# False grants nothing; true does not bypass shock, OC, movement/shooting or
# once-per-turn requirements, all of which core still validates independently.
fun faction_action_while_engaged(Unit unit) -> Bool:
    return orks_action_while_engaged(unit)
