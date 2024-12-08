extends Camera2D

var movement_direction = Vector2(0, 0)
var zoom_speed = 0
var camera_speed = 100

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_A):
		movement_direction.x -= 1
	if Input.is_key_pressed(KEY_D):
		movement_direction.x += 1
	if Input.is_key_pressed(KEY_W):
		movement_direction.y -= 1
	if Input.is_key_pressed(KEY_S):
		movement_direction.y += 1

	movement_direction.x = clamp(movement_direction.x, -1, 1)
	movement_direction.y = clamp(movement_direction.y, -1, 1)

	zoom.x += zoom_speed * delta
	zoom.y += zoom_speed * delta
	zoom.x = clamp(zoom.x, 0.1, 100)
	zoom.y = clamp(zoom.y, 0.1, 100)

	zoom_speed = zoom_speed * 0.95
	translate(movement_direction * delta * camera_speed * zoom.x * 10)
	movement_direction = movement_direction * 0.95

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _unhandled_input(event: InputEvent) -> void:

		
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_speed += 1
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_speed -= 1
