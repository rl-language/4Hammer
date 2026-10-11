extends SceneTree

func _initialize():
	call_deferred("check_bindings")

func deployment_buttons(panel):
	var buttons = []
	for child in panel.get_node("ChoiseList").get_children():
		if not child.is_queued_for_deletion() and child.text.begins_with("deploy "):
			buttons.append(child)
	return buttons

func check_bindings():
	var rules = root.get_node("GlobalRules")
	var choices = VBoxContainer.new()
	choices.set_script(load("res://MultipleChoises.gd"))
	var list = VBoxContainer.new()
	list.name = "ChoiseList"
	choices.add_child(list)
	root.add_child(choices)
	var interaction = Sprite2D.new()
	interaction.set_script(load("res://InteractionManager.gd"))
	interaction.models = Node.new()
	interaction.add_child(interaction.models)
	root.add_child(interaction)
	assert(rules.library.get_state_schema_version() == 5)
	assert(rules.library.get_action_schema_version() == 3)
	assert(rules.library.get_observation_schema_version() == 5)
	assert(rules.valid_actions.size() == 6)
	var choose = RLCGamePickInsidiousInfiltrators.make()
	rules.apply_action(choose)
	assert(rules.valid_actions.size() == 6)
	rules.apply_action(RLCGamePickStrikeForceOctavious.make())
	rules.apply_action(RLCGameDoneAttaching.make())
	var target = rules.get_current_target_action()
	assert(target != null)
	assert(target.get_member(0) is RLCUnitID)
	assert(target.get_member(1) is RLCUnitID)
	var snapshot = rules.as_indented_str(rules.state)
	rules.reset()
	var restored = rules.library.play()
	assert(rules.library.set_state(restored, RLCLib.godot_string_to_rlc_string(snapshot)))
	rules.set_state(restored)
	assert(rules.get_current_target_action() != null)
	rules.apply_action(RLCGameDoneAttaching.make())
	var select = rules.get_current_select_unit_action()
	assert(select != null and select.get_member(0) is RLCUnitID)
	var first_buttons = deployment_buttons(choices)
	assert(first_buttons.size() == 5)
	assert(first_buttons[0].text.begins_with("deploy army 1:"))
	first_buttons[0].button_down.emit()
	var location = rules.get_location_saction()
	assert(location != null and location.get_member(0) is RLCBoardPosition)
	var before_placement = rules.as_indented_str(rules.state)
	location.get_member(0).get_x().set_value(0)
	location.get_member(0).get_y().set_value(29)
	assert(not rules.can_apply(location))
	assert(rules.as_indented_str(rules.state) == before_placement)
	location.get_member(0).get_x().set_value(2)
	location.get_member(0).get_y().set_value(27)
	assert(rules.can_apply(location))
	rules.apply_action(location)
	assert(rules.library.size(rules.state.get_board().get_units()) == 1)
	assert(not rules.library.get(rules.state.get_board().get_units(), 0).get_owned_by_player1())
	interaction.on_state_change()
	assert(interaction.current_select_unit_action == null)
	var opposing_buttons = deployment_buttons(choices)
	assert(opposing_buttons.size() == 4)
	assert(opposing_buttons[0].text.begins_with("deploy army 2:"))
	# The first legal opponent reserve ID is 4, not battlefield model ID 0.
	var wrong = RLCGameSelectUnit.make()
	wrong.get_member(0).get_id().set_value(0)
	assert(not rules.can_apply(wrong))
	opposing_buttons[0].button_down.emit()
	location = rules.get_location_saction()
	assert(location != null)
	location.get_member(0).get_x().set_value(2)
	location.get_member(0).get_y().set_value(2)
	assert(rules.can_apply(location))
	rules.apply_action(location)
	assert(rules.library.size(rules.state.get_board().get_units()) == 2)
	assert(rules.library.get(rules.state.get_board().get_units(), 1).get_owned_by_player1())
	assert(deployment_buttons(choices).size() == 4)
	# Finish army 1 through the real button while it still has reserves.
	var done_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == "done deploying army 1":
			done_button = button
	assert(done_button != null)
	done_button.button_down.emit()
	assert(rules.library.get_current_player(rules.state) == 1)
	var remaining_opponent = deployment_buttons(choices)
	assert(remaining_opponent.size() == 3)
	for button in remaining_opponent:
		assert(button.text.begins_with("deploy army 2:"))
	remaining_opponent[0].button_down.emit()
	location = rules.get_location_saction()
	location.get_member(0).get_x().set_value(15)
	location.get_member(0).get_y().set_value(2)
	assert(rules.can_apply(location))
	rules.apply_action(location)
	# Once army 1 passed, army 2 keeps deploying; army 1 must not return.
	assert(rules.library.get_current_player(rules.state) == 1)
	assert(deployment_buttons(choices).size() == 2)
	for button in deployment_buttons(choices):
		assert(button.text.begins_with("deploy army 2:"))
	var timing_choice = RLCGameChooseTimingRule.make()
	assert(timing_choice.members_count() == 1)
	assert(rules.library.is_enum(timing_choice.get_member(0)))
	var coherency_unit = RLCGameSelectIncoherentUnit.make()
	assert(coherency_unit.members_count() == 1 and coherency_unit.get_member(0) is RLCUnitID)
	var coherency_model = RLCGameRemoveIncoherentModel.make()
	assert(coherency_model.members_count() == 1 and coherency_model.get_member(0) is RLCModelID)
	var neural = RLCGameSelectNeuralDisruptionTarget.make()
	assert(neural.members_count() == 2 and neural.get_member(0) is RLCUnitID and neural.get_member(1) is RLCUnitID)
	# Identical armies must still expose an unambiguous finish/handoff.
	rules.reset()
	rules.apply_action(RLCGamePickStrikeForceOctavious.make())
	rules.apply_action(RLCGamePickStrikeForceOctavious.make())
	rules.apply_action(RLCGameDoneAttaching.make())
	rules.apply_action(RLCGameDoneAttaching.make())
	assert(rules.library.get_current_player(rules.state) == 0)
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == "done deploying army 1":
			button.button_down.emit()
			break
	assert(rules.library.get_current_player(rules.state) == 1)
	assert(deployment_buttons(choices).size() == 4)
	for button in deployment_buttons(choices):
		assert(button.text.begins_with("deploy army 2:"))
	print("PASS: Godot schema exports, army choices, target/unit/location selectors, rejected edge placement, both armies through deployment buttons, done-deploying handoff with different/identical armies and save replacement")
	# Clean up the test-owned library; production ownership changes are out of scope.
	rules.library.free()
	call_deferred("quit", 0)
