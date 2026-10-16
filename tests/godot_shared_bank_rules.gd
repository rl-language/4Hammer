extends SceneTree

func _initialize():
	call_deferred("check_banks")

func panel_for(rules, library, action):
	var wrapped = RLCAnyGameAction.make()
	library.assign(wrapped, action)
	rules.valid_actions = [wrapped]
	var panel = VBoxContainer.new()
	panel.set_script(load("res://MultipleChoises.gd"))
	var buttons = VBoxContainer.new()
	buttons.name = "ChoiseList"
	panel.add_child(buttons)
	root.add_child(panel)
	assert(buttons.get_child_count() == 1)
	return panel

func check_banks():
	var rules = root.get_node("GlobalRules")
	var library = rules.library
	assert(library.get_state_schema_version() == 43)
	assert(library.get_action_schema_version() == 26)
	for bank_index in [1, 2]:
		var board = RLCBoard.make()
		library.append(board.get_units(), library.make_orks_warboss())
		library.append(board.get_units(), library.make_orks_trukk(0, false, library.orks_trukk_extra_choice(0)))
		library.identify_units(board)
		var source = RLCUnitID.make()
		if bank_index == 1:
			assert(library.reposition_unit(board, source))
		else:
			var carrier = library.get(library.get(board.get_units(), 1).get_models(), 0)
			library.transfer_embarked_unit(board, source, carrier.get_identity())
		var bank = RLCSourceBank.make()
		bank.set_value(bank_index)
		var unit = library.source_bank_unit(board, bank, 0)
		var original = library.wounds_left(library.get(unit.get_models(), 0))
		var count = RLCLinearlyDistributedIntT0T4097T.make()
		count.set_value(1)
		var mortal = library.resolve_mortal_wounds(board, bank, source, source, false, count)
		assert(board.get_damage_bank().get_value() == bank_index)
		library.assign(rules.state.get_board(), board)
		var panel = panel_for(rules, library, RLCGameSelectMortalModel.make())
		assert("allocate offboard model 1" in panel.get_node("ChoiseList").get_child(0).text)
		panel.free()
		var model = RLCModelID.make()
		assert(library.can_select_mortal_model(mortal, board, model))
		library.select_mortal_model(mortal, board, model)
		assert(library.is_done(mortal))
		assert(library.wounds_left(library.get(unit.get_models(), 0)) == original - 1)
		assert(board.get_damage_bank().get_value() == 0)
		# Bank context makes the SAME damage payload a button rather than a
		# battlefield model click. No separate offboard-mortal action exists.
		var click = Sprite2D.new()
		click.set_script(load("res://InteractionManager.gd"))
		click.models = Node.new()
		root.add_child(click)
		click.on_state_change()
		assert(click.current_select_model_action == null)
		click.models.free()
		click.free()
	var action = RLCGameChooseDestructionBank.make()
	action.get_member(0).set_value(1)
	var bank_panel = panel_for(rules, library, action)
	assert("resolve destruction in reserves" in bank_panel.get_node("ChoiseList").get_child(0).text)
	bank_panel.free()
	print("PASS: Godot schema exports, shared reserve/passenger mortals, bank restoration, allocation labels and click suppression")
	library.free()
	quit(0)
