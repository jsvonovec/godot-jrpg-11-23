@tool
@icon("res://Sprites/marker_node.png")
extends Node3D

class_name Marker

@export var enabled := true
@export var enabled_in_editor := false
@export var node : Node3D
@export var nodepath : NodePath
@export var replace_after_disable := false
var orig_pos : Vector3
var prev_enabled = false

func _process(_delta):
	if !NIU.iiv(node):
		node = get_node_or_null(nodepath)
	if enabled and (!Engine.is_editor_hint() or enabled_in_editor
	) and (NIU.iiv(node)):
		# first frame of enability
		if !prev_enabled:
			orig_pos = node.position
			prev_enabled = true
		
		node.global_position = global_position
	else:
		# first frame of disability
		if prev_enabled:
			prev_enabled = false
			if replace_after_disable and NIU.iiv(node):
				node.position = orig_pos
