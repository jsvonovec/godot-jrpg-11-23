extends Node
class_name Slide


@export var origin: Vector2
@export var destination = Vector2(-100.0, -100.0)
@export var duration = 1.0
@export var transition_type: int
@export var ease_type: int



func slide_in():
	var tween : Tween = get_tree().create_tween()
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)
	tween.tween_property(get_parent(), "position", origin,
	duration).from(destination)


func slide_out():
	var tween : Tween = get_tree().create_tween()
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)
	tween.tween_property(get_parent(), "position", destination,
	duration).from(origin)
