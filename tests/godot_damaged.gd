extends SceneTree

func _initialize():
	call_deferred("check_damaged")

func check_damaged():
	var library = root.get_node("GlobalRules").library
	assert(library.get_state_schema_version() == 38)
	assert(library.get_observation_schema_version() == 38)
	assert(library.get_action_schema_version() == 24)
	var board = RLCBoard.make()
	var attacker = library.make_infernus_squad()
	var defender = library.make_infernus_squad()
	defender.set_owned_by_player1(true)
	library.append(board.get_units(), attacker)
	library.append(board.get_units(), defender)
	library.identify_units(board)
	var bearer = library.get(library.get(board.get_units(), 0).get_models(), 0)
	bearer.set_has_damaged(true)
	bearer.get_damaged_threshold().set_value(1)
	assert(not library.is_damaged(bearer))
	bearer.get_suffered_wounds().set_value(1)
	assert(library.is_damaged(bearer))
	var source = RLCUnitID.make()
	var target = RLCUnitID.make()
	target.get_id().set_value(1)
	var declaration = library.make_declared_weapon(board, source, 0, 0)
	var neutral = RLCAttackSequenceInfo.make()
	var info = library.declared_attack_info(board, source, target, declaration, neutral)
	assert(info.get_damaged_hit_penalty())
	# The modifier cancels a +1 before the cap.
	assert(library.total_hit_modifier(info) == -1)
	info.set_hit_roll_bonus(true)
	assert(library.total_hit_modifier(info) == 0)
	# Subsequent group snapshots use current wounds even with a stale context.
	bearer.get_suffered_wounds().set_value(0)
	var healed = library.declared_attack_info(board, source, target, declaration, info)
	assert(not healed.get_damaged_hit_penalty())
	assert(library.valid_model_numeric_history(bearer))
	print("PASS: Godot schema exports, Damaged threshold, modifier order and group refresh")
	library.free()
	call_deferred("quit", 0)
