extends SceneTree

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
	assert(library.get_state_schema_version() == 45)
	assert(library.get_observation_schema_version() == 45)
	assert(library.get_action_schema_version() == 27)
	var units = [library.make_orks_boyz(1, 9), library.make_orks_nobz(5), library.make_orks_warboss(), library.make_orks_bigboss(), library.make_orks_bannernob(), library.make_orks_stormboyz(4, true), library.make_orks_warbikers(2), library.make_orks_deff_dread(), library.make_orks_killa_kans(3), library.make_orks_big_mek_dakkarig(), library.make_orks_beastboss_on_squigosaur(true), library.make_orks_mozrog_skragbad()]
	var counts = [10, 5, 1, 1, 1, 5, 3, 1, 3, 1, 1, 1]
	var board = RLCBoard.make()
	for index in range(units.size()):
		assert(library.size(units[index].get_models()) == counts[index])
		library.append(board.get_reserve_units(), units[index])
	library.identify_units(board)
	assert(library.valid_state_foundations(board))
	var nob = library.get(units[6].get_models(), 0)
	assert(library.base_size(nob.get_profile()) == 75.0)
	assert(library.profile_base_width(nob.get_profile()) == 42.0)
	assert(not nob.get_geometry().get_unsupported_footprint())
	var physical_board = RLCBoard.make()
	library.append(physical_board.get_units(), units[6])
	library.identify_units(physical_board)
	var physical_source = RLCUnitID.make()
	var primary = library.make_declared_weapon(physical_board, physical_source, 0, 0)
	var alternate = library.make_declared_weapon(physical_board, physical_source, 0, 1)
	assert(primary.get_physical_group().get_value() == 1)
	assert(primary.get_physical_group().get_value() == alternate.get_physical_group().get_value())
	var mozrog = library.get(units[11].get_models(), 0)
	assert(library.invuln_save(mozrog.get_profile()) == 4)
	assert(library.feel_no_pain(mozrog.get_profile()) == 5)
	var hunter = library.get(mozrog.get_weapons(), 3).get_profile()
	assert(library.stat_dice_count(library.damage(hunter)) == 1)
	assert(library.stat_intrinsic_constant(library.damage(hunter)) == 1)
	library.assign(rules.state.get_board(), board)
	var restored = library.play()
	assert(library.set_state(restored, RLCLib.godot_string_to_rlc_string(rules.as_indented_str(rules.state))))
	assert(library.size(restored.get_board().get_reserve_units()) == 12)
	var source = RLCUnitID.make()
	var combat = RLCBoard.make()
	library.append(combat.get_units(), units[1])
	library.identify_units(combat)
	var phase = RLCBattlePhase.make()
	phase.set_value(3) # Shooting
	library.begin_phase(combat, phase)
	var choice = library.orks_datasheet_selection(combat, source)
	assert(library.can_use_ammo_runts(choice, combat, true))
	library.use_ammo_runts(choice, combat, true)
	assert(library.is_done(choice))
	assert(not library.orks_ammo_available(combat, source, false))
	for action in [RLCGameUseAmmoRunts.make(), RLCGameUseBossAmmoRunt.make(), RLCGameUseRokkitCharge.make()]:
		assert(action.members_count() == 1 and action.get_member(0) is bool)
		var panel = panel_for(rules, library, action)
		var label = panel.get_node("ChoiseList").get_child(0).text
		assert("keep" in label or "rokkit" in label)
		panel.free()
	var ammo_yes = RLCGameUseAmmoRunts.make()
	ammo_yes.set_ammo_use(true)
	var boss_yes = RLCGameUseBossAmmoRunt.make()
	boss_yes.set_boss_ammo_use(true)
	var rokkit_yes = RLCGameUseRokkitCharge.make()
	rokkit_yes.set_rokkit_use(true)
	var expected = ["Use Ammo Runts (+1 ranged hit this phase)", "Use Boss Ammo Runt (bearer +1 ranged hit)", "Rokkit Charge (+1 A/S, Hazardous)"]
	var accepted_actions = [ammo_yes, boss_yes, rokkit_yes]
	for index in range(3):
		var panel = panel_for(rules, library, accepted_actions[index])
		assert(panel.get_node("ChoiseList").get_child(0).text == rules.strip_symbols(expected[index]))
		panel.free()
	print("PASS: Godot schema exports, twelve current Orks constructors, physical profiles, circle metadata, compound damage, source decisions, production labels and saves")
	library.free()
	call_deferred("quit", 0)
