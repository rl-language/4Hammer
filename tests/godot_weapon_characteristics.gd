extends SceneTree

func _initialize():
	call_deferred("check_weapon_characteristics")

func check_weapon_characteristics():
	var library = root.get_node("GlobalRules").library
	assert(library.get_state_schema_version() == 42)
	assert(library.get_observation_schema_version() == 42)
	assert(library.get_action_schema_version() == 26)
	var board = RLCBoard.make()
	var attacker = library.make_infernus_squad()
	var defender = library.make_infernus_squad()
	defender.set_owned_by_player1(true)
	library.append(board.get_units(), attacker)
	library.append(board.get_units(), defender)
	library.identify_units(board)
	var source = RLCUnitID.make()
	var target = RLCUnitID.make()
	target.get_id().set_value(1)
	# Borrow after the board-vector appends which can relocate its members.
	var bearer = library.get(library.get(board.get_units(), 0).get_models(), 0)
	var kind = RLCModifiedCharacteristic.make()
	var operation = RLCModifierOperation.make()
	kind.set_value(10) # STRENGTH
	operation.set_value(2) # ADD
	var grant = library.weapon_characteristic_modifier(kind, operation, 2, 0)
	assert(grant.get_weapon_scope().get_value() == 1)
	library.append(bearer.get_characteristic_modifiers(), grant)
	kind.set_value(9) # BS on every ranged weapon of this bearer.
	library.append(bearer.get_characteristic_modifiers(), library.characteristic_modifier(kind, operation, 1))
	kind.set_value(11) # AP
	operation.set_value(4) # SUBTRACT: improving AP by1.
	library.append(bearer.get_characteristic_modifiers(), library.weapon_characteristic_modifier(kind, operation, 1, 0))
	library.configure_attack_info(board, 0, 1, false, false)
	var declaration = library.make_declared_weapon(board, source, 0, 0)
	var info = library.declared_attack_info(board, source, target, declaration, board.get_attack_info())
	assert(library.attack_strength(info) == 6)
	assert(library.attack_penetration(info) == -1)
	assert(library.effective_attack_skill(board, info) == 4)
	# Subsequent groups use the current T, not the enclosing stale snapshot.
	kind.set_value(1)
	operation.set_value(2)
	var recipient = library.get(library.get(board.get_units(), 1).get_models(), 0)
	library.append(recipient.get_characteristic_modifiers(), library.characteristic_modifier(kind, operation, 3))
	var next_info = library.declared_attack_info(board, source, target, declaration, board.get_attack_info())
	assert(next_info.get_target_toughness().get_value() == 7)
	assert(board.get_attack_info().get_target_toughness().get_value() == 4)
	# Borrowing the same profile does not borrow the carrier's slot-specific grant.
	declaration.set_borrowed_weapon(true)
	var borrowed = library.declared_attack_info(board, source, target, declaration, board.get_attack_info())
	assert(library.attack_strength(borrowed) == 4)
	# The explicit group IDs supersede a neutral/stale enclosing context.
	var neutral = RLCAttackSequenceInfo.make()
	var explicit_info = library.declared_attack_info(board, source, target, declaration, neutral)
	assert(explicit_info.get_target_unit_id().get_id().get_value() == 1)
	var reverse_declaration = library.make_declared_weapon(board, target, 0, 0)
	var reverse_info = library.declared_attack_info(board, target, source, reverse_declaration, neutral)
	assert(reverse_info.get_source_unit_id().get_id().get_value() == 1)
	# A/D grants reach the actual declaration/gathered snapshot APIs.
	kind.set_value(7) # ATTACKS
	operation.set_value(2) # ADD
	library.append(bearer.get_characteristic_modifiers(), library.weapon_characteristic_modifier(kind, operation, 2, 0))
	kind.set_value(12) # DAMAGE
	library.append(bearer.get_characteristic_modifiers(), library.weapon_characteristic_modifier(kind, operation, 1, 0))
	declaration.set_borrowed_weapon(false)
	var modified = library.declared_attack_info(board, source, target, declaration, neutral)
	assert(library.size(modified.get_damage_modifiers()) == 1)
	assert(library.size(library.declaration_attack_modifiers(board, source, declaration)) == 1)
	assert(not library.same_effective_damage(modified, borrowed))
	print("PASS: Godot schema exports, weapon scope, effective S/AP/BS and fresh target Toughness")
	library.free()
	call_deferred("quit", 0)
