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
			elif unwrapped is RLCGameDestroyUnplaceableUnit:
				make_choise("Destroy unplaceable unit", action)
			else:
				make_choise(unwrapped.get_class().substr(7), action)
			added += 1
		if unwrapped.members_count() == 1 and GlobalRules.library.is_enum(unwrapped.get_member(0)):
			make_choise(GlobalRules.library.as_string_literal(unwrapped.get_member(0)), action)
			added += 1
		if unwrapped.members_count() == 1 and unwrapped.get_member(0) is bool:
			var label = GlobalRules.as_str(unwrapped.get_member(0))
			if unwrapped is RLCGameTakeToSkies:
				label = "Take to the skies" if unwrapped.get_member(0) else "Stay grounded"
			if unwrapped is RLCGameWalkerMobile:
				label = "Gain Mobile for this move" if unwrapped.get_member(0) else "Keep current keywords"
			if unwrapped is RLCGameAdvance:
				label = "Advance" if unwrapped.get_member(0) else "Normal move"
			make_choise(label, action)
			added += 1
		# Deployment IDs refer to reserves, not the battlefield models used by
		# the click selector. Offer the actual legal reserve action as a button.
		if unwrapped is RLCGameSelectUnit or unwrapped is RLCGameSelectReserveUnit or unwrapped is RLCGameSelectIngressUnit or unwrapped is RLCGameSelectScoutReserve or unwrapped is RLCGameChooseStrategicReserve:
			var reserve_id = unwrapped.get_member(0).get_id().get_value()
			var reserves = GlobalRules.state.get_board().get_reserve_units()
			var unit = GlobalRules.library.get(reserves, reserve_id)
			var unit_name = RLCLib.convert_string(unit.get_name().get_value())
			var army = 2 if unit.get_owned_by_player1() else 1
			var prefix = "Deploy" if unwrapped is RLCGameSelectUnit else "Reserve"
			if unwrapped is RLCGameSelectScoutReserve:
				prefix = "Scout setup"
			if unwrapped is RLCGameChooseStrategicReserve:
				prefix = "Hold in reserves"
			make_choise(prefix + " army " + str(army) + ": " + unit_name, action)
			added += 1
		if unwrapped is RLCGameSelectWeapon:
			make_choise(GlobalRules.action_to_pretty_string(action), action)
			added += 1
		# Attack groups and melee counts use finite numeric domains. Offer each
		# legal value explicitly; board/model selectors cannot represent them.
		if unwrapped is RLCGameChooseAttackWeapon:
			make_choise("Resolve " + GlobalRules.action_to_pretty_string(action), action)
			added += 1
		if unwrapped is RLCGameAssignAttacks:
			make_choise("Assign " + str(unwrapped.get_member(0).get_value()) + " attacks", action)
			added += 1
		if unwrapped is RLCGameChooseSaveGroup or unwrapped is RLCGameChoosePrecisionGroup:
			var group_id = unwrapped.get_member(0).get_value()
			var prefix = "Precision group " if unwrapped is RLCGameChoosePrecisionGroup else "Allocate group "
			var groups = GlobalRules.state.get_board().get_active_allocation_groups()
			var group = GlobalRules.library.get(groups, group_id)
			var characteristics = "W " + str(group.get_wounds().get_value()) + " Sv " + str(group.get_save().get_value()) + " InSv " + str(group.get_invulnerable().get_value())
			var kind = "Character " if group.get_character() else "Non-character "
			make_choise(prefix + str(group_id + 1) + ": " + kind + characteristics, action)
			added += 1
		if unwrapped is RLCGameRotateModel and unwrapped.get_member(0).get_value() % 90 == 0:
			make_choise("Rotate " + str(unwrapped.get_member(0).get_value()) + " degrees", action)
			added += 1
		if unwrapped is RLCGameSelectReroll:
			make_choise("Re-roll a " + str(unwrapped.get_member(0).get_value()), action)
			added += 1
			

	if added != 0:	
		visible = true

func clear():
	for node in $ChoiseList.get_children():
		node.queue_free()
	visible = false
