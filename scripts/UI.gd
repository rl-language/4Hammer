extends CanvasLayer

var event_bar_message_prefab = preload("res://scenes/event_bar_message.tscn")
var last_message = 0

func _ready() -> void:
	GlobalRules.on_action_applied.connect(self.on_action)
	Server.on_connection.connect(self.on_remote_mode_activated)
	
func on_remote_mode_activated():
	$AcceptRejectAction.hide()
	$RollDiceButton.hide()
	$MultipleChoise.active = false
	$LeftBar.hide()

func add_message(message: String):
	var message_obj = event_bar_message_prefab.instantiate()
	message_obj.text = message
	var event_bar = $RightBar/Panel/EventScrollable/EventBar
	event_bar.add_child(message_obj)
	$RightBar/Panel/EventScrollable.scroll_vertical = $RightBar/Panel/EventScrollable.get_v_scroll_bar().max_value
	#event_bar.move_child(event_bar.get_children().back(), 0)

func on_action(action):
	var casted = action.unwrap()
	add_message(GlobalRules.strip_symbols(GlobalRules.as_str(action)))
	
