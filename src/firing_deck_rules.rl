import transport_rules
import attack_declarations

# Finite supported temporary selection capacity; not a tabletop restriction.
# Printed per-carrier X remains independently enforced (24.14 p.81).
cls DeckSelection:
    EntityIdentity carrier
    EntityIdentity passenger_model
using DeckSelections = CheckedVector<DeckSelection, MAX_DECK_SELECTIONS>

# Each actual carrier model uses its own X, and each passenger model is
# selected at most once; its unit must not have selected to shoot (p.81).
fun deck_passenger_valid(Board board, UnitID source, ModelID carrier, UnitID passenger, ModelID model, DeckSelections selected) -> Bool:
    if source.get() >= board.units.size() or carrier.get() >= board[source].models.size() or passenger.get() >= board.embarked_units.size() or model.get() >= board.embarked_units[passenger.get()].models.size():
        return false
    ref carrier_model = board[source][carrier]
    ref passenger_unit = board.embarked_units[passenger.get()]
    if carrier_model.firing_deck.value == 0 or !carrier_model.is_alive() or passenger_unit.embarked_transport != carrier_model.identity or passenger_unit.history.shot_this_phase or !passenger_unit[model].is_alive():
        return false
    let used = 0
    for selected_index in range(selected.size()):
        if selected[selected_index].passenger_model == passenger_unit[model].identity:
            return false
        if selected[selected_index].carrier == carrier_model.identity:
            used = used + 1
    return used < carrier_model.firing_deck.value and selected.has_capacity()

# ONE SHOT weapons are excluded before granting; own passenger restrictions
# are not transferred to the transport (24.14 p.81). Carrier shooting mode and
# pistol/normal weapon exclusivity still apply (pp.34–35/80).
fun deck_weapon_valid(Board board, UnitID source, ModelID carrier, UnitID passenger, ModelID model, Int slot, DeclaredWeapons declarations) -> Bool:
    if slot < 0 or slot >= board.embarked_units[passenger.get()][model].weapons.size():
        return false
    ref passenger_model = board.embarked_units[passenger.get()][model]
    ref weapon = passenger_model.weapons[slot].profile
    if weapon.range() <= 0 or model_weapon_has_rule(passenger_model, slot, WeaponRuleKind::one_shot) or passenger_model.used_once_per_battle_weapon[slot]:
        return false
    let pistol = close_quarters_weapon(weapon)
    if board[source].shooting_kind == ShootingKind::assault:
        let borrowed = make_deck_declaration(board, source, carrier, passenger, model, slot)
        if !declared_weapon_has_kind(borrowed, WeaponRuleKind::assault):
            return false
    if !monster_vehicle_model(board[source][carrier]):
        if board[source].shooting_kind == ShootingKind::close_quarters and !pistol:
            return false
        for declaration_index in range(declarations.size()):
            if declarations[declaration_index].model_identity == board[source][carrier].identity and close_quarters_weapon(declarations[declaration_index].weapon) != pistol:
                return false
    return true

# Grant only the selected weapon/profile's rules, plus the carrier's own
# granted weapon rules; passenger-unit abilities do not become carrier abilities
# merely because it borrows a weapon (24.14 p.81; ability presence p.78).
fun make_deck_declaration(Board board, UnitID source, ModelID carrier, UnitID passenger, ModelID model, Int slot) -> DeclaredWeapon:
    let result : DeclaredWeapon
    result.model = carrier
    result.borrowed_weapon = true
    result.model_identity = board[source][carrier].identity
    result.weapon_owner = board.embarked_units[passenger.get()][model].identity
    result.physical_group = weapon_primary_id(board.embarked_units[passenger.get()][model], slot)
    result.slot = slot
    result.weapon = board.embarked_units[passenger.get()][model].weapons[slot].profile
    result.weapon_name = board.embarked_units[passenger.get()][model].weapons[slot].profile.family_id()
    result.profile_name = board.embarked_units[passenger.get()][model].weapons[slot].profile.value
    result.hunter_condition = board.embarked_units[passenger.get()][model].hunter_profile_conditions[slot]
    let intrinsic = result.weapon.rules()
    for intrinsic_index in range(intrinsic.size()):
        result.selected_rules.append(intrinsic[intrinsic_index])
    for granted_index in range(board.embarked_units[passenger.get()][model].additional_weapon_rules[slot].size()):
        result.selected_rules.append(board.embarked_units[passenger.get()][model].additional_weapon_rules[slot][granted_index])
    append_faction_intrinsic_weapon_rules(board[source][carrier], result.weapon, result.selected_rules)
    append_faction_package_weapon_rules(board, source, carrier.get(), result.weapon, result.weapon_name, result.selected_rules)
    append_faction_datasheet_weapon_rules(board, source, result.weapon, result.selected_rules)
    let own_rules = board[source].get_temporary_weapon_rules()
    for own_index in range(own_rules.size()):
        result.selected_rules.append(own_rules[own_index])
    result.current_target_rules = result.selected_rules
    return result

# All units in that carrier become unable to shoot for the rest of this turn,
# including unselected passengers and after disembarking/repositioning (p.81).
fun lock_deck_passengers(Board board, EntityIdentity carrier):
    for locked_unit in range(board.embarked_units.size()):
        if board.embarked_units[locked_unit].embarked_transport == carrier:
            board.embarked_units[locked_unit].history.deck_shooting_locked = true
            board.embarked_units[locked_unit].can_shoot = false

# Imported rules make a carrier eligible for Assault/close-quarters/indirect
# modes too; actual profile choices still undergo the mode checks (p.81).
fun carrier_has_ranged_rule(Board board, UnitID source, WeaponRuleKind kind) -> Bool:
    let found = false
    for bearer in range(board[source].models.size()):
        if board[source][bearer].is_alive():
            for slot in range(board[source][bearer].weapons.size()):
                found = found or board[source][bearer].weapons[slot].profile.range() > 0 and available_weapon_has_rule(board, source, bearer, slot, kind)
    for carrier_index in range(board[source].models.size()):
        if board[source][carrier_index].firing_deck.value > 0:
            for bank_unit in range(board.embarked_units.size()):
                if board.embarked_units[bank_unit].embarked_transport == board[source][carrier_index].identity and !board.embarked_units[bank_unit].history.shot_this_phase:
                    for bank_model in range(board.embarked_units[bank_unit].models.size()):
                        for weapon_slot in range(board.embarked_units[bank_unit][bank_model].weapons.size()):
                            if board.embarked_units[bank_unit][bank_model].weapons[weapon_slot].profile.range() > 0 and !model_weapon_has_rule(board.embarked_units[bank_unit][bank_model], weapon_slot, WeaponRuleKind::one_shot):
                                let carrier : ModelID
                                carrier = carrier_index
                                let passenger : UnitID
                                passenger = bank_unit
                                let model : ModelID
                                model = bank_model
                                let borrowed = make_deck_declaration(board, source, carrier, passenger, model, weapon_slot)
                                found = found or declared_weapon_has_kind(borrowed, kind)
    return found

# Firing Deck runs only in own Shooting, never Snap or melee (24.14 p.81).
# Temporary declarations disappear at activation end; physical weapon slots
# and passenger One Shot history are never overwritten.
act select_firing_deck(ctx Board board, ctx DeclaredWeapons declarations, frm UnitID deck_source) -> SelectFiringDeck:
    frm selected : DeckSelections
    frm carrier_index : ModelIterator
    while carrier_index.value < board[deck_source].models.size():
        frm deck_carrier : ModelID
        deck_carrier = carrier_index.value
        if board[deck_source][deck_carrier].firing_deck.value > 0 and carrier_has_passengers(board, board[deck_source][deck_carrier].identity):
            lock_deck_passengers(board, board[deck_source][deck_carrier].identity)
            frm done = false
            while !done:
                actions:
                    act finish_firing_deck()
                        done = true
                    act select_firing_deck_passenger(frm UnitID deck_passenger) {deck_passenger.get() < board.embarked_units.size(), board.embarked_units[deck_passenger.get()].embarked_transport == board[deck_source][deck_carrier].identity, !board.embarked_units[deck_passenger.get()].history.shot_this_phase}
                        board.selected_passenger_bank = deck_passenger
                        actions:
                            act cancel_deck_passenger()
                            act select_firing_deck_model(frm ModelID deck_model) {deck_passenger_valid(board, deck_source, deck_carrier, deck_passenger, deck_model, selected)}
                                board.selected_passenger_model = deck_model
                                actions:
                                    act cancel_deck_model()
                                    act select_firing_deck_weapon(frm BInt<0, MAX_WEAPONS> deck_weapon) {deck_weapon_valid(board, deck_source, deck_carrier, deck_passenger, deck_model, deck_weapon.value, declarations)}
                                        frm granted_weapon = make_deck_declaration(board, deck_source, deck_carrier, deck_passenger, deck_model, deck_weapon.value)
                                        board.shared_actions.choose_weapon_abilities = choose_weapon_abilities(board, granted_weapon.selected_rules)
                                        subaction*(board) board.shared_actions.choose_weapon_abilities
                                        frm deck_abilities_chosen_snapshot_1 = board.shared_actions.choose_weapon_abilities.chosen
                                        granted_weapon.selected_rules = deck_abilities_chosen_snapshot_1
                                        granted_weapon.current_target_rules = deck_abilities_chosen_snapshot_1
                                        declarations.append(granted_weapon)
                                        let chosen : DeckSelection
                                        chosen.carrier = board[deck_source][deck_carrier].identity
                                        chosen.passenger_model = board.embarked_units[deck_passenger.get()][deck_model].identity
                                        selected.append(chosen)
        carrier_index = carrier_index + 1
