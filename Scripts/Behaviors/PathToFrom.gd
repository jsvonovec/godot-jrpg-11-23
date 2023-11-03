@tool
extends Path3D
class_name PathToFrom

@export_node_path("Node3D") var start_node_path : NodePath :
	set(val):
		start_node = get_node_or_null(val)
		start_node_path = val
var start_node : Node3D
@export_node_path("Node3D") var end_node_path : NodePath :
	set(val):
		end_node = get_node_or_null(val)
		end_node_path = val
var end_node : Node3D
@export var middle_height := 0.0
@export var middle_control_strength := 0.0

func _enter_tree():
	create_curve()

func create_curve():
	curve = Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3.FORWARD * 2.5 + Vector3.UP * middle_height)
	curve.add_point(Vector3.FORWARD * 5.0)
	

func _physics_process(_delta):
	if start_node == null:
		start_node = get_node(start_node_path)
	if end_node == null:
		end_node = get_node(end_node_path)
#	pass
	if is_instance_valid(start_node) and is_instance_valid(end_node):
		update_curve()
	rotation_degrees = Vector3.ZERO

func update_curve():
	if !NIU.iiv(curve):
		create_curve()
	var same = start_node.global_position - end_node.global_position == Vector3.ZERO
	var p = [start_node.global_position - global_position,
	(end_node.global_position + start_node.global_position) / 2.0 
	+ Vector3.UP * middle_height - global_position 
	if !same else start_node.global_position - global_position + Vector3.UP * 0.005,
	end_node.global_position - global_position 
	if !same else start_node.global_position - global_position + Vector3.UP * 0.01]
	
	curve.set_point_position(0, p[0])
	curve.set_point_position(1, p[1])
	curve.set_point_position(2, p[2])
	var p_in = (p[0] - p[1]) * middle_control_strength
	p_in.y = 0.0
	curve.set_point_in(1, p_in)
	var p_out = (p[2] - p[1]) * middle_control_strength
	p_out.y = 0.0
	curve.set_point_out(1, p_out)
	
	for c in get_children():
		if c is PathFollow3D:
			c.progress = c.progress
