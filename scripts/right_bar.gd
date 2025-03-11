extends VBoxContainer


var current_state = 0
func _ready() -> void:
	GlobalRules.on_state_changed.connect($Panel/GameContent.on_state_changed)
	GlobalRules.on_state_reset.connect(on_reset)

func toggle():
	if current_state == 0:
		current_state = current_state + 1
		$Panel/EventScrollable.hide()
		$Panel/GameContent.show()
		$Panel/GameContent.on_state_changed()
	elif current_state == 1:
		current_state = current_state + 1
		$Panel/EventScrollable.show()
		$Panel/GameContent.hide()
	else:
		current_state = 0
		$Panel/EventScrollable.hide()
		$Panel/GameContent.hide()

func on_reset():
	for child in $Panel/EventScrollable/EventBar.get_children():
		child.queue_free()
