extends SceneTree

# Faction-free callers exercise the generated contexts and payloads of the
# shared procedures (core pp9/33; appendix01.02.03/01.05.02/02.02.04).
func _initialize():
	call_deferred("check_procedures")

func position(x, y):
	var result = RLCBoardPosition.make()
	result.get_x().set_value(x)
	result.get_y().set_value(y)
	return result

func check_procedures():
	var library = root.get_node("GlobalRules").library
	assert(library.get_state_schema_version() == 42)
	assert(library.get_action_schema_version() == 26)
	var board = RLCBoard.make()
	board.set_current_decision_maker(true)
	var budget = RLCRoundResourceBudget.make()
	var roll = library.roll_spent_round_resource(board, budget, false, 1, true)
	assert(budget.get_spent().get_value() == 1)
	var die = RLCBIntT1T7T.make()
	die.set_value(1)
	library.roll(roll, board, die)
	assert(not board.get_current_decision_maker())
	library.keep_it(roll, board, false)
	die.set_value(6)
	library.reroll(roll, board, die)
	assert(library.is_done(roll) and roll.get_result().get_value() == 6)
	assert(budget.get_spent().get_value() == 1 and board.get_current_decision_maker())
	# Use a non-Orks unit without a source registration or faction ability.
	var draft = library.make_infernus_squad()
	while library.size(draft.get_models()) > 1:
		library.erase(draft.get_models(), library.size(draft.get_models()) - 1)
	library.assign(library.get(draft.get_models(), 0).get_position(), position(5, 5))
	library.append(board.get_units(), draft)
	library.identify_units(board)
	var unit = library.get(board.get_units(), 0)
	library.capture_starting_strength(unit)
	var source = RLCUnitID.make()
	for marker in range(4):
		library.set_objective_position(board, marker, position(30, 20))
	library.set_objective_position(board, 0, position(8, 5))
	var distance = RLCLinearlyDistributedIntT0T257T.make()
	distance.set_value(3)
	var move = library.reactive_move(board, source, distance, true)
	assert(not library.can_move_to(move, board, position(2, 5)))
	assert(library.can_move_to(move, board, position(8, 5)))
	library.move_to(move, board, position(8, 5))
	assert(library.is_done(move) and move.get_completed())
	assert(not board.get_move_requires_objective() and board.get_current_decision_maker())
	assert(unit.get_history().get_last_move_phase().get_value() == board.get_phase_serial().get_value() + 1)
	var model = library.get(unit.get_models(), 0)
	model.get_suffered_wounds().set_value(1)
	var amount = RLCLinearlyDistributedIntT0T257T.make()
	amount.set_value(1)
	var bank = RLCSourceBank.make()
	var heal = library.heal_unit(board, unit, bank, amount)
	var member = RLCModelID.make()
	assert(library.can_choose_healed_model(heal, board, unit, member))
	library.choose_healed_model(heal, board, unit, member)
	assert(library.is_done(heal) and model.get_suffered_wounds().get_value() == 0)
	var identity = model.get_identity().get_value()
	library.damage(unit, 0, library.wounds(model.get_profile()))
	var policy = RLCReturnPlacementPolicy.make()
	policy.set_value(1) # nearest_unengaged
	var returned = library.return_model(board, unit, bank, source, member, policy, 1)
	assert(library.can_place_returned_model(returned, board, unit, position(8, 5)))
	assert(not library.can_place_returned_model(returned, board, unit, position(7, 5)))
	library.place_returned_model(returned, board, unit, position(8, 5))
	assert(library.is_done(returned) and library.size(unit.get_models()) == 1)
	assert(library.get(unit.get_models(), 0).get_identity().get_value() == identity)
	assert(library.size(unit.get_destroyed_models().get_value()) == 0)
	assert(board.get_current_decision_maker())
	# Surly and ordinary healing now expose the same grid-position payload.
	var payload = RLCGamePlaceReturnedModel.make()
	assert(payload.members_count() == 1 and payload.get_member(0) is RLCBoardPosition)
	print("PASS: Godot schema exports, shared resource/reroll, constrained move, healing and original-model return without faction rules")
	library.free()
	quit(0)
