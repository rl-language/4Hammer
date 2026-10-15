extends SceneTree

# Current25-card source adapters and their new enum/bank/boolean decisions.
# Native regressions exercise all equipment combinations and rule consumers.
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
	assert(library.get_state_schema_version() == 35)
	assert(library.get_observation_schema_version() == 35)
	assert(library.get_action_schema_version() == 23)
	# Source identities for every remaining standard card; Use-model sizes are
	# intentionally approximate large circles, authorized2026-10-15.
	var codes = [2, 11, 13, 14, 19, 20, 22, 23, 26, 27, 31, 32, 34, 37, 43, 45, 47, 51, 54, 57, 62, 63, 64, 65, 66]
	var board = RLCBoard.make()
	for code in codes:
		var sheet = RLCOrksDatasheet.make()
		sheet.set_value(code)
		var model = library.orks_remaining_model(sheet, 0)
		assert(model.get_datasheet().get_value() == code)
		assert(library.base_radius_micrometres(model) > 0.0)
		assert(model.get_has_waaagh())
	var gun = RLCOrksGunwagonGun.make()
	var extra = RLCOrksTrukkExtra.make()
	var units = [library.make_orks_battlewagon(0, 4, true, true), library.make_orks_big_ed_bossbunka(0, 3), library.make_orks_blitza_bommer(), library.make_orks_boss_snikrot(), library.make_orks_burna_bommer(true), library.make_orks_dakkajet(true), library.make_orks_deffkilla_wartrike(), library.make_orks_ghazghkull_thraka(), library.make_orks_gorkanaut(), library.make_orks_gunwagon(0, 4, true, true, true, gun), library.make_orks_hunta_rig(), library.make_orks_kill_rig(), library.make_orks_morkanaut(), library.make_orks_nazdreg(), library.make_orks_rukkatrukk_squigbuggies(2), library.make_orks_stompa(0), library.make_orks_trukk(0, true, extra), library.make_orks_wartrakks(2), library.make_orks_wazbom_blastajet(true, true, true), library.make_orks_wazdakka_gutsmek(), library.make_orks_weirdboy()]
	for unit in units:
		library.append(board.get_reserve_units(), unit)
	library.identify_units(board)
	library.capture_starting_strengths(board)
	library.register_orks_passive_rules(board)
	library.register_orks_unit_rules(board)
	assert(library.valid_state_foundations(board))
	assert(library.orks_passenger_space(units[7]) == 4)
	assert(library.get(units[0].get_models(), 0).get_geometry().get_proxy_diameter_mm().get_value() == 160)
	library.assign(rules.state.get_board(), board)
	var restored = library.play()
	assert(library.set_state(restored, RLCLib.godot_string_to_rlc_string(rules.as_indented_str(rules.state))))
	assert(library.size(restored.get_board().get_reserve_units()) == 21)
	# Exercise the actual new engine decision through generated production ABI.
	var combat = RLCBoard.make()
	library.append(combat.get_units(), library.make_orks_wazdakka_gutsmek())
	library.identify_units(combat)
	var phase = RLCBattlePhase.make()
	phase.set_value(1) # Command
	library.begin_phase(combat, phase)
	library.register_orks_unit_rules(combat)
	var engine_source = null
	for index in range(library.size(combat.get_source_instances())):
		var source = library.get(combat.get_source_instances(), index)
		if source.get_rule().get_value() == 145:
			engine_source = source
	assert(engine_source != null)
	var selection = library.orks_remaining_window(combat, engine_source)
	var engine = RLCOrksEngine.make()
	assert(library.can_choose_shokka_engine(selection, combat, engine))
	library.choose_shokka_engine(selection, combat, engine)
	assert(library.is_done(selection))
	# Exercise real bank-backed labels using a legal formation embarkation.
	var passenger_id = RLCUnitID.make()
	passenger_id.get_id().set_value(3) # Boss Snikrot
	var carrier_id = RLCUnitID.make()
	carrier_id.get_id().set_value(16) # Trukk
	var carrier_model = RLCModelID.make()
	library.embark_formation_unit(board, passenger_id, carrier_id, carrier_model)
	var bank = RLCSourceBank.make()
	bank.set_value(1) # reserves
	library.assign(board.get_orks_support_bank(), bank)
	library.assign(rules.state.get_board(), board)
	var actions = [RLCGameUseDatasheetWarpath.make(), RLCGameUseBeastscent.make(), RLCGameUseShokkAttackEngine.make(), RLCGameChooseSupremeFixedFive.make(), RLCGameSplitKommandoUnit.make(), RLCGameChooseSplitBombSquig.make(), RLCGameChooseSplitKommando.make(), RLCGameChooseShokkaEngine.make(), RLCGameChooseDatasheetMoveAbility.make(), RLCGameChooseMakariUnit.make(), RLCGameChoosePilinOutPassenger.make()]
	var labels = ["Fight without Warpath", "Disembark without Beastscent", "Stay on battlefield", "Roll D6 for Supreme Kunnin", "Keep ten Kommandos together", "Bomb Squig in remaining five", "Split Kommando model 1", "turbo", "makari", "Makari banner: Battlewagon", "Pilin Out: rapid disembark: Boss Snikrot"]
	for index in range(actions.size()):
		assert(actions[index].members_count() == 1)
		var panel = panel_for(rules, library, actions[index])
		assert(rules.strip_symbols(labels[index]) in panel.get_node("ChoiseList").get_child(0).text)
		panel.free()
	print("PASS: Godot schema exports, remaining25 source identities,21 current constructors, approximate hulls, source/save round trip, actual engine choice and11 named controls")
	library.free()
	call_deferred("quit", 0)
