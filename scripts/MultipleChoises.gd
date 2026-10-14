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
			elif unwrapped is RLCGamePickMorgrimButcha:
				make_choise("Orks (current units)", action)
			elif unwrapped is RLCGameFinishDetachmentSelection:
				make_choise("Finish detachment selection", action)
			elif unwrapped is RLCGameFinishOrksOptions:
				make_choise("Finish enhancements", action)
			elif unwrapped is RLCGameCancelOrksOption or unwrapped is RLCGameCancelOrksOptionBearer:
				make_choise("Cancel enhancement selection", action)
			else:
				make_choise(unwrapped.get_class().substr(7), action)
			added += 1
		if unwrapped.members_count() == 1 and GlobalRules.library.is_enum(unwrapped.get_member(0)):
			var label = str(GlobalRules.library.as_string_literal(unwrapped.get_member(0))).replace("_", " ")
			if unwrapped is RLCGameChooseShootingKind:
				label += " shooting"
			if unwrapped is RLCGameChooseFightKind:
				label += " fight"
			if unwrapped is RLCGameChooseOrksTimingRule:
				label = "Call War Cry (once per battle)" if unwrapped.get_member(0).get_value() == 0 else "Da Boss: gain 1 CP"
			if unwrapped is RLCGameChooseOrksDetachment:
				label = "Select detachment: " + label
			if unwrapped is RLCGameChooseOrksOption:
				label = ("Upgrade: " if GlobalRules.library.orks_is_upgrade(unwrapped.get_member(0)) else "Enhancement: ") + label
			if unwrapped is RLCGameChooseOrksAttackStratagem or unwrapped is RLCGameChooseOrksDefenceStratagem or unwrapped is RLCGameChooseOrksMoveStratagem or unwrapped is RLCGameChooseOrksWindowStratagem or unwrapped is RLCGameChooseOrksPhaseCard or unwrapped is RLCGameChooseOrksAttackReactionCard:
				label = label.trim_prefix("orks ")
				label += " (2 CP)" if label == "infested war zone" else " (1 CP)"
			if unwrapped is RLCGameChooseArtilleristMode:
				label = ["Lethal Hits", "Sustained Hits 1", "Lethal + Sustained Hits 1 + Hazardous"][unwrapped.get_member(0).get_value()]
			make_choise(label, action)
			added += 1
		if unwrapped.members_count() == 1 and unwrapped.get_member(0) is bool:
			var label = GlobalRules.as_str(unwrapped.get_member(0))
			if unwrapped is RLCGameTakeToSkies or unwrapped is RLCGameChargeTakeToSkies:
				label = "Take to the skies" if unwrapped.get_member(0) else "Stay grounded"
			if unwrapped is RLCGameWalkerMobile:
				label = "Gain Mobile for this move" if unwrapped.get_member(0) else "Keep current keywords"
			if unwrapped is RLCGameUseLethalHits:
				label = "Automatically wound with this critical hit" if unwrapped.get_member(0) else "Roll to wound with this critical hit"
			if unwrapped is RLCGameApplyAttackModifier:
				var detail = GlobalRules.library.convert_string(GlobalRules.library.modifier_choice_label(GlobalRules.state.get_board()))
				label = ("Apply " if unwrapped.get_member(0) else "Ignore ") + detail
			if unwrapped is RLCGameAdvance:
				label = "Advance" if unwrapped.get_member(0) else "Normal move"
			if unwrapped is RLCGameChooseHulkingProtection:
				label = "All ranged attacks: -1 to wound (2 CP)" if unwrapped.get_member(0) else "Only S greater than T: -1 to wound (1 CP)"
			if unwrapped is RLCGameChooseButtonDice:
				label = "Roll two D6 and one extra Hazardous test" if unwrapped.get_member(0) else "Roll one D6"
			if unwrapped is RLCGameUseUnstoppableAdvance:
				label = "Use Advance result 6" if unwrapped.get_member(0) else "Keep rolled Advance result"
			if unwrapped is RLCGameChooseAssaultDisembark:
				label = "Assault Disembark: may charge" if unwrapped.get_member(0) else "Rapid Disembark: cannot charge"
			make_choise(label, action)
			added += 1
		# Core effects coexist with ordinary one-UnitID phase selectors; explicit
		# source buttons let players choose the effect before clicking its bearer.
		if unwrapped is RLCGameUseExplosives or unwrapped is RLCGameCounteroffensive or unwrapped is RLCGameSmokescreen:
			var source_id = unwrapped.get_member(0).get_id().get_value()
			var source_unit = GlobalRules.library.get(GlobalRules.state.get_board().get_units(), source_id)
			var source_name = RLCLib.convert_string(source_unit.get_name().get_value())
			var effect = "Explosives (1 CP)" if unwrapped is RLCGameUseExplosives else "Smokescreen (1 CP)"
			if unwrapped is RLCGameCounteroffensive:
				effect = "Counteroffensive (2 CP)"
			make_choise(effect + ": " + source_name, action)
			added += 1
		if unwrapped is RLCGameAttachUnit:
			var source_id = unwrapped.get_member(0).get_id().get_value()
			var target_id = unwrapped.get_member(1).get_id().get_value()
			var reserves = GlobalRules.state.get_board().get_reserve_units()
			var leader = GlobalRules.library.get(reserves, source_id)
			var bodyguard = GlobalRules.library.get(reserves, target_id)
			var role = GlobalRules.library.as_string_literal(leader.get_attachment_role())
			make_choise("Attach " + str(role) + ": " + RLCLib.convert_string(leader.get_name().get_value()) + " to " + RLCLib.convert_string(bodyguard.get_name().get_value()), action)
			added += 1
		# Enhancement selections address the reserve roster before attachments.
		# Keep the native one-ModelID shape, but label it from that bank.
		if unwrapped is RLCGameChooseOrksOptionBearer:
			var model_id = unwrapped.get_member(0).get_id().get_value()
			var reserve_id = GlobalRules.state.get_board().get_orks_selected_unit().get_id().get_value()
			var roster_unit = GlobalRules.library.get(GlobalRules.state.get_board().get_reserve_units(), reserve_id)
			make_choise("Enhancement bearer: " + RLCLib.convert_string(roster_unit.get_name().get_value()) + " model " + str(model_id + 1), action)
			added += 1
		if unwrapped is RLCGameChooseHealedCasualty or unwrapped is RLCGameChooseSurlyCasualty:
			var casualty_id = unwrapped.get_member(0).get_id().get_value()
			make_choise("Return original casualty " + str(casualty_id + 1), action)
			added += 1
		if unwrapped is RLCGameChooseWarlordModel:
			var model_id = unwrapped.get_member(0).get_id().get_value()
			var reserve_id = GlobalRules.state.get_board().get_selected_warlord_unit().get_id().get_value()
			var roster_unit = GlobalRules.library.get(GlobalRules.state.get_board().get_reserve_units(), reserve_id)
			make_choise("Warlord: " + RLCLib.convert_string(roster_unit.get_name().get_value()) + " model " + str(model_id + 1), action)
			added += 1
		# Deployment IDs refer to reserves, not the battlefield models used by
		# the click selector. Offer the actual legal reserve action as a button.
		if unwrapped is RLCGameChooseOrksOptionUnit or unwrapped is RLCGameChooseWarlordUnit or unwrapped is RLCGameSelectUnit or unwrapped is RLCGameSelectReserveUnit or unwrapped is RLCGameSelectIngressUnit or unwrapped is RLCGameSelectScoutReserve or unwrapped is RLCGameChooseStrategicReserve or unwrapped is RLCGameChooseFormationPassenger or unwrapped is RLCGameChooseFormationTransport:
			var reserve_id = unwrapped.get_member(0).get_id().get_value()
			var reserves = GlobalRules.state.get_board().get_reserve_units()
			var unit = GlobalRules.library.get(reserves, reserve_id)
			var unit_name = RLCLib.convert_string(unit.get_name().get_value())
			var army = 2 if unit.get_owned_by_player1() else 1
			var prefix = "Deploy" if unwrapped is RLCGameSelectUnit else "Reserve"
			if unwrapped is RLCGameChooseOrksOptionUnit:
				prefix = "Enhancement unit"
			if unwrapped is RLCGameChooseWarlordUnit:
				prefix = "Warlord unit"
			if unwrapped is RLCGameSelectScoutReserve:
				prefix = "Scout setup"
			if unwrapped is RLCGameChooseStrategicReserve:
				prefix = "Hold in reserves"
			if unwrapped is RLCGameChooseFormationPassenger:
				prefix = "Embark passenger"
			if unwrapped is RLCGameChooseFormationTransport:
				prefix = "Choose carrier"
			make_choise(prefix + " army " + str(army) + ": " + unit_name, action)
			added += 1
		# Parallel same-shape faction choices get explicit source buttons, so
		# the click autodetector cannot hide a support/reaction selector.
		if unwrapped is RLCGameUseDreadherderSupport or unwrapped is RLCGameUseOrksMovementSupport or unwrapped is RLCGameChooseOrksPackageSource or unwrapped is RLCGameChooseOrksAttackReactionUnit or unwrapped is RLCGameChooseOrksMoveReactionUnit or unwrapped is RLCGameChooseMobMentalitySource:
			var source_id = unwrapped.get_member(0).get_id().get_value()
			var source_unit = GlobalRules.library.get(GlobalRules.state.get_board().get_units(), source_id)
			var label = "Movement abilities" if unwrapped is RLCGameUseOrksMovementSupport else "Resolve detachment rule"
			if unwrapped is RLCGameChooseOrksAttackReactionUnit or unwrapped is RLCGameChooseOrksMoveReactionUnit:
				label = "Reaction unit"
			if unwrapped is RLCGameUseDreadherderSupport:
				label = "Dreadherder"
			if unwrapped is RLCGameChooseMobMentalitySource:
				label = "Mob Mentality (1 CP)"
			make_choise(label + ": " + RLCLib.convert_string(source_unit.get_name().get_value()), action)
			added += 1
		if unwrapped is RLCGameChooseOrksOffboardUnit or unwrapped is RLCGameChooseOffboardDreadUnit:
			var slot = unwrapped.get_member(0).get_id().get_value()
			var bank = GlobalRules.state.get_board().get_orks_support_bank().get_value()
			var units = GlobalRules.state.get_board().get_reserve_units() if bank == 1 else GlobalRules.state.get_board().get_embarked_units()
			var unit = GlobalRules.library.get(units, slot)
			make_choise("Own-unit ability: " + RLCLib.convert_string(unit.get_name().get_value()), action)
			added += 1
		if unwrapped is RLCGameChooseOffboardMortalModel:
			var model_id = unwrapped.get_member(0).get_id().get_value()
			make_choise("Offboard mortal wound: model " + str(model_id + 1), action)
			added += 1
		# Embarked selectors address the passenger bank, never battlefield IDs.
		if unwrapped is RLCGameSelectDisembarkingUnit or unwrapped is RLCGameChooseEmergencyPassenger or unwrapped is RLCGameSelectFiringDeckPassenger:
			var passenger_id = unwrapped.get_member(0).get_id().get_value()
			var passenger = GlobalRules.library.get(GlobalRules.state.get_board().get_embarked_units(), passenger_id)
			var passenger_name = RLCLib.convert_string(passenger.get_name().get_value())
			var prefix = "Disembark" if unwrapped is RLCGameSelectDisembarkingUnit else "Emergency disembark"
			if unwrapped is RLCGameSelectFiringDeckPassenger:
				prefix = "Firing Deck passenger"
			make_choise(prefix + ": " + passenger_name, action)
			added += 1
		# Offboard models cannot be selected by clicking old battlefield bases.
		if unwrapped is RLCGameChooseFormationCarrierModel or unwrapped is RLCGameSelectFiringDeckModel or unwrapped is RLCGameSelectDisembarkingModel:
			var selected_model = unwrapped.get_member(0).get_id().get_value()
			make_choise("Choose model " + str(selected_model + 1), action)
			added += 1
		if unwrapped is RLCGameSelectFiringDeckWeapon:
			var board = GlobalRules.state.get_board()
			var passenger = GlobalRules.library.get(board.get_embarked_units(), board.get_selected_passenger_bank().get_id().get_value())
			var model = GlobalRules.library.get(passenger.get_models(), board.get_selected_passenger_model().get_id().get_value())
			var weapon = GlobalRules.library.get(model.get_weapons(), unwrapped.get_member(0).get_value())
			make_choise("Firing Deck: " + str(GlobalRules.library.as_string_literal(weapon)).replace("_", " "), action)
			added += 1
		if unwrapped is RLCGameChooseDestructionUnit:
			var dying_id = unwrapped.get_member(0).get_id().get_value()
			var dying_unit = GlobalRules.library.get(GlobalRules.state.get_board().get_units(), dying_id)
			var offboard_death = dying_unit.get_off_battlefield()
			for dying_model_id in range(GlobalRules.library.size(dying_unit.get_models())):
				offboard_death = offboard_death or GlobalRules.library.get(dying_unit.get_models(), dying_model_id).get_off_battlefield()
			if offboard_death:
				make_choise("Resolve offboard destruction: " + RLCLib.convert_string(dying_unit.get_name().get_value()), action)
				added += 1
		# Hazard allocation/destruction can occur before passengers are placed.
		if unwrapped is RLCGameSelectMortalModel or unwrapped is RLCGameResolveDestructionModel:
			var allocation_board = GlobalRules.state.get_board()
			var allocation_unit = GlobalRules.library.get(allocation_board.get_units(), allocation_board.get_attack_info().get_target_unit_id().get_id().get_value())
			var allocation_model_id = unwrapped.get_member(0).get_id().get_value()
			var allocation_model = GlobalRules.library.get(allocation_unit.get_models(), allocation_model_id)
			if allocation_unit.get_off_battlefield() or allocation_model.get_off_battlefield():
				make_choise("Allocate offboard model " + str(allocation_model_id + 1), action)
				added += 1
		if unwrapped is RLCGameChooseWeaponAbility:
			var instance = unwrapped.get_member(0).get_value()
			var ability = GlobalRules.library.get(GlobalRules.state.get_board().get_pending_weapon_abilities(), instance)
			var label = str(GlobalRules.library.as_string_literal(ability.get_kind())).replace("_", " ")
			if ability.get_parameter().get_value() > 0:
				label += " " + str(ability.get_parameter().get_value())
			# Appendix02.05.01: preserve AND, OR and exclusions in condition labels.
			var required: PackedStringArray = []
			var alternatives: PackedStringArray = []
			var excluded: PackedStringArray = []
			for entry in range(GlobalRules.library.weapon_ability_condition_count(ability)):
				var keyword = str(GlobalRules.library.as_string_literal(GlobalRules.library.weapon_ability_condition_keyword(ability, entry))).replace("_", " ")
				var clause = GlobalRules.library.weapon_ability_condition_clause(ability, entry).get_value()
				if clause == 0:
					required.append(keyword)
				elif clause == 1:
					alternatives.append(keyword)
				else:
					excluded.append(keyword)
			var conditions: PackedStringArray = []
			if not required.is_empty():
				conditions.append(" and ".join(required))
			if not alternatives.is_empty():
				var either = " or ".join(alternatives)
				conditions.append("(" + either + ")" if alternatives.size() > 1 else either)
			if not conditions.is_empty():
				label += " against " + " and ".join(conditions)
			if not excluded.is_empty():
				label += "; excluding " + " or ".join(excluded)
			make_choise(label, action)
			added += 1
		if unwrapped is RLCGameSelectWeapon:
			make_choise(GlobalRules.action_to_pretty_string(action), action)
			added += 1
		# Attack groups and melee counts use finite numeric domains. Offer each
		# legal value explicitly; board/model selectors cannot represent them.
		# Source instances use a bounded source selector, never a board UnitID.
		if unwrapped is RLCGameChooseSourceEvent or unwrapped is RLCGameChooseWindowSource or unwrapped is RLCGameChooseMovementSource:
			make_choise("Resolve " + GlobalRules.action_to_pretty_string(action), action)
			added += 1
		# Targeted current Orks effects retain one-UnitID click discovery and also
		# offer named buttons, so the selected effect is explicit to the player.
		if unwrapped is RLCGameChooseKeepHuntinTarget or unwrapped is RLCGameChooseBombSquigTarget or unwrapped is RLCGameChooseMobbedTarget:
			var target_id = unwrapped.get_member(0).get_id().get_value()
			var target_unit = GlobalRules.library.get(GlobalRules.state.get_board().get_units(), target_id)
			var effect = "Keep Huntin'" if unwrapped is RLCGameChooseKeepHuntinTarget else "Bomb Squig"
			if unwrapped is RLCGameChooseMobbedTarget:
				effect = "Mobbed: Battle-shock"
			make_choise(effect + ": " + RLCLib.convert_string(target_unit.get_name().get_value()), action)
			added += 1
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
		if (unwrapped is RLCGameRotateModel or unwrapped is RLCGameRotateChargeModel or unwrapped is RLCGameRotateMeleeModel) and unwrapped.get_member(0).get_value() % 90 == 0:
			make_choise("Rotate " + str(unwrapped.get_member(0).get_value()) + " degrees", action)
			added += 1
		if unwrapped is RLCGameChooseMeleeObjective:
			make_choise("Consolidate to objective " + str(unwrapped.get_member(0).get_value() + 1), action)
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
