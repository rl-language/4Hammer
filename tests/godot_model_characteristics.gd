extends SceneTree

func _initialize():
	call_deferred("check_characteristics")

func check_characteristics():
	var library = root.get_node("GlobalRules").library
	assert(library.get_state_schema_version() == 46)
	assert(library.get_observation_schema_version() == 46)
	assert(library.get_action_schema_version() == 27)
	var board = RLCBoard.make()
	var unit = library.make_infernus_squad()
	library.append(board.get_units(), unit)
	var target = library.get(board.get_units(), 0)
	var model = library.get(target.get_models(), 1)
	var characteristic = RLCModifiedCharacteristic.make()
	var operation = RLCModifierOperation.make()
	characteristic.set_value(1) # TOUGHNESS, appendix02.02.01/05.02.01.
	operation.set_value(2) # ADD
	library.append(model.get_characteristic_modifiers(), library.characteristic_modifier(characteristic, operation, 3))
	assert(library.effective_toughness(model) == 7)
	assert(library.get_unit_toughtness(target) == 7)
	assert(library.effective_toughness(library.get(target.get_models(), 0)) == 4)
	characteristic.set_value(2) # SAVE
	operation.set_value(4) # SUBTRACT
	library.append(model.get_characteristic_modifiers(), library.characteristic_modifier(characteristic, operation, 1))
	var info = board.get_attack_info()
	var groups = library.make_allocation_groups(board, target, info)
	assert(library.size(groups) == 2)
	assert(library.get(groups, 0).get_save().get_value() == 3)
	assert(library.get(groups, 1).get_save().get_value() == 2)
	# A missing InSv stays unavailable even with a large arithmetic bonus.
	characteristic.set_value(3)
	library.append(model.get_characteristic_modifiers(), library.characteristic_modifier(characteristic, operation, 9))
	assert(library.effective_invulnerable_save(model) == 10)
	characteristic.set_value(0) # MOVEMENT: apply to the already rolled base.
	operation.set_value(2)
	library.append(model.get_characteristic_modifiers(), library.characteristic_modifier(characteristic, operation, 2))
	assert(library.effective_movement(model, 4) == 6)
	print("PASS: Godot schema exports, bearer modifiers, mixed Toughness, modified save groups and movement")
	library.free()
	call_deferred("quit", 0)
