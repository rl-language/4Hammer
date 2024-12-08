extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalRules.on_state_changed.connect(on_state_change)
	on_state_change()

func on_state_change():
	visible = GlobalRules.choise_is_random()
	

func _on_button_down() -> void:
	GlobalRules.apply_random_action()
