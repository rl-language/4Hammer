extends TextEdit

var dirty = false
# Called when the node enters the scene tree for the first time.

func on_state_changed():
	if not visible:
		return
	text = GlobalRules.as_indented_str(GlobalRules.state)
	dirty = false

func _input(event):
	if event.is_action_pressed("ApplyState") and dirty:
		GlobalRules.load_state(text)

func _on_text_changed() -> void:
	dirty = true
