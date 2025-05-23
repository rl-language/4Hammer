extends Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalRules.on_state_changed.connect(self.on_state_change)
	on_state_change()

func on_state_change():
	var scores = str(GlobalRules.score(0)) + ":" + str(GlobalRules.score(1))
	if GlobalRules.is_terminal():
		text = scores + " - Done"
	elif GlobalRules.get_question_action():
		text = scores
	elif GlobalRules.get_current_state_description() != "":
		text = scores + " - " + GlobalRules.get_current_state_description()
	elif GlobalRules.all_valid_actions_are_of_same_type():
		text = scores + " - " + GlobalRules.strip_symbols(GlobalRules.valid_actions[0].unwrap().get_class().substr(7))
	else:
		text = scores + " - Multiple choise"
