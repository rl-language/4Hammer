extends PanelContainer



func _on_mouse_entered():
	GlobalPopup.ItemPopup(get_global_mouse_position(), "Huzza", "Hizza") # Replace with function body.


func _on_mouse_exited():
	GlobalPopup.HideItemPopup() # Replace with function body.
