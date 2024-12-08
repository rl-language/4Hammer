extends HBoxContainer


var trace_txt
var trace : RLCVectorTAnyGameActionT
var current_action : int
var am_i_emitting_the_action = false

func _ready() -> void:
	GlobalRules.on_state_changed.connect(on_action)
	var trace_file = FileAccess.open("res://trace.txt", FileAccess.READ)
	trace_txt = trace_file.get_as_text()
	trace = GlobalRules.library.parse_actions(RLCAnyGameAction.make(), GlobalRules.library.s(trace_txt))
	current_action = 0

func on_action():
	if not am_i_emitting_the_action:
		$NextTraceAction.visible = false

func _on_next_trace_action_button_down() -> void:
	am_i_emitting_the_action = true
	if current_action >= GlobalRules.library.size(trace):
		print("failed to apply action")
		return
	GlobalRules.apply_action(GlobalRules.library.get(trace, current_action))
	current_action += 1
	am_i_emitting_the_action = false
