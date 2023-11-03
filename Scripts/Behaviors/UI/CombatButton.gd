extends Button
class_name CombatButton

var parts = preload("res://Scenes/Prefabs/UI/Parts/ButtonParts.tscn")

var action
var target


func _pressed() -> void:
	var newparts = parts.instantiate()
	newparts.on_press(self)
