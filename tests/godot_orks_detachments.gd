extends SceneTree

func _initialize():
	call_deferred("check_detachments")

func press(panel, label):
	for button in panel.get_node("ChoiseList").get_children():
		if not button.is_queued_for_deletion() and button.text == label:
			button.button_down.emit()
			return
	assert(false, "Missing detachment choice: " + label)

func check_detachments():
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
	press(panel, "orks (current units)")
	press(panel, "select detachment: war horde")
	press(panel, "select detachment: brute bosses")
	press(panel, "select detachment: wurrband")
	assert(library.size(library.army_for_player(rules.state.get_board(), false).get_detachments()) == 3)
	press(panel, "enhancement: follow me ladz")
	press(panel, "enhancement unit army 1: beastboss")
	press(panel, "enhancement bearer: beastboss model 1")
	var boss = library.get(rules.state.get_board().get_reserve_units(), 0)
	assert(library.get(boss.get_models(), 0).get_orks_enhancement().get_value() == 4)
	var saved = rules.as_indented_str(rules.state)
	var restored = library.play()
	assert(library.set_state(restored, RLCLib.godot_string_to_rlc_string(saved)))
	rules.set_state(restored)
	press(panel, "finish enhancements")
	press(panel, "warlord unit army 1: beastboss")
	press(panel, "warlord: beastboss model 1")
	assert(library.get_current_player(rules.state) == 1)
	print("PASS: Godot schema exports, three detachments, option unit/model buttons and pending save")
	panel.queue_free()
	library.free()
	quit()
