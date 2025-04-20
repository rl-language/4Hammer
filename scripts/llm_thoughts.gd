extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Server.on_message.connect(self.on_message)

func on_message(text: String):
	self.text = text

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
