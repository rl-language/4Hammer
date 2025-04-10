extends Node

var library = RLCLib.new()
var state = null
var automatic_actions = []
var all_actions = null
var valid_actions = null
var rng = RandomNumberGenerator.new()
signal on_action_applied
signal on_state_changed
signal on_state_reset

# Called when the node enters the scene tree for the first time.
func _ready():
	_reset()
 # Replace with function body.

func set_state(new_state: RLCGame):
	library.assign(self.state, new_state)
	var alias = RLCAnyGameAction.make()
	all_actions = library.enumerate(alias)
	valid_actions = _valid_actions()
	on_state_reset.emit()
	on_state_changed.emit()

func add_automatic_action(action: RLCAnyGameAction):
	print("here")
	automatic_actions.append(action)

func _reset():
	state = library.play()
	var alias = RLCAnyGameAction.make()
	all_actions = library.enumerate(alias)
	valid_actions = _valid_actions()

func reset():
	_reset()
	on_state_reset.emit()
	on_state_changed.emit()

func action_to_pretty_string(action: RLCAnyGameAction) -> String:
	return strip_symbols(library.convert_string(library.pretty_string(get_state().get_board(), action)))

func resolve_randomnmess():
	while library.get_current_player(state) == -1:
		_apply_random_action()
	on_state_changed.emit()
		
func _valid_actions():
	var l = []
	for i in range(library.size(all_actions)):
		var action = library.get(all_actions, i)
		if library.can_apply(action, state):
			l.append(action)
	return l
	
func all_valid_actions_are_of_same_type() -> bool:
	if valid_actions.size() == 0:
		return false
		
	var action_type = null
	for action in valid_actions:
		var unwrapped = action.unwrap()
		if unwrapped as RLCGameSkip:
			continue
		if action_type == null:
			action_type = unwrapped.get_class()
		elif action_type != unwrapped.get_class():
			return false
	return true

func apply_random_action():
	_apply_random_action()
	on_state_changed.emit()

func _apply_random_action():
	var actions = valid_actions
	if len(actions) == 0:
		return
	var selected = actions[rng.randi_range(0, len(actions)-1)]
	var applied = _apply_action(selected)
	for act in applied:
		on_action_applied.emit(act)

func load_state(str: String):
	var new_state = library.play()
	if library.set_state(new_state, RLCLib.godot_string_to_rlc_string(str)):
		state = new_state
		on_state_changed.emit()
		print("applied")
	else:
		print("failed to apply state")

func strip_symbols(s: String) -> String:
	return s.replace("[", "").replace("]", "").replace(",", "").replace("{", "").replace("}", "").to_snake_case().replace("_", " ")

func get_state() -> RLCGame:
	return state as RLCGame

func can_apply(action):
	if not action is RLCAnyGameAction:
		var wrapperd = RLCAnyGameAction.make()
		wrapperd.assign(action)
		action = wrapperd
	return self.library.can_apply(action, state)
	
func _apply_action(action):
	var actions = []
	library.apply(action, state)
	actions.append(action)
	while true:
		var applied_one = false
		for auto_action in automatic_actions:
			if can_apply(auto_action):
				library.apply(auto_action, state)
				applied_one = true
				actions.append(auto_action)
		if not applied_one:
			break
	valid_actions = _valid_actions()
	return actions

func apply_buffered(actions):
	for action in actions:
		library.apply(action, state)
	for act in actions:
		on_action_applied.emit(act)
	on_state_changed.emit()

func get_current_state_description() -> String:
	if get_state().get_board().get_current_state().get_value() == 0:
		return ""
	return strip_symbols(as_str(get_state().get_board().get_current_state()))

func apply_action(action):
	if not action is RLCAnyGameAction:
		var wrapperd = RLCAnyGameAction.make()
		wrapperd.assign(action)
		action = wrapperd
	if not library.can_apply(action, state):
		print("could not apply action")
		print_rlc(action)
		return
	var actions = _apply_action(action)
	for act in actions:
		on_action_applied.emit(act)
	on_state_changed.emit()

func apply_actions(actions):
	for action in actions:
		if not library.can_apply(action, state):
			print("could not apply action")
			print_rlc(action)
			return
		library.apply(action, state)


func get_units_counts() -> int:
	return library.size(get_state().get_board().get_units())

func get_unit(unit_id: int) -> RLCUnit:
	if unit_id >= get_units_counts() or 0 > unit_id:
		return null
	return library.get(get_state().get_board().get_units(), unit_id) as RLCUnit
	
func action_from_string(data: String) -> RLCAnyGameAction:
	var action = RLCAnyGameAction.make()
	if not library.from_string(action, library.godot_string_to_rlc_string(data)):
		return null
	return action

func get_model(unit_id: int, model_id: int) -> RLCModel:
	var unit = get_unit(unit_id)
	if unit == null:
		return null
	if model_id >= library.size(get_unit(unit_id).get_models()) or 0 > model_id:
		return null
	return library.get(get_unit(unit_id).get_models(), model_id) as RLCModel

func model_name(model: RLCModel) -> String:
	assert(model != null)
	return strip_symbols(library.convert_string(library.to_string(model.get_profile())))
	
func print_rlc(rlc_object):
	print(as_str(rlc_object))

func as_str(rlc_object)  -> String:
	assert(rlc_object != null)
	var stringed = library.to_string(rlc_object)
	if stringed == null:
		print("obj could not be converted to string")
		return ""
	return library.convert_string(stringed)

func as_indented_str(rlc_object)  -> String:
	assert(rlc_object != null)
	return RLCLib.convert_string(library.to_indented_lines(library.to_string(rlc_object)))

func choise_is_random() -> bool:
	return library.get_current_player(state) == -1

func get_current_select_model_action():
	for action in valid_actions:
		var unwrapped = action.unwrap()
		if unwrapped.members_count() == 1 and (unwrapped.get_member(0) is RLCModelID):
			return unwrapped.make()
	return null

func get_current_select_unit_action():
	for action in valid_actions:
		var unwrapped = action.unwrap()
		if unwrapped.members_count() == 1 and (unwrapped.get_member(0) is RLCUnitID):
			return unwrapped.make()

	return null

func is_target_action(action: RLCAnyGameAction):
	var unwrapped = action.unwrap()
	return unwrapped.members_count() == 2 and (unwrapped.get_member(0) as RLCUnitID) and (unwrapped.get_member(1) as RLCUnitID)

func get_current_target_action():
	for action in valid_actions:
		if is_target_action(action):
			return action.unwrap().make()
	return null
	
	
func get_targetable_unit_id() -> int:
	return (state as RLCGame).get_board().get_attack().get_target().get_id().get_value()

func is_terminal() -> bool:
	return (state as RLCGame).get_resume_index() == -1
	
func get_question_action():
	for action in valid_actions:
		var unwrapped = action.unwrap()
		if unwrapped.get_member(0) is bool and unwrapped.members_count() == 0:
			return unwrapped.make()
	return null
	
func unit_can_target_something(unit_id: int) -> bool:
	for action in valid_actions:
		if is_target_action(action):
			if (action.unwrap().get_member(0) as RLCUnitID).get_id().get_value() == unit_id:
				return true
	return false
	
func is_location_action(action: RLCAnyGameAction):
	var unwrapped = action.unwrap()
	if unwrapped.members_count() == 1 and (unwrapped.get_member(0) is RLCBoardPosition):
		return true
	return false
	
func get_location_saction():
	for action in valid_actions:
		if is_location_action(action):
			return action.unwrap().make()
	return null

func score(player_id: int):
	return library.get_score((state as RLCGame).get_board(), player_id)
