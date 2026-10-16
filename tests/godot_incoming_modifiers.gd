extends SceneTree

func _initialize():
	call_deferred("check_incoming")

func check_incoming():
	var library = root.get_node("GlobalRules").library
	assert(library.get_state_schema_version() == 44)
	assert(library.get_observation_schema_version() == 44)
	assert(library.get_action_schema_version() == 26)
	var model = library.make_infernus_squad()
	var bearer = library.get(model.get_models(), 0)
	var kind = RLCModifiedCharacteristic.make()
	kind.set_value(12) # damage
	var operation = RLCModifierOperation.make()
	operation.set_value(4) # subtract
	var scope = RLCIncomingAttackScope.make()
	scope.set_value(1) # ranged
	var entry = library.incoming_attack_modifier(kind, operation, 1, scope)
	library.append(bearer.get_incoming_attack_modifiers(), entry)
	assert(library.valid_model_numeric_history(bearer))
	var info = RLCAttackSequenceInfo.make()
	var outgoing = info.get_damage_modifiers()
	var ranged = library.combined_incoming_modifiers(outgoing, bearer.get_incoming_attack_modifiers(), kind, false)
	var melee = library.combined_incoming_modifiers(outgoing, bearer.get_incoming_attack_modifiers(), kind, true)
	assert(library.size(ranged) == 1)
	assert(library.size(melee) == 0)
	assert(library.modified_characteristic(3, kind, ranged, false) == 2)
	assert(library.modified_characteristic(1, kind, ranged, false) == 1)
	print("PASS: Godot schema exports, incoming ranged scope, metadata and Damage floor")
	library.free()
	call_deferred("quit", 0)
