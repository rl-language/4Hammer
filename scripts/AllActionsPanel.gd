extends PanelContainer

var list = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	list = $VContainer/ActionListScrollable/ActionList
	position.x = -(size.x - 30)
	#$VContainer/ActionListScrollable.custom_minimum_size.y = get_viewport().size.y - 100
	GlobalRules.on_state_changed.connect(on_state_change)

	on_state_change()
	
func on_state_change():
	if not visible:
		return
	clear_actions()
	var counter = 0
	for action in GlobalRules.valid_actions:
		add_action(GlobalRules.action_to_pretty_string(action), action, counter)
		counter = counter + 1

func disconnect_all(sig:Signal):
	for dict in sig.get_connections():
		sig.disconnect(dict.callable)

func add_action(text: String, action, child_id = 0):
	var button : Button = null
	if list.get_child_count() > child_id:
		button = list.get_child(child_id)
	else:
		button = Button.new()
		list.add_child(button)
	button.text = text
	button.button_down.connect(func(): self.trigger_action(action))
	button.connect("gui_input", func(event): self._on_button_input(event, action))
	button.visible = true

func _on_button_input(event, action):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MASK_RIGHT:
			GlobalRules.add_automatic_action(action)
			trigger_action(action)
	
func clear_actions():
	for child in list.get_children():
		child.visible = false
		disconnect_all(child.button_down)
		disconnect_all(child.gui_input)
		
func trigger_action(action):
	GlobalRules.apply_action(action)

func toggle():
	visible = not visible
	on_state_change()
	get_viewport().set_input_as_handled()
			
