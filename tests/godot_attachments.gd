extends SceneTree

func _initialize():
	call_deferred("check_attachments")

func configure(library, unit, code):
	var tag = RLCOrksDatasheet.make()
	tag.set_value(code)
	library.configure_orks_attachment(unit, tag)

func identifier(value):
	var result = RLCUnitID.make()
	result.get_id().set_value(value)
	return result

func wrapped(library, action):
	var result = RLCAnyGameAction.make()
	library.assign(result, action)
	return result

func check_attachments():
	var rules = root.get_node("GlobalRules")
	var library = rules.library
	assert(library.get_state_schema_version() == 38)
	assert(library.get_observation_schema_version() == 38)
	assert(library.get_action_schema_version() == 24)
	var board = RLCBoard.make()
	var bodyguard = library.make_infernus_squad()
	configure(library, bodyguard, 16) # Boyz; fixture profiles only
	var leader = library.make_tantus()
	configure(library, leader, 59) # Warboss
	var support = library.make_octavius()
	configure(library, support, 50) # Painboy
	library.append(board.get_reserve_units(), bodyguard)
	library.append(board.get_reserve_units(), leader)
	library.append(board.get_reserve_units(), support)
	library.identify_units(board)
	var leader_identity = library.get(board.get_reserve_units(), 1).get_identity().get_value()
	var selection = library.attach_leaders(board)
	assert(library.can_attach_unit(selection, board, identifier(1), identifier(0)))
	assert(not library.can_attach_unit(selection, board, identifier(0), identifier(1)))
	assert(not library.can_attach_unit(selection, board, identifier(31), identifier(0)))
	var action = RLCGameAttachUnit.make()
	library.assign(action.get_attach_source(), identifier(1))
	library.assign(action.get_attach_target(), identifier(0))
	assert(action.members_count() == 2)
	assert(action.get_member(0) is RLCUnitID and action.get_member(1) is RLCUnitID)
	library.assign(rules.state.get_board(), board)
	rules.valid_actions = [wrapped(library, action)]
	var panel = VBoxContainer.new()
	panel.set_script(load("res://MultipleChoises.gd"))
	var buttons = VBoxContainer.new()
	buttons.name = "ChoiseList"
	panel.add_child(buttons)
	root.add_child(panel)
	assert(buttons.get_child_count() == 1)
	assert(buttons.get_child(0).text.begins_with(rules.strip_symbols("Attach leader:")))
	panel.free()
	var sprites = Node2D.new()
	var interaction = Sprite2D.new()
	interaction.set_script(load("res://InteractionManager.gd"))
	interaction.models = sprites
	root.add_child(sprites)
	root.add_child(interaction)
	interaction.on_state_change()
	assert(interaction.current_target_unit_action == null)
	assert(interaction.current_select_unit_action == null)
	interaction.free()
	sprites.free()
	library.attach_unit(selection, board, identifier(1), identifier(0))
	assert(board.get_current_decision_maker()) # opponent gets the next choice
	assert(not library.can_attach_unit(selection, board, identifier(1), identifier(0)))
	library.done_attaching(selection, board)
	assert(not board.get_current_decision_maker())
	assert(library.can_attach_unit(selection, board, identifier(1), identifier(0)))
	library.attach_unit(selection, board, identifier(1), identifier(0))
	library.done_attaching(selection, board)
	assert(library.is_done(selection))
	assert(library.size(board.get_reserve_units()) == 1)
	var attached = library.get(board.get_reserve_units(), 0)
	assert(library.size(attached.get_models()) == 7)
	assert(attached.get_starting_strenght().get_value() == 7)
	assert(library.size(attached.get_attached_units()) == 2)
	var component = library.get(attached.get_attached_units(), 0)
	assert(component.get_identity().get_value() == leader_identity)
	assert(component.get_role().get_value() == 1)
	assert(component.get_starting_strength().get_value() == 1)
	assert(library.valid_state_foundations(board))
	rules.valid_actions = []
	print("PASS: Godot schema exports, source-first reserve attachment pairs, separate Leader/Support slots and offboard click suppression")
	library.free()
	call_deferred("quit", 0)
