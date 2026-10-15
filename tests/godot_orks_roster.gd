extends SceneTree

func _initialize():
	call_deferred("check_roster")

func press(panel, label):
	for button in panel.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == label:
			button.button_down.emit()
			return
	assert(false, "Missing current-roster choice: " + label)

func check_roster():
	var rules = root.get_node("GlobalRules")
	var library = rules.library
	assert(library.get_state_schema_version() == 40)
	assert(library.get_action_schema_version() == 26)
	var panel = VBoxContainer.new()
	panel.set_script(load("res://MultipleChoises.gd"))
	var buttons = VBoxContainer.new()
	buttons.name = "ChoiseList"
	panel.add_child(buttons)
	root.add_child(panel)
	print("CHECK: selecting current Orks roster")
	press(panel, rules.strip_symbols("Orks (current units)"))
	assert(library.size(rules.state.get_board().get_reserve_units()) == 4)
	var hogs = library.get(rules.state.get_board().get_reserve_units(), 1)
	assert(library.size(hogs.get_models()) == 4)
	assert(library.base_size(library.get(hogs.get_models(), 0).get_profile()) == 90.0)
	press(panel, "select detachment: war horde")
	press(panel, "finish detachment selection")
	if rules.can_apply(RLCGameFinishOrksOptions.make()):
		press(panel, "finish enhancements")
	press(panel, "warlord unit army 1: beastboss")
	var restored = library.play()
	assert(library.set_state(restored, RLCLib.godot_string_to_rlc_string(rules.as_indented_str(rules.state))))
	rules.set_state(restored)
	press(panel, "warlord: beastboss model 1")
	print("CHECK: first Warlord and pending save completed")
	assert(library.get_current_player(rules.state) == 1)
	press(panel, rules.strip_symbols("Orks (current units)"))
	press(panel, "finish detachment selection")
	if rules.can_apply(RLCGameFinishOrksOptions.make()):
		press(panel, "finish enhancements")
	press(panel, "warlord unit army 2: beastboss")
	press(panel, "warlord: beastboss model 1")
	print("CHECK: both roster and Warlord selections completed")
	var attach = RLCGameAttachUnit.make()
	attach.get_member(0).get_id().set_value(0)
	attach.get_member(1).get_id().set_value(2)
	assert(rules.can_apply(attach))
	rules.apply_action(attach)
	var combined = library.get(rules.state.get_board().get_reserve_units(), 1)
	assert(library.size(combined.get_models()) == 11)
	assert(library.army_for_player(rules.state.get_board(), false).get_warlord().get_value() == library.get(combined.get_models(), 10).get_identity().get_value())
	# Formation choices alternate after each action, including an attachment.
	attach = RLCGameAttachUnit.make()
	attach.get_member(0).get_id().set_value(3)
	attach.get_member(1).get_id().set_value(5)
	assert(rules.can_apply(attach))
	rules.apply_action(attach)
	rules.apply_action(RLCGameDoneAttaching.make())
	rules.apply_action(RLCGameDoneAttaching.make())
	assert(library.valid_state_foundations(rules.state.get_board()))
	# Production reserve/passive initialization retains the selected package
	# and current source registrations after both formation choices.
	assert(library.size(rules.state.get_board().get_source_instances()) >= 6)
	print("CHECK: both current attachments and registrations completed")
	# Explicit battlefield fixture isolates the native duplicate chooser UI:
	# current Beastboss conditional2 versus selected War Horde unconditional1.
	var board = RLCBoard.make()
	var army = library.army_for_player(board, false)
	army.get_faction().set_value(4)
	var detachment = RLCOrksDetachment.make()
	detachment.set_value(1)
	assert(library.record_detachment(army, detachment))
	library.append(board.get_units(), library.make_orks_beastboss())
	var source = RLCUnitID.make()
	var available = library.model_weapon_rules(board, source, 0, 1)
	assert(library.size(available) == 2)
	var choice = library.choose_weapon_abilities(board, available)
	library.assign(rules.state.get_board(), board)
	var action = RLCGameChooseWeaponAbility.make()
	action.get_member(0).set_value(1)
	var wrapped = RLCAnyGameAction.make()
	library.assign(wrapped, action)
	rules.valid_actions = [wrapped]
	panel.on_state_change()
	var found = false
	for button in buttons.get_children():
		if not button.is_queued_for_deletion() and "sustained" in button.text and "1" in button.text:
			found = true
	assert(found)
	assert(library.can_choose_weapon_ability(choice, board, action.get_member(0)))
	library.choose_weapon_ability(choice, board, action.get_member(0))
	assert(library.is_done(choice))
	var chosen = library.get(choice.get_chosen(), 0)
	assert(chosen.get_parameter().get_value() == 1)
	print("PASS: Godot schema exports, current Orks roster buttons, both Warlords/attachments, pending save, registrations and War Horde duplicate-choice control")
	panel.free()
	library.free()
	call_deferred("quit", 0)
