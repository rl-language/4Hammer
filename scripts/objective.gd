extends Sprite2D

@export var index = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalRules.on_state_changed.connect(self.on_state_changed)
	on_state_changed()
	
func get_objective_game_position():
	var all_pos = GlobalRules.library.get_objectives_locations(GlobalRules.get_state().get_board())
	var new_pos = GlobalRules.library.get(all_pos, index) as RLCBoardPosition
	return Vector2(new_pos.get_x().get_value() * 64, new_pos.get_y().get_value() * 64)
	
func on_state_changed():
	position = get_objective_game_position()
