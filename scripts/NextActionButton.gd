extends Button


func _on_button_down() -> void:
	GlobalRules.apply_random_action()
	
func _on_button_down_actions() -> void:
	GlobalRules.apply_random_action()
	GlobalRules.resolve_randomnmess()
