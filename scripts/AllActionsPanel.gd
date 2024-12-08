extends PanelContainer

var time = 0.0
var list = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	list = $VContainer/ActionListScrollable/ActionList
	position.x = -(size.x - 30)
	#$VContainer/ActionListScrollable.custom_minimum_size.y = get_viewport().size.y - 100
	GlobalRules.on_state_changed.connect(on_state_change)
	visible = false

	on_state_change()
	
func on_state_change():
	if not visible:
		return
	clear_actions()
	var counter = 0
	for action in GlobalRules.valid_actions:
		add_action(GlobalRules.strip_symbols(GlobalRules.as_str(action)), action, counter)
		counter = counter + 1

func _process(delta: float) -> void:
	if get_rect().has_point(get_global_mouse_position()):
		time += delta * 2
	else:
		time -= delta * 2
	time = clamp(time, 0.0, 1.0)
	position.x = lerp(-(size.x - 30), 0.0, time)

func disconnect_all(sig:Signal):
	for dict in sig.get_connections():
		sig.disconnect(dict.callable)

func add_action(text: String, action, child_id = 0):
	var button = null
	if list.get_child_count() > child_id:
		button = list.get_child(child_id)
	else:
		button = Button.new()
		list.add_child(button)
	button.text = text
	button.button_down.connect(func(): self.trigger_action(action))
	button.visible = true
	
func clear_actions():
	for child in list.get_children():
		child.visible = false
		disconnect_all(child.button_down)
func trigger_action(action):
	GlobalRules.apply_action(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed() and event.keycode == KEY_P:
			visible = not visible
			on_state_change()
			get_viewport().set_input_as_handled()
