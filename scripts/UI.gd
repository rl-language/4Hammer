extends CanvasLayer

var event_bar_message_prefab = preload("res://scenes/event_bar_message.tscn")
var last_message = 0

func _ready() -> void:
	GlobalRules.on_action_applied.connect(self.on_action)

func add_message(message: String):
	var message_obj = event_bar_message_prefab.instantiate()
	message_obj.text = message
	$RightBar/Panel/EventScrollable/EventBar.add_child(message_obj)

func on_action(action):
	var casted = action.unwrap()
	add_message(GlobalRules.strip_symbols(GlobalRules.as_str(action)))
	
