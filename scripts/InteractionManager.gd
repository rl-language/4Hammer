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
		if node.unit_id != GlobalRules.get_targetable_unit_id():
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
