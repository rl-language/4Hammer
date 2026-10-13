extends SceneTree

func _initialize():
	call_deferred("check_keyword_predicates")

func check_keyword_predicates():
	var library = root.get_node("GlobalRules").library
	assert(library.get_state_schema_version() == 23)
	assert(library.get_action_schema_version() == 14)
	assert(library.get_observation_schema_version() == 23)
	# Build an ordinary Board directly, avoiding large coroutine wrappers;
	# this still crosses the real Godot/native boundary and borrowed fields.
	var board = RLCBoard.make()
	var attacking = library.make_infernus_squad()
	var defending = library.make_infernus_squad()
	defending.set_owned_by_player1(true)
	library.append(board.get_units(), attacking)
	library.append(board.get_units(), defending)
	# Fetch borrowed members after the vector append that may relocate them.
	var target = library.get(board.get_units(), 1)
	var target_model = library.get(target.get_models(), 0)
	var keyword = RLCKeyword.make()
	keyword.set_value(45) # MONSTER in the preserved stats.rl enum order.
	library.append(target_model.get_keywords(), keyword)
	var predicate = RLCKeywordPredicate.make()
	var clause = RLCKeywordClause.make()
	clause.set_value(0) # ALL MONSTER
	assert(library.append_keyword_condition(predicate, clause, keyword))
	clause.set_value(2) # NONE TITANIC
	keyword.set_value(48)
	assert(library.append_keyword_condition(predicate, clause, keyword))
	assert(library.unit_matches_keywords(target, predicate))
	assert(library.model_matches_keywords(target_model, predicate))
	var kind = RLCWeaponRuleKind.make()
	kind.set_value(10) # ANTI-MONSTER
	var grant = library.conditional_weapon_rule(kind, 3, predicate)
	assert(library.weapon_ability_condition_count(grant) == 2)
	assert(library.weapon_ability_condition_clause(grant, 0).get_value() == 0)
	assert(library.weapon_ability_condition_clause(grant, 1).get_value() == 2)
	var info = board.get_attack_info()
	info.get_source_unit_id().get_id().set_value(0)
	info.get_target_unit_id().get_id().set_value(1)
	library.append(info.get_temporary_weapon_abilities(), grant)
	# p.79 / appendix02.05.01: temporary ANTI must obey its whole condition.
	assert(library.critical_wound_threshold(board, info) == 3)
	library.append(target_model.get_keywords(), keyword)
	assert(not library.unit_matches_keywords(target, predicate))
	assert(library.critical_wound_threshold(board, info) == 6)
	print("PASS: Godot schema exports, grouped predicates, condition bridges and temporary ANTI exclusion")
	# RLCLib is a test-owned Object, matching the full harness cleanup.
	library.free()
	call_deferred("quit", 0)
