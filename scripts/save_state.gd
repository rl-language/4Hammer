extends Button

var state = null

func _on_pressed() -> void:
	state = RLCGame.make()
	GlobalRules.library.assign(state, GlobalRules.state)
	


func _on_load_state_pressed() -> void:
	if state != null:
		GlobalRules.set_state(state)
