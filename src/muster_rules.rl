import board

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun warlord_unit_base_valid(Board board, Bool player, UnitID unit, Keyword faction_keyword) -> Bool:
    return unit.get() >= 0 and unit.get() < board.reserve_units.size() and board.reserve_units[unit.get()].owned_by_player1 == player and board.reserve_units[unit.get()].has_keyword(faction_keyword) and board.reserve_units[unit.get()].has_keyword(Keyword::character)

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun warlord_model_base_valid(Unit unit, Int model) -> Bool:
    return model >= 0 and model < unit.models.size() and unit[model].is_alive() and unit[model].has_keyword(Keyword::character) and !unit[model].cannot_be_warlord

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun warlord_model_required(Unit unit, Int model) -> Bool:
    return warlord_model_base_valid(unit, model) and (unit.must_supply_warlord or unit[model].must_be_warlord)

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun has_required_warlord(Board board, Bool player, Keyword faction_keyword) -> Bool:
    let required = false
    let unit : UnitID
    for index in range(board.reserve_units.size()):
        unit = index
        if !warlord_unit_base_valid(board, player, unit, faction_keyword):
            continue
        for model in range(board.reserve_units[index].models.size()):
            required = required or warlord_model_required(board.reserve_units[index], model)
    return required

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun warlord_model_valid(Board board, Bool player, UnitID unit, ModelID model, Keyword faction_keyword) -> Bool:
    if board.armies[int(player)].warlord.value != 0 or !warlord_unit_base_valid(board, player, unit, faction_keyword) or !warlord_model_base_valid(board.reserve_units[unit.get()], model.get()):
        return false
    ref roster_unit = board.reserve_units[unit.get()]
    let required_model = false
    for index in range(roster_unit.models.size()):
        required_model = required_model or (warlord_model_base_valid(roster_unit, index) and roster_unit[index].must_be_warlord)
    if required_model and !roster_unit[model.get()].must_be_warlord:
        return false
    return !has_required_warlord(board, player, faction_keyword) or warlord_model_required(roster_unit, model.get())

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun warlord_unit_valid(Board board, Bool player, UnitID unit, Keyword faction_keyword) -> Bool:
    if !warlord_unit_base_valid(board, player, unit, faction_keyword):
        return false
    let selectable = false
    let model : ModelID
    for index in range(board.reserve_units[unit.get()].models.size()):
        model = index
        selectable = selectable or warlord_model_valid(board, player, unit, model, faction_keyword)
    return selectable

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
fun has_warlord_choice(Board board, Bool player, Keyword faction_keyword) -> Bool:
    let selectable = false
    let unit : UnitID
    for index in range(board.reserve_units.size()):
        unit = index
        selectable = selectable or warlord_unit_valid(board, player, unit, faction_keyword)
    return selectable

# Shared Warlord selection follows the supplied Character/faction and
# required/prohibited-model precedence rules (core Select Army/user definition).
act select_warlord(ctx Board board, frm Bool player, frm Keyword faction_keyword, frm Bool enabled) -> SelectWarlord:
    if !enabled or !has_warlord_choice(board, player, faction_keyword):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_unit = board.selected_warlord_unit
    board.current_decision_maker = player
    act choose_warlord_unit(frm UnitID warlord_unit) {warlord_unit_valid(board, player, warlord_unit, faction_keyword)}
    board.selected_warlord_unit = warlord_unit
    act choose_warlord_model(frm ModelID warlord_model) {warlord_model_valid(board, player, warlord_unit, warlord_model, faction_keyword)}
    ref selected = board.reserve_units[warlord_unit.get()][warlord_model]
    board.armies[int(player)].warlord = selected.identity
    if !selected.has_keyword(Keyword::warlord):
        selected.keywords.append(Keyword::warlord)
    board.selected_warlord_unit = previous_unit
    board.current_decision_maker = previous_owner

# General user roster limits:3 copies,6 for effective Battleline. Unknown
# legacy datasheet IDs remain unclassified; no price calculation is introduced.
fun muster_copies_valid(Board board) -> Bool:
    for slot in range(board.reserve_units.size()):
        ref unit = board.reserve_units[slot]
        if unit.models.empty():
            continue
        let code = unit[0].datasheet.value
        if code == 0:
            continue
        let copies = 0
        for other in range(board.reserve_units.size()):
            ref candidate = board.reserve_units[other]
            if !candidate.models.empty() and candidate.owned_by_player1 == unit.owned_by_player1 and candidate[0].datasheet.value == code:
                copies = copies + 1
        if copies > muster_copy_limit(unit, faction_force_battleline(board, unit)):
            return false
    return true

# The user-supplied3/6 rule is independent of the faction granting Battleline.
fun muster_copy_limit(Unit unit, Bool battleline_override) -> Int:
    return 3 + 3 * int(unit.has_keyword(Keyword::battleline) or battleline_override)

# Finite bookkeeping for general enhancement selection:4 distinct selections,
# ordinary enhancements unique, Upgrades up to3 copies (user supplied rules).
# Adapter reads its storage; this counter handles duplication/count arithmetic.
cls EnhancementSelectionCounter:
    Bool[39] counted
    FixedStat total
    FixedStat copies

    # Record each catalog entry once even when an Upgrade is on every model.
    fun record_choice(Int choice):
        assert(choice > 0 and choice < 39, "enhancement choice outside catalog capacity")
        if !self.counted[choice]:
            self.counted[choice] = true
            self.total = self.total + 1

    # Copies count per original unit, not per recipient model (Select Army).
    fun record_unit_copy(Bool present):
        self.copies = self.copies.value + int(present)

    # Second/third identical Upgrades do not consume another counted slot.
    fun permits(Int choice, Bool upgrade) -> Bool:
        return choice > 0 and choice < 39 and (self.counted[choice] or self.total < 4) and self.copies.value < (1 + 2 * int(upgrade))

# General recipient restrictions from the user's enhancement definition.
# Card-specific permissions and existing choices are checked by the adapter.
fun enhancement_recipient_valid(Unit unit, Model model, Bool upgrade) -> Bool:
    return !unit.has_keyword(Keyword::epic_hero) and model.is_alive() and (upgrade or model.has_keyword(Keyword::character))

# Joining original roster units cannot bypass the user's Epic Hero exclusion.
fun enhancement_attachment_valid(Unit leader, Unit bodyguard, Bool has_options) -> Bool:
    return !has_options or (!leader.has_keyword(Keyword::epic_hero) and !bodyguard.has_keyword(Keyword::epic_hero))
