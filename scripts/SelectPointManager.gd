extends Node2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_MASK_RIGHT and event.is_pressed():
			var location_action = GlobalRules.get_location_saction()
			if not location_action:
				return
			var position = (location_action.get_member(0) as RLCBoardPosition)
			position.get_x().set_value(get_global_mouse_position().x / 64)
			position.get_y().set_value(get_global_mouse_position().y / 64)
			GlobalRules.apply_action(location_action)
