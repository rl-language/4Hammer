extends Panel

var quad = load("res://scenes/table_quad.tscn")
var quads = {}

func _ready():
	var i1 = 0
	for i in range(-position.x,  size.x, 64):
		var i2 = 0
		for y in range(-position.y, size.y, 64):
			var quad = quad.instantiate()
			quad.position.x = i
			quad.position.y = y
			$ValidLocations.add_child(quad)
			quad.visible = false
			quads[(i1*100) + i2] = quad
			i2 = i2 + 1
		i1 = i1 + 1

	GlobalRules.on_state_changed.connect(self.on_state_changed)
	
func on_state_changed():
	for quad in quads.values():
		quad.visible = false
	for action in GlobalRules.valid_actions:
		var unwrapped = action.unwrap()
		if unwrapped.members_count() != 1:
			continue
		if not unwrapped.get_member(0) is RLCBoardPosition:
			continue
		var board_position = unwrapped.get_member(0) as RLCBoardPosition
		if not board_position:
			continue
		quads[board_position.get_x().get_value() * 100 + board_position.get_y().get_value()].visible = true
