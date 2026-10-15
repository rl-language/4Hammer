extends SceneTree

func _initialize():
	call_deferred("check_muster")

func button_label(rules, library, action):
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
	var label = buttons.get_child(0).text
	panel.free()
	return label

func check_muster():
	var rules = root.get_node("GlobalRules")
	var library = rules.library
	assert(library.get_state_schema_version() == 39)
	assert(library.get_action_schema_version() == 25)
	var game = library.play()
	library.pick_custom_orks(game)
	library.finish_detachment_selection(game)
	assert(not library.can_finish_orks_roster(game))
	var sheet = RLCOrksDatasheet.make()
	sheet.set_value(59) # Warboss, source catalog code
	library.choose_orks_muster_unit(game, sheet)
	var field = RLCOrksMusterField.make()
	field.set_value(2) # primary weapon
	library.choose_orks_muster_field(game, field)
	var encoded = rules.as_indented_str(game)
	var restored = library.play()
	assert(library.set_state(restored, RLCLib.godot_string_to_rlc_string(encoded)))
	var value = RLCBIntT0T21T.make()
	value.set_value(2) # Kustom Shoota
	assert(library.can_choose_orks_muster_value(restored, value))
	library.choose_orks_muster_value(restored, value)
	library.add_orks_muster_unit(restored)
	assert(library.can_finish_orks_roster(restored))
	# Start a Boyz draft so field/model buttons use the actual active frame.
	sheet.set_value(16)
	library.choose_orks_muster_unit(restored, sheet)
	library.assign(rules.state, restored)
	assert(button_label(rules, library, RLCGamePickCustomOrks.make()) == rules.strip_symbols("Orks (custom roster)"))
	var pick = RLCGameChooseOrksMusterUnit.make()
	pick.get_member(0).set_value(16)
	assert(button_label(rules, library, pick) == rules.strip_symbols("Add Orks unit: Boyz"))
	var field_action = RLCGameChooseOrksMusterField.make()
	field_action.get_member(0).set_value(2)
	assert(button_label(rules, library, field_action) == "weapons")
	var model_action = RLCGameSelectOrksMusterModel.make()
	model_action.get_member(0).get_id().set_value(1)
	assert(button_label(rules, library, model_action) == "equipment for model 2")
	library.choose_orks_muster_field(rules.state, field)
	var value_action = RLCGameChooseOrksMusterValue.make()
	value_action.get_member(0).set_value(1)
	assert(button_label(rules, library, value_action) == "power klaw")
	var remove = RLCGameRemoveOrksMusterUnit.make()
	remove.get_member(0).get_id().set_value(0)
	assert(button_label(rules, library, remove) == rules.strip_symbols("Remove from roster: Warboss"))
	assert(button_label(rules, library, RLCGameAddOrksMusterUnit.make()) == "add unit to roster")
	assert(button_label(rules, library, RLCGameCancelOrksMusterUnit.make()) == "cancel unit")
	assert(button_label(rules, library, RLCGameFinishOrksRoster.make()) == "finish orks roster")
	# Draft selectors must never be interpreted as battlefield model/unit IDs.
	var interaction = Sprite2D.new()
	interaction.set_script(load("res://InteractionManager.gd"))
	interaction.models = Node.new()
	interaction.add_child(interaction.models)
	root.add_child(interaction)
	button_label(rules, library, model_action)
	interaction.on_state_change()
	assert(interaction.current_select_model_action == null)
	button_label(rules, library, remove)
	interaction.on_state_change()
	assert(interaction.current_select_unit_action == null)
	interaction.free()
	print("PASS: Godot schema exports, public custom roster transitions, draft save/restore and nine named/bank controls")
	library.free()
	quit(0)
