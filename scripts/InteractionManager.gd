extends Sprite2D

var source : Sprite2D
var intesity = 0.0
var current_select_model_action = null
var current_target_unit_action = null
var current_select_unit_action = null
var models = null

func on_state_change():
	clear()
	current_select_model_action = GlobalRules.get_current_select_model_action()
	current_target_unit_action = GlobalRules.get_current_target_action()
	current_select_unit_action = GlobalRules.get_current_select_unit_action()
	# Attachment pairs address reserves; source/target battlefield clicks use
	# different collections and must not supply those IDs.
	if current_target_unit_action is RLCGameAttachUnit:
		current_target_unit_action = null
	# Deployment selects reserves through the choice panel. Battlefield model
	# indices address a different collection and must not select reserve units.
	if current_select_unit_action is RLCGameRemoveOrksMusterUnit or current_select_unit_action is RLCGameChooseOffboardDreadUnit or current_select_unit_action is RLCGameChooseOrksOffboardUnit or current_select_unit_action is RLCGameChooseOrksOptionUnit or current_select_unit_action is RLCGameChooseWarlordUnit or current_select_unit_action is RLCGameSelectUnit or current_select_unit_action is RLCGameSelectReserveUnit or current_select_unit_action is RLCGameSelectIngressUnit or current_select_unit_action is RLCGameSelectScoutReserve or current_select_unit_action is RLCGameChooseStrategicReserve or current_select_unit_action is RLCGameChooseFormationPassenger or current_select_unit_action is RLCGameChooseFormationTransport or current_select_unit_action is RLCGameSelectDisembarkingUnit or current_select_unit_action is RLCGameChooseEmergencyPassenger or current_select_unit_action is RLCGameSelectFiringDeckPassenger or current_select_unit_action is RLCGameChooseMakariUnit or current_select_unit_action is RLCGameChoosePilinOutPassenger:
		current_select_unit_action = null
	# Passenger/formation model choices use buttons because these models are offboard.
	if current_select_model_action is RLCGameSelectOrksMusterModel or current_select_model_action is RLCGameChooseOrksOptionBearer or current_select_model_action is RLCGameChooseHealedCasualty or current_select_model_action is RLCGameChooseSurlyCasualty or current_select_model_action is RLCGameChooseWarlordModel or current_select_model_action is RLCGameChooseFormationCarrierModel or current_select_model_action is RLCGameSelectFiringDeckModel or current_select_model_action is RLCGameSelectDisembarkingModel or current_select_model_action is RLCGameChooseSplitKommando:
		current_select_model_action = null
	# Shared damage selectors address the bank recorded by the engine. Offboard
	# choices remain buttons; battlefield clicks must not supply their indices.
	if GlobalRules.state.get_board().get_damage_bank().get_value() != 0:
		if current_select_unit_action is RLCGameChooseDestructionUnit:
			current_select_unit_action = null
		if current_select_model_action is RLCGameSelectMortalModel or current_select_model_action is RLCGameResolveDestructionModel:
			current_select_model_action = null
	mark_possible_targets()
		

func select(node : Node2D):
	if current_select_model_action:
		var content = current_select_model_action.get_member(0) as RLCModelID
		content.get_id().set_value(node.model_id)
		GlobalRules.apply_action(current_select_model_action)
		return
	if current_select_unit_action:
		var content = current_select_unit_action.get_member(0) as RLCUnitID
		content.get_id().set_value(node.unit_id)
		GlobalRules.apply_action(current_select_unit_action)
		return
	if current_target_unit_action:
		if source == null:
			source = node
			(current_target_unit_action.get_member(0) as RLCUnitID).get_id().set_value(node.unit_id)
			mark_possible_targets()
		else:
			(current_target_unit_action.get_member(1) as RLCUnitID).get_id().set_value(node.unit_id)
			GlobalRules.apply_action(current_target_unit_action)
	
func clear():
	source = null
	current_select_model_action = null
	current_target_unit_action = null
	unmark_possible_targets()	
	
func mark_possible_target(node):
	if current_select_model_action:
		var target_id = GlobalRules.get_targetable_unit_id()
		# Task-10 damage/destruction can select a model outside the original
		# attack target (e.g. self hazards); its explicit context identifies it.
		if current_select_model_action is RLCGameChooseHealedModel:
			target_id = GlobalRules.state.get_board().get_orks_selected_unit().get_id().get_value()
		if current_select_model_action is RLCGameAllocateWound or current_select_model_action is RLCGameAllocateMortal or current_select_model_action is RLCGameSelectMortalModel or current_select_model_action is RLCGameResolveDestructionModel:
			target_id = GlobalRules.state.get_board().get_attack_info().get_target_unit_id().get_id().get_value()
		if current_select_model_action is RLCGameSelectMovingModel or current_select_model_action is RLCGameSelectChargingModel or current_select_model_action is RLCGameSelectMeleeModel or current_select_model_action is RLCGameChooseExplosivesModel or current_select_model_action is RLCGameChooseImpactModel or current_select_model_action is RLCGameChooseEpicCharacter or current_select_model_action is RLCGameChooseEmbarkModel:
			target_id = GlobalRules.state.get_board().get_moving_unit().get_id().get_value()
		if node.unit_id != target_id:
			return
		var content = current_select_model_action.get_member(0) as RLCModelID
		content.get_id().set_value(node.model_id)
		if GlobalRules.can_apply(current_select_model_action):
			node.show_aura()
	if current_select_unit_action:
		var content = current_select_unit_action.get_member(0) as RLCUnitID
		content.get_id().set_value(node.unit_id)
		if GlobalRules.can_apply(current_select_unit_action):
			node.show_aura()
	if current_target_unit_action:
		if source == null:
			if GlobalRules.unit_can_target_something(node.unit_id):
				node.show_aura()
		else:
			var content = (current_target_unit_action.get_member(1)) as RLCUnitID
			content.get_id().set_value(node.unit_id)
			if GlobalRules.can_apply(current_target_unit_action):
				node.show_aura()
	
func mark_possible_targets():
	for node in models.get_children():
		if not node.has_method("show_aura"):
			continue
		mark_possible_target(node)

func unmark_possible_targets():
	for node in models.get_children():
		if node.has_method("show_aura"):
			node.hide_aura()

func _process(delta):
	if source == null:
		intesity -= delta
	else:
		intesity += delta
		
	intesity = clamp(intesity, 0.0, 1.0)
	modulate = lerp(Color.TRANSPARENT, Color.GREEN_YELLOW, intesity)
	if source == null:
		return
	position = (source.position + get_global_mouse_position()) / 2
	scale.x = (source.position - get_global_mouse_position()).length() / 64
	look_at(get_global_mouse_position())

func _unhandled_input(event):
	if not source:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == 2:
			on_state_change()
