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
	assert(rules.library.get_state_schema_version() == 19)
	assert(rules.library.get_action_schema_version() == 14)
	assert(rules.library.get_observation_schema_version() == 19)
	assert(rules.valid_actions.size() == 6)
	# User-directed configuration: actual enum buttons, unique picks, saved
	# pending selection and automatic handoff after the third package.
	rules.apply_action(RLCGamePickMorgrimButcha.make())
	assert(rules.library.get_current_player(rules.state) == 0)
	press_choice(choices, "select detachment: war horde")
	var package_pick = RLCGameChooseOrksDetachment.make()
	package_pick.get_member(0).set_value(1)
	assert(not rules.can_apply(package_pick))
	press_choice(choices, "select detachment: da big hunt")
	var package_snapshot = rules.as_indented_str(rules.state)
	var package_restored = rules.library.play()
	assert(rules.library.set_state(package_restored, RLCLib.godot_string_to_rlc_string(package_snapshot)))
	rules.set_state(package_restored)
	assert(rules.library.size(rules.library.army_for_player(rules.state.get_board(), false).get_detachments()) == 2)
	press_choice(choices, "select detachment: green tide")
	assert(rules.library.get_current_player(rules.state) == 1)
	assert(not rules.can_apply(package_pick))
	assert(rules.library.size(rules.library.army_for_player(rules.state.get_board(), false).get_detachments()) == 3)
	rules.apply_action(RLCGamePickMorgrimButcha.make())
	assert(rules.library.get_current_player(rules.state) == 1)
	press_choice(choices, "select detachment: bully boyz")
	press_choice(choices, "finish detachment selection")
	assert(rules.library.size(rules.library.army_for_player(rules.state.get_board(), true).get_detachments()) == 1)
	print("CHECK: Godot three-detachment buttons, duplicate rejection, pending save and both-player handoff completed")
	rules.reset()
	var choose = RLCGamePickInsidiousInfiltrators.make()
	rules.apply_action(choose)
	assert(rules.valid_actions.size() == 6)
	rules.apply_action(RLCGamePickStrikeForceOctavious.make())
	rules.apply_action(RLCGameDoneAttaching.make())
	finish_reserve_choices(rules)
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
	finish_reserve_choices(rules)
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
	# Explicit reserve fixtures preserve the two-army button handoff check;
	# production now requires every non-reserved unit to deploy.
	mark_remaining_reserves(rules, false)
	rules.valid_actions = rules._valid_actions()
	choices.on_state_change()
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
	finish_reserve_choices(rules)
	rules.apply_action(RLCGameDoneAttaching.make())
	finish_reserve_choices(rules)
	assert(rules.library.get_current_player(rules.state) == 0)
	mark_remaining_reserves(rules, false)
	rules.valid_actions = rules._valid_actions()
	choices.on_state_change()
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
	mark_remaining_reserves(rules, true)
	rules.valid_actions = rules._valid_actions()
	choices.on_state_change()
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == "done deploying army 2":
			button.button_down.emit()
			break
	while rules.can_apply(RLCGameFinishScouts.make()):
		rules.apply_action(RLCGameFinishScouts.make())
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
	area.get_lower().get_x().set_value(1)
	area.get_lower().get_y().set_value(1)
	area.get_upper().get_x().set_value(3)
	area.get_upper().get_y().set_value(3)
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
	var source_node = ModelClickFixture.new()
	var target_node = ModelClickFixture.new()
	target_node.unit_id = 1
	interaction.models.add_child(source_node)
	interaction.models.add_child(target_node)
	for step in range(50):
		if board.get_timing().get_phase().get_value() == 3 and rules.can_apply(shoot):
			break
		var advance = null
		for action in rules.valid_actions:
			var unwrapped = action.unwrap()
			if unwrapped is RLCGameFinishTimingRules or unwrapped is RLCGameEndMove or unwrapped is RLCGameMoveUnit or unwrapped is RLCGameRemainStationary or unwrapped is RLCGameSelectReserveUnit or unwrapped is RLCGameReserveRemainStationary:
				advance = action
				break
		assert(advance != null)
		if advance.unwrap() is RLCGameMoveUnit:
			rules.apply_action(advance)
			rules.apply_action(RLCGameNormalMove.make())
			interaction.on_state_change()
			assert(interaction.current_select_model_action is RLCGameSelectMovingModel)
			assert(source_node.marked and not target_node.marked)
			interaction.select(source_node)
			var waypoint = rules.get_location_saction()
			assert(waypoint is RLCGameWaypoint)
			waypoint.get_member(0).get_x().set_value(3)
			waypoint.get_member(0).get_y().set_value(2)
			assert(rules.can_apply(waypoint))
			rules.apply_action(waypoint)
			assert(rules.library.get(rules.library.get(board.get_units(), 0).get_models(), 0).get_position().get_x().get_value() == 2)
			var moving_snapshot = rules.as_indented_str(rules.state)
			var moving_restored = rules.library.play()
			assert(rules.library.set_state(moving_restored, RLCLib.godot_string_to_rlc_string(moving_snapshot)))
			rules.set_state(moving_restored)
			board = rules.state.get_board()
			rules.apply_action(RLCGameFinishModel.make())
			rules.apply_action(RLCGameFinishMove.make())
			assert(rules.library.get(rules.library.get(board.get_units(), 0).get_models(), 0).get_position().get_x().get_value() == 3)
		else:
			rules.apply_action(advance)
	assert(board.get_timing().get_phase().get_value() == 3 and rules.can_apply(shoot))
	# Task 15: explicit keyword fixture selects Explosives by source button,
	# then its bearer/target through the production model/unit click controls.
	var explosives_unit = rules.library.get(board.get_units(), 0)
	var explosives_model = rules.library.get(explosives_unit.get_models(), 0)
	append_core_keyword(rules.library, explosives_model, 56, "grenades")
	rules.library.command_points_for_player(board, true).set_value(6)
	rules.valid_actions = rules._valid_actions()
	rules.on_state_changed.emit()
	press_first_choice(choices, "explosives")
	interaction.on_state_change()
	assert(interaction.current_select_model_action is RLCGameChooseExplosivesModel)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameChooseExplosivesTarget)
	interaction.select(target_node)
	var explosives_roll = RLCGameRoll.make()
	explosives_roll.get_member(0).set_value(1)
	for die in range(6):
		assert(rules.library.get_current_player(rules.state) == -1)
		rules.apply_action(explosives_roll)
	assert(not explosives_unit.get_has_shoot())
	assert(explosives_unit.get_history().get_used_stratagem_this_phase())
	print("CHECK: Godot Explosives source button, bearer/target clicks and six dice completed")
	# Separate fixture: the existing hit/save regression needs an unused
	# per-unit stratagem allowance. Do not treat this reset as legal gameplay.
	rules.library.clear_phase_modifiers(board)
	rules.valid_actions = rules._valid_actions()
	rules.on_state_changed.emit()
	# Task16 explicit capacity/Firing Deck fixture. These declarations are test
	# permissions, not new faction data. The passenger bank is never clickable
	# at its former battlefield location, and keeps its original model identity.
	append_core_keyword(rules.library, explosives_model, 59, "transport")
	explosives_model.set_transport_permissions_known(true)
	explosives_model.get_transport_capacity().set_value(6)
	explosives_model.get_firing_deck().set_value(1)
	var passenger_fixture = rules.library.make_infernus_squad()
	while rules.library.size(passenger_fixture.get_models()) > 1:
		rules.library.erase(passenger_fixture.get_models(), rules.library.size(passenger_fixture.get_models()) - 1)
	passenger_fixture.set_owned_by_player1(explosives_unit.get_owned_by_player1())
	var passenger_fixture_model = rules.library.get(passenger_fixture.get_models(), 0)
	passenger_fixture_model.get_position().get_x().set_value(5)
	passenger_fixture_model.get_position().get_y().set_value(2)
	rules.library.capture_starting_strength(passenger_fixture)
	rules.library.append(board.get_units(), passenger_fixture)
	var passenger_fixture_id = RLCUnitID.make()
	passenger_fixture_id.get_id().set_value(2)
	var passenger_fixture_unit = rules.library.get(board.get_units(), 2)
	rules.library.identify_unit(board, passenger_fixture_unit)
	var fixture_move = RLCMovementKind.make()
	fixture_move.set_value(1)
	assert(str(rules.library.as_string_literal(fixture_move)) == "normal")
	rules.library.record_move(board, passenger_fixture_id, fixture_move)
	var fixture_carrier_id = RLCUnitID.make()
	fixture_carrier_id.get_id().set_value(0)
	var fixture_carrier_model = RLCModelID.make()
	fixture_carrier_model.get_id().set_value(0)
	rules.library.embark_battlefield_unit(board, passenger_fixture_id, fixture_carrier_id, fixture_carrier_model)
	assert(rules.library.size(board.get_embarked_units()) == 1)
	assert(rules.library.size(passenger_fixture_unit.get_models()) == 0)
	assert(rules.library.valid_state_foundations(board))
	rules.apply_action(shoot)
	var shooting_kind = RLCGameChooseShootingKind.make()
	shooting_kind.get_member(0).set_value(0)
	assert(rules.can_apply(shooting_kind))
	rules.apply_action(shooting_kind)
	# Explicit fixture grants exercise duplicate ability buttons in Select Weapons.
	var grant = RLCWeaponRule.make()
	grant.get_kind().set_value(6) # SUSTAINED HITS
	# A field wrapper borrows its parent action; retain that parent while using it.
	var slot_action = RLCGameSelectWeapon.make()
	var slot = slot_action.get_member(0)
	slot.set_value(0)
	var bearer = RLCModelID.make()
	bearer.get_id().set_value(0)
	var shooter_id = RLCUnitID.make()
	shooter_id.get_id().set_value(0)
	grant.get_parameter().set_value(1)
	rules.library.grant_model_weapon_rule(board, shooter_id, bearer, slot, grant)
	grant.get_parameter().set_value(2)
	# Appendix02.05.01: the duplicate button must display a conjunction,
	# slash alternatives and an exclusion distinctly. Keyword IDs retain the
	# existing stats.rl enum order; these are fixture metadata, not actions.
	var predicate_clause = RLCKeywordClause.make()
	var condition_keyword = RLCKeyword.make()
	predicate_clause.set_value(0) # ALL
	condition_keyword.set_value(0) # INFANTRY
	assert(rules.library.append_keyword_condition(grant.get_target_condition(), predicate_clause, condition_keyword))
	predicate_clause.set_value(1) # ANY
	condition_keyword.set_value(45) # MONSTER
	assert(rules.library.append_keyword_condition(grant.get_target_condition(), predicate_clause, condition_keyword))
	condition_keyword.set_value(46) # VEHICLE
	assert(rules.library.append_keyword_condition(grant.get_target_condition(), predicate_clause, condition_keyword))
	predicate_clause.set_value(2) # NONE
	condition_keyword.set_value(48) # TITANIC
	assert(rules.library.append_keyword_condition(grant.get_target_condition(), predicate_clause, condition_keyword))
	rules.library.grant_model_weapon_rule(board, shooter_id, bearer, slot, grant)
	var weapon_choice = RLCGameSelectWeapon.make()
	weapon_choice.get_member(0).set_value(0)
	assert(rules.can_apply(weapon_choice))
	var weapon_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.contains("captain storm bolter"):
			weapon_button = button
	assert(weapon_button != null)
	weapon_button.button_down.emit()
	var compound_condition_button = null
	for candidate_button in choices.get_node("ChoiseList").get_children():
		if not candidate_button.is_queued_for_deletion() and candidate_button.text == rules.strip_symbols("sustained hit 2 against infantry and (monster or vehicle); excluding titanic"):
			compound_condition_button = candidate_button
	assert(compound_condition_button != null)
	print("CHECK: Godot ALL/ANY/NONE duplicate-ability label completed")
	var weapon_ability_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == rules.strip_symbols("sustained hit 1"):
			weapon_ability_button = button
	assert(weapon_ability_button != null)
	weapon_ability_button.button_down.emit()
	rules.apply_action(RLCGameSkip.make())
	press_first_choice(choices, "firing deck passenger")
	interaction.on_state_change()
	assert(interaction.current_select_model_action == null)
	press_choice(choices, "choose model 1")
	press_first_choice(choices, "firing deck:")
	press_choice(choices, "finish firing deck")
	assert(rules.library.get(board.get_embarked_units(), 0).get_history().get_deck_shooting_locked())
	var declaration = rules.get_current_target_action()
	assert(declaration is RLCGameDeclareTarget)
	assert(declaration.get_member(0) is RLCUnitID and declaration.get_member(1) is RLCUnitID)
	interaction.on_state_change()
	assert(source_node.marked)
	interaction.select(source_node)
	assert(target_node.marked)
	interaction.select(target_node)
	# Resolve the physical weapon as before; decline the borrowed profile's
	# target so the pre-existing combat fixture keeps its original attack count.
	assert(rules.can_apply(RLCGameSkipTarget.make()))
	rules.apply_action(RLCGameSkipTarget.make())
	print("CHECK: Godot Firing Deck passenger/model/weapon buttons and offboard context completed")
	# Subsequent shooting checks are independent fixtures without Firing Deck.
	explosives_model.get_firing_deck().set_value(0)
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
	print("CHECK: Godot shooting selection and hit snapshot reached")
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
	# Task 10: explicit FNP fixture, with another activation to exercise actual
	# group buttons, all saves before allocation and model clicks on the defender.
	print("CHECK: Godot hit snapshot restoration completed")
	var attacker = rules.library.get(board.get_units(), 0)
	attacker.set_has_shoot(false)
	var fnp_fixture = rules.library.make_beast_snagga_boyz()
	var fnp_profile = rules.library.get(fnp_fixture.get_models(), 1).get_profile()
	rules.library.assign(rules.library.get(rules.library.get(board.get_units(), 1).get_models(), 0).get_profile(), fnp_profile)
	assert(rules.can_apply(shoot))
	rules.apply_action(shoot)
	assert(rules.can_apply(shooting_kind))
	rules.apply_action(shooting_kind)
	weapon_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.contains("captain storm bolter"):
			weapon_button = button
	assert(weapon_button != null)
	weapon_button.button_down.emit()
	var ability_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == rules.strip_symbols("sustained hit 1"):
			ability_button = button
	assert(ability_button != null)
	ability_button.button_down.emit()
	rules.apply_action(RLCGameSkip.make())
	interaction.on_state_change()
	interaction.select(source_node)
	interaction.select(target_node)
	interaction.on_state_change()
	interaction.select(target_node)
	rules.apply_action(RLCGameNoDefensiveStratagem.make())
	rules.apply_action(RLCGameNoOffensiveStratagem.make())
	group_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.begins_with("resolve "):
			group_button = button
	assert(group_button != null)
	group_button.button_down.emit()
	print("CHECK: Godot second shooting selection completed")
	hit.get_member(0).set_value(6)
	# Four critical hits with Sustained Hits 1 produce eight wound rolls.
	for batch in range(2):
		for i in range(4 if batch == 0 else 8):
			assert(rules.library.get_current_player(rules.state) == -1)
			assert(rules.can_apply(hit))
			rules.apply_action(hit)
		if rules.can_apply(RLCGameKeepBatch.make()):
			rules.apply_action(RLCGameKeepBatch.make())
	assert(rules.library.get_current_player(rules.state) == 0)
	var save_group_button = null
	for button in choices.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.begins_with("allocate group 1"):
			save_group_button = button
	assert(save_group_button != null)
	assert(save_group_button.text.contains("sv 5"))
	save_group_button.button_down.emit()
	hit.get_member(0).set_value(1)
	for i in range(8):
		assert(rules.can_apply(hit))
		rules.apply_action(hit)
	if rules.can_apply(RLCGameKeepBatch.make()):
		rules.apply_action(RLCGameKeepBatch.make())
	assert(rules.get_current_select_model_action() is RLCGameAllocateWound)
	print("CHECK: Godot Sustained Hits, save groups and allocation reached")
	var save_snapshot = rules.as_indented_str(rules.state)
	var save_restored = rules.library.play()
	assert(rules.library.set_state(save_restored, RLCLib.godot_string_to_rlc_string(save_snapshot)))
	rules.set_state(save_restored)
	board = rules.state.get_board()
	print("CHECK: Godot pending-save restoration completed")
	for i in range(3):
		interaction.on_state_change()
		assert(target_node.marked and not source_node.marked)
		interaction.select(target_node)
		assert(rules.library.get_current_player(rules.state) == -1)
		hit.get_member(0).set_value(6 if i == 0 else 1)
		rules.apply_action(hit)
	assert(rules.library.size(rules.library.get(board.get_units(), 1).get_models()) == 0)
	assert(rules.library.size(rules.library.get(board.get_units(), 1).get_destroyed_models().get_value()) == 1)
	assert(rules.can_apply(RLCGameEndShootingPhase.make()))
	assert(rules.library.get_current_player(rules.state) == 1)
	# Task 13: prepare two living enemy fixtures, then use the production unit
	# and model clicks for post-roll multi-target declaration and staged paths.
	var charger = rules.library.get(board.get_units(), 0)
	var charger_model = rules.library.get(charger.get_models(), 0)
	charger_model.get_position().get_x().set_value(5)
	charger_model.get_position().get_y().set_value(5)
	charger.set_can_charge(true)
	append_core_keyword(rules.library, charger_model, 46, "vehicle")
	rules.library.command_points_for_player(board, false).set_value(3)
	rules.library.command_points_for_player(board, true).set_value(3)
	charger.get_history().set_advanced_this_turn(false)
	charger.get_history().set_fell_back_this_turn(false)
	var charge_enemy = rules.library.make_infernus_squad()
	while rules.library.size(charge_enemy.get_models()) > 1:
		rules.library.erase(charge_enemy.get_models(), rules.library.size(charge_enemy.get_models()) - 1)
	charge_enemy.set_owned_by_player1(false)
	var charge_enemy_model = rules.library.get(charge_enemy.get_models(), 0)
	charge_enemy_model.get_position().get_x().set_value(13)
	charge_enemy_model.get_position().get_y().set_value(5)
	rules.library.append(rules.library.get(board.get_units(), 1).get_models(), charge_enemy_model)
	rules.library.identify_unit(board, rules.library.get(board.get_units(), 1))
	charge_enemy_model.get_position().get_y().set_value(7)
	var second_target_slot = rules.library.size(board.get_units())
	rules.library.append(board.get_units(), charge_enemy)
	rules.library.identify_unit(board, rules.library.get(board.get_units(), second_target_slot))
	# Appending can relocate the unit vector. Refresh borrowed wrappers before
	# checking that the forthcoming charge path only changes its staged copy.
	charger = rules.library.get(board.get_units(), 0)
	charger_model = rules.library.get(charger.get_models(), 0)
	var second_target_node = ModelClickFixture.new()
	second_target_node.unit_id = second_target_slot
	interaction.models.add_child(second_target_node)
	rules.apply_action(RLCGameEndShootingPhase.make())
	for step in range(8):
		if rules.get_current_select_unit_action() is RLCGameSelectChargingUnit:
			break
		assert(rules.can_apply(RLCGameFinishTimingRules.make()))
		rules.apply_action(RLCGameFinishTimingRules.make())
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameSelectChargingUnit)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	assert(rules.library.get_current_player(rules.state) == -1)
	var charge_pair = RLCGameRollPair.make()
	charge_pair.get_member(0).set_value(4)
	charge_pair.get_member(1).set_value(4)
	assert(rules.can_apply(charge_pair))
	rules.apply_action(charge_pair)
	var keep_charge_roll = RLCGameKeepIt.make()
	keep_charge_roll.set_do_it(true)
	if rules.can_apply(keep_charge_roll):
		rules.apply_action(keep_charge_roll)
	assert(not charger.get_has_charged())
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameSelectChargeTarget)
	assert(target_node.marked and second_target_node.marked and not source_node.marked)
	interaction.select(target_node)
	interaction.on_state_change()
	assert(not target_node.marked and second_target_node.marked)
	interaction.select(second_target_node)
	rules.apply_action(RLCGameFinishChargeTargets.make())
	interaction.on_state_change()
	assert(interaction.current_select_model_action is RLCGameSelectChargingModel)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	var charge_waypoint = rules.get_location_saction()
	assert(charge_waypoint is RLCGameChargeWaypoint)
	charge_waypoint.get_member(0).get_x().set_value(11)
	charge_waypoint.get_member(0).get_y().set_value(6)
	assert(rules.can_apply(charge_waypoint))
	rules.apply_action(charge_waypoint)
	assert(charger_model.get_position().get_x().get_value() == 5)
	var charge_snapshot = rules.as_indented_str(rules.state)
	var charge_restored = rules.library.play()
	assert(rules.library.set_state(charge_restored, RLCLib.godot_string_to_rlc_string(charge_snapshot)))
	rules.set_state(charge_restored)
	board = rules.state.get_board()
	rules.apply_action(RLCGameFinishChargeModel.make())
	assert(rules.can_apply(RLCGameFinishChargeMove.make()))
	rules.apply_action(RLCGameFinishChargeMove.make())
	charger = rules.library.get(board.get_units(), 0)
	assert(charger.get_has_charged())
	assert(charger.get_history().get_charge_move_phase().get_value() == board.get_phase_serial().get_value() + 1)
	assert(rules.library.get(charger.get_models(), 0).get_position().get_x().get_value() == 11)
	assert(rules.can_apply(RLCGameCrushingImpact.make()))
	press_choice(choices, "crushing impact")
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameChooseImpactTarget)
	interaction.select(target_node)
	interaction.on_state_change()
	assert(interaction.current_select_model_action is RLCGameChooseImpactModel)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	var impact_roll = RLCGameRoll.make()
	impact_roll.get_member(0).set_value(2)
	var impact_dice = 0
	while rules.can_apply(impact_roll):
		assert(rules.library.get_current_player(rules.state) == -1)
		rules.apply_action(impact_roll)
		impact_dice += 1
		assert(impact_dice < 257)
	assert(impact_dice == rules.library.thoughness(rules.library.get(charger.get_models(), 0).get_profile()))
	assert(rules.can_apply(RLCGameEndCharge.make()))
	print("CHECK: Godot Crushing Impact target/bearer clicks and Toughness dice completed")
	print("CHECK: Godot post-roll multi-target charge clicks and staged path restoration completed")
	# Task 14: phase-wide Pile In precedes unit fighting. Exercise the same
	# controller's closest-target tie choice and save a pending melee path.
	rules.apply_action(RLCGameEndCharge.make())
	for step in range(8):
		if rules.get_current_select_unit_action() is RLCGameSelectMeleeUnit:
			break
		assert(rules.can_apply(RLCGameFinishTimingRules.make()))
		rules.apply_action(RLCGameFinishTimingRules.make())
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameSelectMeleeUnit)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	interaction.on_state_change()
	assert(interaction.current_select_model_action is RLCGameSelectMeleeModel)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameChooseMeleeApproach)
	assert(target_node.marked and second_target_node.marked)
	interaction.select(target_node)
	var melee_waypoint = rules.get_location_saction()
	assert(melee_waypoint is RLCGameMeleeWaypoint)
	melee_waypoint.get_member(0).get_x().set_value(11)
	melee_waypoint.get_member(0).get_y().set_value(5)
	rules.apply_action(melee_waypoint)
	var melee_snapshot = rules.as_indented_str(rules.state)
	var melee_restored = rules.library.play()
	assert(rules.library.set_state(melee_restored, RLCLib.godot_string_to_rlc_string(melee_snapshot)))
	rules.set_state(melee_restored)
	board = rules.state.get_board()
	rules.apply_action(RLCGameFinishMeleeModel.make())
	assert(rules.can_apply(RLCGameFinishMeleeMove.make()))
	rules.apply_action(RLCGameFinishMeleeMove.make())
	charger = rules.library.get(board.get_units(), 0)
	assert(charger.get_history().get_pile_in_phase().get_value() == board.get_phase_serial().get_value() + 1)
	rules.apply_action(RLCGameFinishMeleeStep.make())
	assert(rules.library.get_current_player(rules.state) == 0)
	rules.apply_action(RLCGameFinishMeleeStep.make())
	assert(rules.library.get_current_player(rules.state) == 1)
	# A fixture melee loadout keeps this UI test independent of old Captain
	# weapons; the actual unit/faction permission data still belongs to task 17.
	charger_model = rules.library.get(charger.get_models(), 0)
	rules.library.assign(charger_model.get_weapons(), rules.library.get(charge_enemy.get_models(), 0).get_weapons())
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameSelectFightingUnit)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	assert(rules.can_apply(RLCGameEpicChallenge.make()))
	press_choice(choices, "epic challenge")
	interaction.on_state_change()
	assert(interaction.current_select_model_action is RLCGameChooseEpicCharacter)
	assert(source_node.marked and not target_node.marked)
	interaction.select(source_node)
	assert(rules.library.get(charger.get_models(), 0).get_history().get_epic_challenge())
	press_choice(choices, "normal fight")
	press_choice(choices, "close combact weapon")
	rules.apply_action(RLCGameSkip.make())
	interaction.on_state_change()
	interaction.select(source_node)
	interaction.select(target_node)
	var share = RLCGameAssignAttacks.make()
	share.get_member(0).set_value(3)
	rules.apply_action(share)
	interaction.on_state_change()
	interaction.select(target_node)
	rules.apply_action(RLCGameNoDefensiveStratagem.make())
	rules.apply_action(RLCGameNoOffensiveStratagem.make())
	press_first_choice(choices, "resolve ")
	hit.get_member(0).set_value(1)
	for die in range(3):
		assert(rules.library.get_current_player(rules.state) == -1)
		rules.apply_action(hit)
	if rules.can_apply(RLCGameKeepBatch.make()):
		rules.apply_action(RLCGameKeepBatch.make())
	assert(charger.get_has_fought())
	assert(rules.library.get_current_player(rules.state) == 0)
	press_first_choice(choices, "counteroffensive")
	assert(rules.library.get(board.get_units(), 1).get_phase_modifiers().get_counteroffensive())
	interaction.on_state_change()
	assert(target_node.marked and not source_node.marked)
	print("CHECK: Godot Epic Challenge bearer and Counteroffensive next-unit selection completed")
	# Supplied Fight on Death: this enemy remains physically present, and is
	# selected with its unit rather than retaliating during the previous attack.
	var retained_unit = rules.library.get(board.get_units(), 1)
	var retained_model = rules.library.get(retained_unit.get_models(), 0)
	retained_model.get_state().set_value(1)
	retained_model.get_suffered_wounds().set_value(2)
	retained_model.set_destruction_pending(true)
	retained_model.set_destroyed_by_attack(true)
	retained_model.set_destroying_unit_known(true)
	retained_model.get_destroying_unit().get_id().set_value(0)
	retained_model.get_destruction_fight_roll().set_value(1)
	interaction.on_state_change()
	interaction.select(target_node)
	press_choice(choices, "normal fight")
	press_choice(choices, "close combact weapon")
	rules.apply_action(RLCGameSkip.make())
	interaction.on_state_change()
	interaction.select(target_node)
	interaction.select(source_node)
	rules.apply_action(share)
	interaction.on_state_change()
	interaction.select(source_node)
	rules.apply_action(RLCGameNoDefensiveStratagem.make())
	rules.apply_action(RLCGameNoOffensiveStratagem.make())
	press_first_choice(choices, "resolve ")
	for die in range(3):
		rules.apply_action(hit)
	if rules.can_apply(RLCGameKeepBatch.make()):
		rules.apply_action(RLCGameKeepBatch.make())
	interaction.on_state_change()
	assert(interaction.current_select_unit_action is RLCGameChooseDestructionUnit)
	interaction.select(target_node)
	interaction.on_state_change()
	assert(interaction.current_select_model_action is RLCGameResolveDestructionModel)
	assert(target_node.marked and not source_node.marked)
	interaction.select(target_node)
	assert(rules.library.size(retained_unit.get_models()) == 0)
	assert(rules.library.size(retained_unit.get_destroyed_models().get_value()) == 2)
	assert(not board.get_allow_destroyed_attack())
	print("CHECK: Godot Pile In/closest-target/path restoration, alternating melee and retained-unit Fight on Death completed")
	print("PASS: Godot schema exports, deployment, Command recovery, terrain/objective saves, weapon/target/group buttons and clicks, batch chance ownership, pending-attack/save restoration, allocation group/model controls, per-wound FNP and independent movement clicks/waypoints/save restoration")
	# Clean up the test-owned library; production ownership changes are out of scope.
	rules.library.free()
	call_deferred("quit", 0)

# Explicit fixture-only strategic status, not permission to bypass points in play.
func mark_remaining_reserves(rules, owner):
	var reserves = rules.state.get_board().get_reserve_units()
	for i in range(rules.library.size(reserves)):
		var unit = rules.library.get(reserves, i)
		if unit.get_owned_by_player1() == owner:
			unit.get_history().set_strategic_reserve(true)

func finish_reserve_choices(rules):
	while rules.can_apply(RLCGameFinishReserveSelection.make()):
		rules.apply_action(RLCGameFinishReserveSelection.make())

# Buttons are production controls; reject a missing required choice rather
# than invoking the underlying action directly for weapon/fight decisions.
func press_choice(panel, label):
	for button in panel.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == label:
			button.button_down.emit()
			return
	assert(false, "Missing choice: " + label)

func press_first_choice(panel, prefix):
	for button in panel.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text.begins_with(prefix):
			button.button_down.emit()
			return
	assert(false, "Missing choice prefix: " + prefix)

# Explicit core fixtures assert the generated enum name before using its ID.
func append_core_keyword(library, model, value, expected_name):
	var keyword = RLCKeyword.make()
	keyword.set_value(value)
	assert(str(library.as_string_literal(keyword)) == expected_name)
	library.append(model.get_keywords(), keyword)
