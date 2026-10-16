extends SceneTree

# These production bindings expose actual current cards and preserve the
# editor's one-UnitID/one-ModelID action discovery. Sources: Orks card URLs
# in src/factions/orks/datasheets.rl and src/factions/orks/README.md.
func _initialize():
	call_deferred("check_units")

func panel_for(rules, library, action):
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
	return panel

func check_units():
	var rules = root.get_node("GlobalRules")
	var library = rules.library
	assert(library.get_state_schema_version() == 42)
	assert(library.get_observation_schema_version() == 42)
	assert(library.get_action_schema_version() == 26)
	var gun = RLCOrksMegaMekGun.make()
	var extra = RLCOrksMegaMekExtra.make()
	extra.set_value(2) # force_field
	var pulsa = RLCOrksTankbustaExtra.make()
	pulsa.set_value(2)
	var units = [library.make_orks_flash_gitz(4), library.make_orks_meganobz(2), library.make_orks_mek(), library.make_orks_big_mek(false, false), library.make_orks_big_mek_in_mega_armour(gun, extra), library.make_orks_big_mek_with_shokk_attack_gun(), library.make_orks_painboy(), library.make_orks_painboss(), library.make_orks_breaka_boyz(false, 5, 5), library.make_orks_tankbustas(false, pulsa, 0), library.make_orks_warboss_in_mega_armour(), library.make_orks_gretchin(10), library.make_orks_runtherd(), library.make_orks_zodgrod_wortsnagga()]
	var counts = [5, 2, 1, 1, 1, 1, 1, 1, 6, 6, 1, 10, 1, 1]
	var board = RLCBoard.make()
	for index in range(units.size()):
		assert(library.size(units[index].get_models()) == counts[index])
		library.append(board.get_reserve_units(), units[index])
	library.identify_units(board)
	library.capture_starting_strengths(board)
	library.register_orks_passive_rules(board)
	library.register_orks_datasheet_sources(board)
	assert(library.valid_state_foundations(board))
	assert(library.orks_passenger_space(units[11]) == 5)
	library.assign(rules.state.get_board(), board)
	var restored = library.play()
	assert(library.set_state(restored, RLCLib.godot_string_to_rlc_string(rules.as_indented_str(rules.state))))
	assert(library.size(restored.get_board().get_reserve_units()) == 14)
	var combat = RLCBoard.make()
	library.append(combat.get_units(), units[9])
	library.append(combat.get_units(), library.make_orks_killa_kans(3))
	library.get(combat.get_units(), 1).set_owned_by_player1(true)
	library.identify_units(combat)
	library.get(library.get(combat.get_units(), 0).get_models(), 0).get_position().get_x().set_value(5)
	library.get(library.get(combat.get_units(), 0).get_models(), 0).get_position().get_y().set_value(5)
	for index in range(3):
		var position = library.get(library.get(combat.get_units(), 1).get_models(), index).get_position()
		position.get_x().set_value(10 + index * 3)
		position.get_y().set_value(5)
	var phase = RLCBattlePhase.make()
	phase.set_value(3)
	library.begin_phase(combat, phase)
	var source = RLCUnitID.make()
	var selection = library.orks_pulsa_selection(combat, source)
	assert(library.can_use_pulsa_rokkit(selection, combat, true))
	library.use_pulsa_rokkit(selection, combat, true)
	var target = RLCUnitID.make()
	target.get_id().set_value(1)
	assert(library.can_choose_pulsa_target(selection, combat, target))
	library.choose_pulsa_target(selection, combat, target)
	assert(library.is_done(selection))
	assert(library.orks_pulsa_applies(combat, library.get(combat.get_units(), 0), library.get(combat.get_units(), 1).get_identity()))
	library.assign(rules.state.get_board(), combat)
	var actions = [RLCGameChooseMekRepairUnit.make(), RLCGameChoosePainbossHealingUnit.make(), RLCGameChoosePulsaTarget.make(), RLCGameChooseImpetusTarget.make(), RLCGameChooseRokkitBarrageTarget.make(), RLCGameChooseMekRepairModel.make(), RLCGameChooseHealedModel.make(), RLCGameChoosePunishedGretchin.make()]
	var labels = ["Clever Know-wotz", "Push Dat Bit Back In", "Pulsa Rokkit", "Krushin' Impetus", "Rokkit Barrage", "Repair vehicle model 1", "Heal model 1", "Destroy Gretchin 1"]
	for index in range(actions.size()):
		assert(actions[index].members_count() == 1)
		var panel = panel_for(rules, library, actions[index])
		assert(rules.strip_symbols(labels[index]) in panel.get_node("ChoiseList").get_child(0).text)
		panel.free()
	print("PASS: Godot schema exports, fourteen current Orks constructors, source/save round trip, Gretchin capacity, actual Pulsa choice and eight named selectors")
	library.free()
	call_deferred("quit", 0)
