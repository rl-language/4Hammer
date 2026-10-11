extends SceneTree

class ModelClickFixture:
	extends Sprite2D
	var unit_id = 0
	var model_id = 0
	var marked = false
	func show_aura():
		marked = true
	func hide_aura():
		marked = false

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
	assert(rules.library.get_state_schema_version() == 8)
	assert(rules.library.get_action_schema_version() == 4)
	assert(rules.library.get_observation_schema_version() == 8)
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
	# Continue into a real Command recovery roll with Army 2 as first player.
	deployment_buttons(choices)[0].button_down.emit()
	location = rules.get_location_saction()
	location.get_member(0).get_x().set_value(2)
	location.get_member(0).get_y().set_value(2)
	assert(rules.can_apply(location))
	rules.apply_action(location)
	var unit = rules.library.get(rules.state.get_board().get_units(), 0)
	assert(unit.get_owned_by_player1())
	unit.set_battle_socked(true)
	assert(rules.library.model_is_battle_shocked(unit, 0))
	assert(rules.library.model_objective_control(unit, 0) == 0)
	assert(not rules.library.allows_action_start(unit))
	assert(not rules.library.allows_action_completion(unit))
	rules.state.get_board().set_starting_player(true)
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == "done deploying army 2":
			button.button_down.emit()
			break
	assert(rules.library.get_current_player(rules.state) == -1)
	assert(unit.get_battle_socked())
	# Save/reload while waiting for recovery dice: preserve the start-step
	# shock snapshot, nested frame and chance ownership in the current schema.
	var recovery_snapshot = rules.as_indented_str(rules.state)
	var recovery_restored = rules.library.play()
	assert(rules.library.set_state(recovery_restored, RLCLib.godot_string_to_rlc_string(recovery_snapshot)))
	rules.set_state(recovery_restored)
	unit = rules.library.get(rules.state.get_board().get_units(), 0)
	assert(unit.get_battle_socked())
	assert(rules.library.get_current_player(rules.state) == -1)
	var recovery = RLCGameRollPair.make()
	recovery.get_member(0).set_value(3)
	recovery.get_member(1).set_value(3)
	assert(rules.can_apply(recovery))
	# The existing pair payload and chance classifier survive the new frame.
	rules.apply_action(recovery)
	assert(not unit.get_battle_socked())
	assert(rules.library.model_objective_control(unit, 0) == 1)
	assert(rules.library.allows_action_start(unit))
	assert(rules.library.allows_action_completion(unit))
	assert(rules.library.get_current_player(rules.state) == 1)
	# Task 8: construct an area using bounded generated fields, then validate
	# cover/Hidden and secured objective snapshots through native bindings.
	var board = rules.state.get_board()
	var area = RLCTerrainArea.make()
	area.get_lower().get_x().set_value(25400)
	area.get_lower().get_y().set_value(25400)
	area.get_upper().get_x().set_value(76200)
	area.get_upper().get_y().set_value(76200)
	area.set_dense(true)
	area.set_light(true)
	rules.library.append(board.get_terrain_areas(), area)
	var point = RLCBoardPosition.make()
	point.get_x().set_value(2)
	point.get_y().set_value(2)
	rules.library.set_objective_position(board, 0, point)
	assert(rules.library.link_objective_terrain_areas(board))
	assert(rules.library.get_objective_controller(board, 0) == -1)
	rules.library.update_objective_control(board, true)
	assert(rules.library.get_objective_controller(board, 0) == 1)
	rules.library.grant_secured_objective(board, 0, true)
	var model = rules.library.get(unit.get_models(), 0)
	assert(rules.library.model_is_hidden(board, unit, model))
	var observer_unit = rules.library.make_infernus_squad()
	var observer = rules.library.get(observer_unit.get_models(), 0)
	observer.get_position().get_x().set_value(22)
	observer.get_position().get_y().set_value(2)
	assert(not rules.library.model_visible_to_model(board, observer, unit, model))
	assert(rules.library.unit_has_benefit_of_cover(board, observer, unit))
	model.get_position().get_x().set_value(10)
	rules.library.update_objective_control(board, true)
	assert(rules.library.get_objective_controller(board, 0) == 1)
	var area_snapshot = rules.as_indented_str(rules.state)
	var area_restored = rules.library.play()
	assert(rules.library.set_state(area_restored, RLCLib.godot_string_to_rlc_string(area_snapshot)))
	rules.set_state(area_restored)
	board = rules.state.get_board()
	assert(rules.library.size(board.get_terrain_areas()) == 1)
	assert(rules.library.get(board.get_terrain_areas(), 0).get_dense())
	assert(rules.library.get(board.get_terrain_areas(), 0).get_light())
	assert(rules.library.get_objective_controller(board, 0) == 1)
	unit = rules.library.get(board.get_units(), 0)
	model = rules.library.get(unit.get_models(), 0)
	model.get_position().get_x().set_value(2)
	assert(rules.library.model_is_hidden(board, unit, model))
	var shooter = RLCUnitID.make()
	shooter.get_id().set_value(0)
	rules.library.record_ranged_attacks(board, shooter)
	assert(not rules.library.model_is_hidden(board, unit, model))
	# Task 9: add one explicit opponent fixture, finish timing/movement without
	# moving, then declare an actual Captain weapon through the production UI.
	var enemy = rules.library.make_infernus_squad()
	while rules.library.size(enemy.get_models()) > 1:
		rules.library.erase(enemy.get_models(), rules.library.size(enemy.get_models()) - 1)
	assert(rules.library.size(enemy.get_models()) == 1)
	enemy.set_owned_by_player1(false)
	rules.library.append(board.get_units(), enemy)
	rules.library.identify_unit(board, rules.library.get(board.get_units(), 1))
	# Configure the live target after inserting the single-model fixture.
	var live_enemy = rules.library.get(rules.library.get(board.get_units(), 1).get_models(), 0)
	live_enemy.get_position().get_x().set_value(10)
	live_enemy.get_position().get_y().set_value(2)
	var shoot = RLCGameSelectTarget.make()
	shoot.get_member(0).get_id().set_value(0)
	shoot.get_member(1).get_id().set_value(1)
	for step in range(20):
		if board.get_timing().get_phase().get_value() == 3 and rules.can_apply(shoot):
			break
		var advance = null
		for action in rules.valid_actions:
			var unwrapped = action.unwrap()
			if unwrapped is RLCGameFinishTimingRules or unwrapped is RLCGameEndMove or unwrapped is RLCGameNothingToDeploy:
				advance = action
				break
		assert(advance != null)
		rules.apply_action(advance)
	assert(board.get_timing().get_phase().get_value() == 3 and rules.can_apply(shoot))
	rules.apply_action(shoot)
	var weapon_choice = RLCGameSelectWeapon.make()
	weapon_choice.get_member(0).set_value(0)
	assert(rules.can_apply(weapon_choice))
	var weapon_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.contains("captain storm bolter"):
			weapon_button = button
	assert(weapon_button != null)
	weapon_button.button_down.emit()
	rules.apply_action(RLCGameSkip.make())
	var declaration = rules.get_current_target_action()
	assert(declaration is RLCGameDeclareTarget)
	assert(declaration.get_member(0) is RLCUnitID and declaration.get_member(1) is RLCUnitID)
	var source_node = ModelClickFixture.new()
	var target_node = ModelClickFixture.new()
	target_node.unit_id = 1
	interaction.models.add_child(source_node)
	interaction.models.add_child(target_node)
	interaction.on_state_change()
	assert(source_node.marked)
	interaction.select(source_node)
	assert(target_node.marked)
	interaction.select(target_node)
	assert(rules.get_current_select_unit_action() is RLCGameChooseAttackTarget)
	interaction.on_state_change()
	interaction.select(target_node)
	rules.apply_action(RLCGameNoDefensiveStratagem.make())
	rules.apply_action(RLCGameNoOffensiveStratagem.make())
	var group_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.begins_with("resolve "):
			group_button = button
	assert(group_button != null)
	group_button.button_down.emit()
	assert(rules.library.get_current_player(rules.state) == -1)
	var hit = RLCGameRoll.make()
	hit.get_member(0).set_value(1)
	for i in range(3):
		assert(rules.can_apply(hit))
		rules.apply_action(hit)
		assert(rules.library.get_current_player(rules.state) == -1)
	assert(board.get_attack().get_dice().get_hits().get_pool().get_total().get_value() == 3)
	var attack_snapshot = rules.as_indented_str(rules.state)
	var attack_restored = rules.library.play()
	assert(rules.library.set_state(attack_restored, RLCLib.godot_string_to_rlc_string(attack_snapshot)))
	rules.set_state(attack_restored)
	board = rules.state.get_board()
	assert(board.get_attack().get_dice().get_hits().get_pool().get_total().get_value() == 3)
	assert(rules.library.get_current_player(rules.state) == -1)
	rules.apply_action(hit)
	assert(rules.library.get_current_player(rules.state) == 1)
	var reroll_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == rules.strip_symbols("Re-roll a 1"):
			reroll_button = button
	assert(reroll_button != null)
	assert(rules.can_apply(RLCGameKeepBatch.make()))
	rules.apply_action(RLCGameKeepBatch.make())
	assert(rules.can_apply(RLCGameEndShootingPhase.make()))
	assert(rules.library.get_current_player(rules.state) == 1)
	print("PASS: Godot schema exports, deployment, Command recovery, terrain/objective saves, weapon/target/group buttons and clicks, batch chance ownership and pending-attack save replacement")
	# Clean up the test-owned library; production ownership changes are out of scope.
	rules.library.free()
	call_deferred("quit", 0)
