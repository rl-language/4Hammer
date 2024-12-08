extends VBoxContainer

var action = null

func _ready() -> void:
	visible = false
	GlobalRules.on_state_changed.connect(self.on_state_change)
	on_state_change()
	
func on_state_change():
	action = GlobalRules.get_question_action()
	if action:
		show_form(action.get_class().substr(7).to_snake_case().replace("_", " ") + "?", action)
		return
	visible = false

func show_form(str: String, bool_based_action):
	$Title.text = str
	visible = true
	action = bool_based_action

func _on_ok_button_button_down() -> void:
	visible = false
	action.set_member(0, true)
	GlobalRules.apply_action(action)

func _on_cancel_button_button_down() -> void:
	visible = false
	action.set_member(0, false)
	GlobalRules.apply_action(action)
