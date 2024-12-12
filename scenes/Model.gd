extends Sprite2D

var overed = false
var overed_time = 0
var pulsating_time = 0
var unit_id = 0
var model_id = 0
var unit = null
var being_removed = false

func _ready() -> void:
	var tween = create_tween()
	modulate.a = 0
	tween.tween_property(self, "modulate:a", 1, 0.5)

func _on_area_2d_mouse_entered():
	GlobalPopup.ItemPopup(get_viewport().get_mouse_position(), self.name(), self.tool_tip_text()) 
	self.overed = true

func _on_area_2d_mouse_exited():
	self.overed = false
	GlobalPopup.HideItemPopup()
	
func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	
	GlobalPopup.ItemPopup(get_viewport().get_mouse_position(), self.name(), self.tool_tip_text()) 
	self.overed = true
	

func _on_area_2d_mouse_shape_exited(shape_idx: int) -> void:
	self.overed = false
	GlobalPopup.HideItemPopup()
	
func get_model() -> RLCModel:
	return GlobalRules.get_model(unit_id, model_id)
	
func get_unit() -> RLCUnit:
	return GlobalRules.get_unit(unit_id)

func name() -> String:
	return GlobalRules.model_name(get_model())

func tool_tip_text() -> String:
	return GlobalRules.strip_symbols(GlobalRules.as_indented_str(get_model()))
	
func get_unit_color()  -> Color:
	if get_unit().get_owned_by_player1():
		return Color.AQUA
	return Color.REBECCA_PURPLE

func _process(delta):
	if being_removed:
		return
	var model = get_model() 
	if model == null:
		_fade_out()
		return
	if (overed or InteractionManager.source == self) and $Aura.visible:
		overed_time += delta * 2
	else:
		overed_time -= delta * 2
	overed_time = clamp(overed_time, 0, 1)
	pulsating_time += delta
	$Aura.scale = Vector2(1.2 + abs(sin(pulsating_time)/3.0), 1.2 + abs(sin(pulsating_time)/3.0))
	self_modulate = lerp(get_unit_color(), Color.DARK_RED, overed_time)
	self.position.x = model.get_position().get_x().get_value()*64
	self.position.y = model.get_position().get_y().get_value()*64
	var both_scale = GlobalRules.library.base_size(model.get_profile()) / 25.0
	scale = Vector2(both_scale, both_scale)
	
func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.pressed:
			InteractionManager.select(self)

func show_aura():
	$Aura.visible = true
	
func hide_aura():
	$Aura.visible = false

func _fade_out():
	get_parent().remove(self)
	unit.remove_model(self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.tween_callback(self.queue_free)
	being_removed = true
