extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalRules.on_state_changed.connect(self.on_state_change)
	on_state_change()

func on_state_change():
	if GlobalRules.is_terminal():
		text = "Done"
	elif GlobalRules.get_question_action():
		text = ""
	else:
		text = GlobalRules.strip_symbols(GlobalRules.valid_actions[0].unwrap().get_class().substr(7))
