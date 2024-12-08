extends Node

var model_prefab = load("res://scenes/model.tscn")
var alive_nodes = {}

func _ready() -> void:
	spawn_needed_models()
	GlobalRules.on_state_changed.connect(self.on_state_change)
	InteractionManager.models = self


func spawn_model_for(unit_id: int, model_id: int):
	if (unit_id*100)+model_id in alive_nodes:
		return 
	var child = model_prefab.instantiate()
	child.position = Vector2((model_id-10) * 64, 300*(unit_id+1) -600)
	child.unit_id = unit_id
	child.model_id = model_id
	add_child(child)
	alive_nodes[(unit_id*100)+model_id] = child

func spawn_needed_models():
	for unit_id in  range(GlobalRules.get_units_counts()):
		var unit = GlobalRules.get_unit(unit_id)
		for model_id in GlobalRules.library.size(unit.get_models()):
			spawn_model_for(unit_id, model_id)

func remove(model):
	alive_nodes.erase(model.unit_id*100+model.model_id)

func on_state_change():
	spawn_needed_models()
	InteractionManager.on_state_change()
