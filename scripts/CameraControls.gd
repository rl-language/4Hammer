extends Camera2D

var movement_direction = Vector2(0, 0)
var zoom_speed = 0
var camera_speed = 100
@export var center_on : Panel
var positions : Array = [Vector2(), Vector2()]


func _ready():
	Server.on_connection.connect(self.on_server_connected)
	var viewport_size = get_viewport_rect().size
	var viewport_width = viewport_size.y
	var zoom_factor = viewport_width / center_on.size.y
	print(center_on.size.x)
	zoom = Vector2(zoom_factor, zoom_factor)
	position.x = center_on.size.x / 2 + center_on.position.x
	position.y = center_on.size.y / 2 + center_on.position.y
	
func on_server_connected():
	var viewport_size = get_viewport_rect().size
	var viewport_width = viewport_size.y
	var zoom_factor = viewport_width / center_on.size.y
	zoom = Vector2(zoom_factor * 0.8, zoom_factor * 0.8)

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
	zoom.x = clamp(zoom.x, 0.01, 100000)
	zoom.y = clamp(zoom.y, 0.01, 100000)

	zoom_speed = zoom_speed * 0.95
	translate(movement_direction * delta * camera_speed * zoom.x * 10)
	movement_direction = movement_direction * 0.95

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		positions[event.index] = event.position
		if event.index == 1:
			var zoom_amount = (positions[0] - positions[1]).length()
			zoom = zoom + zoom_amount
	# Check if this is a mouse motion event
	if event is InputEventMouseMotion:
		# And if the right mouse button is currently held down
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			# Subtract event.relative from the camera's position
			# so that dragging the mouse to the right/left moves
			# the camera correspondingly.
			position -= event.relative / zoom
		
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_speed += 1
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_speed -= 1
