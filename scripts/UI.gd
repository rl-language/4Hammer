extends CanvasLayer

var event_bar_message_prefab = preload("res://scenes/event_bar_message.tscn")
var last_message = 0

func _ready() -> void:
	GlobalRules.on_action_applied.connect(self.on_action)

func add_message(message: String):
	var message_obj = event_bar_message_prefab.instantiate()
	message_obj.text = message
	$EventScrollable/EventBar.add_child(message_obj)
	var tween = create_tween()
	message_obj.modulate.a = 0
	tween.tween_property(message_obj, "modulate:a", 1, 0.5)
	last_message = 0

func _process(delta: float) -> void:
	last_message += delta
	if last_message > 3:
		last_message -= 3
		if $EventScrollable/EventBar.get_child_count() != 0:
			_remove_element($EventScrollable/EventBar.get_child(0))
			

func _remove_element(element):
	var tween = create_tween()
	tween.tween_property(element, "modulate:a", 0, 0.5)
	tween.tween_callback(element.queue_free)

func on_action(action):
	var casted = action.unwrap()

	add_message(GlobalRules.strip_symbols(GlobalRules.as_str(action)))
