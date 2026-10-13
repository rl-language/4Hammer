extends SceneTree

func _initialize():
	call_deferred("check_orks_army")

func panel_for(rules, actions):
	rules.valid_actions = actions
	var panel = VBoxContainer.new()
	panel.set_script(load("res://MultipleChoises.gd"))
	var buttons = VBoxContainer.new()
	buttons.name = "ChoiseList"
	panel.add_child(buttons)
	root.add_child(panel)
	return panel

func wrapped(library, action):
	var result = RLCAnyGameAction.make()
	library.assign(result, action)
	return result

func check_offboard_clicks(rules, action):
	rules.valid_actions = [action]
	var sprites = Node2D.new()
	var interaction = Sprite2D.new()
	interaction.set_script(load("res://InteractionManager.gd"))
	interaction.models = sprites
	root.add_child(sprites)
	root.add_child(interaction)
	interaction.on_state_change()
	assert(interaction.current_select_unit_action == null)
	assert(interaction.current_select_model_action == null)
	interaction.free()
	sprites.free()

func check_orks_army():
	var rules = root.get_node("GlobalRules")
	var library = rules.library
	assert(library.get_state_schema_version() == 28)
	assert(library.get_observation_schema_version() == 28)
	assert(library.get_action_schema_version() == 18)
	var board = RLCBoard.make()
	var faction = RLCArmyFaction.make()
	faction.set_value(4) # orks
	library.army_for_player(board, false).get_faction().set_value(faction.get_value())
	var unit = library.make_infernus_squad()
	library.resize(unit.get_models(), 1)
	var model = library.get(unit.get_models(), 0)
	var keyword = RLCKeyword.make()
	keyword.set_value(61) # appended ORKS keyword
	assert(str(library.as_string_literal(keyword)) == "orks")
	library.append(model.get_keywords(), keyword)
	keyword = RLCKeyword.make()
	keyword.set_value(8) # CHARACTER
	library.append(model.get_keywords(), keyword)
	model.set_has_waaagh(true)
	model.set_has_da_boss(true)
	library.append(board.get_reserve_units(), unit)
	library.identify_units(board)
	library.capture_starting_strengths(board)
	var selection = library.select_orks_warlord(board, false)
	var unit_id = RLCUnitID.make()
	unit_id.get_id().set_value(31)
	assert(not library.can_choose_warlord_unit(selection, board, unit_id))
	unit_id.get_id().set_value(0)
	assert(library.can_choose_warlord_unit(selection, board, unit_id))
	library.assign(rules.state.get_board(), board)
	var unit_action = RLCGameChooseWarlordUnit.make()
	library.assign(unit_action.get_warlord_unit(), unit_id)
	assert(unit_action.members_count() == 1 and unit_action.get_member(0) is RLCUnitID)
	var panel = panel_for(rules, [wrapped(library, unit_action)])
	assert(panel.get_node("ChoiseList").get_child_count() == 1)
	assert(panel.get_node("ChoiseList").get_child(0).text.begins_with(rules.strip_symbols("Warlord unit army 1")))
	panel.free()
	check_offboard_clicks(rules, wrapped(library, unit_action))
	library.choose_warlord_unit(selection, board, unit_id)
	library.assign(rules.state.get_board(), board)
	var model_id = RLCModelID.make()
	var model_action = RLCGameChooseWarlordModel.make()
	library.assign(model_action.get_warlord_model(), model_id)
	assert(model_action.members_count() == 1 and model_action.get_member(0) is RLCModelID)
	panel = panel_for(rules, [wrapped(library, model_action)])
	assert(panel.get_node("ChoiseList").get_child_count() == 1)
	assert(panel.get_node("ChoiseList").get_child(0).text.begins_with(rules.strip_symbols("Warlord:")))
	panel.free()
	check_offboard_clicks(rules, wrapped(library, model_action))
	library.choose_warlord_model(selection, board, model_id)
	assert(library.is_done(selection))
	var actual = library.get(library.get(board.get_reserve_units(), 0).get_models(), 0)
	assert(library.army_for_player(board, false).get_warlord().get_value() == actual.get_identity().get_value())
	keyword = RLCKeyword.make()
	keyword.set_value(62) # WARLORD
	assert(library.has_keyword(actual, keyword))
	var window = RLCTimingWindow.make()
	window.set_value(1) # round_start
	var timing = library.resolve_timing_window(board, window)
	assert(not library.can_finish_timing_rules(timing, board))
	var rule = RLCOrksTimingRule.make()
	rule.set_value(1) # da_boss
	assert(library.can_choose_orks_timing_rule(timing, board, rule))
	library.choose_orks_timing_rule(timing, board, rule)
	assert(library.is_done(timing))
	assert(library.command_points_for_player(board, false).get_value() == 1)
	var phase = RLCBattlePhase.make()
	phase.set_value(1) # command
	library.start_turn_history(board)
	library.begin_phase(board, phase)
	window.set_value(5) # command_start
	timing = library.resolve_timing_window(board, window)
	rule.set_value(0) # war_cry
	assert(library.can_choose_orks_timing_rule(timing, board, rule))
	var timing_action = RLCGameChooseOrksTimingRule.make()
	timing_action.get_orks_rule().set_value(rule.get_value())
	library.assign(rules.state.get_board(), board)
	panel = panel_for(rules, [wrapped(library, timing_action)])
	assert(panel.get_node("ChoiseList").get_child(0).text == rules.strip_symbols("Call War Cry (once per battle)"))
	panel.free()
	library.choose_orks_timing_rule(timing, board, rule)
	assert(library.is_done(timing))
	assert(library.army_for_player(board, false).get_war_cry_used())
	actual = library.get(library.get(board.get_reserve_units(), 0).get_models(), 0)
	assert(library.is_riled_up(actual) and library.effective_invulnerable_save(actual) == 5)
	assert(library.valid_state_foundations(board))
	rules.valid_actions = []
	print("PASS: Godot schema exports, Warlord unit/model buttons, mandatory Da Boss CP and War Cry ownership/status")
	library.free()
	call_deferred("quit", 0)
