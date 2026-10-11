extends VBoxContainer

var active = true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalRules.on_state_changed.connect(on_state_change)
	visible = false
	on_state_change()
	
func make_choise(name: String, action: RLCAnyGameAction):
	var button = Button.new()
	button.add_theme_font_size_override("font_size", 30)
	button.text = GlobalRules.strip_symbols(name)
	button.button_down.connect(func(): GlobalRules.apply_action(action))
	$ChoiseList.add_child(button)

func on_state_change():
	clear()
	if not active:
		return
	var added = 0
	for action in GlobalRules.valid_actions:
		var unwrapped = action.unwrap()
		if unwrapped.members_count() == 0:
			if unwrapped is RLCGameDoneDeploying:
				# This finishes the current decision owner's deployment, not
				# the army that placed the preceding model.
				var army = GlobalRules.library.get_current_player(GlobalRules.state) + 1
				make_choise("Done deploying army " + str(army), action)
			else:
				make_choise(unwrapped.get_class().substr(7), action)
			added += 1
		if unwrapped.members_count() == 1 and GlobalRules.library.is_enum(unwrapped.get_member(0)):
			make_choise(GlobalRules.library.as_string_literal(unwrapped.get_member(0)), action)
			added += 1
		if unwrapped.members_count() == 1 and unwrapped.get_member(0) is bool:
			make_choise(GlobalRules.as_str(unwrapped.get_member(0)), action)
			added += 1
		# Deployment IDs refer to reserves, not the battlefield models used by
		# the click selector. Offer the actual legal reserve action as a button.
		if unwrapped is RLCGameSelectUnit:
			var reserve_id = unwrapped.get_member(0).get_id().get_value()
			var reserves = GlobalRules.state.get_board().get_reserve_units()
			var unit = GlobalRules.library.get(reserves, reserve_id)
			var unit_name = RLCLib.convert_string(unit.get_name().get_value())
			var army = 2 if unit.get_owned_by_player1() else 1
			make_choise("Deploy army " + str(army) + ": " + unit_name, action)
			added += 1
		if unwrapped is RLCGameSelectWeapon:
			make_choise(GlobalRules.action_to_pretty_string(action), action)
			added += 1
			

	if added != 0:	
		visible = true

func clear():
	for node in $ChoiseList.get_children():
		node.queue_free()
	visible = false
