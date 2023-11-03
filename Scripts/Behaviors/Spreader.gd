@tool
extends Node3D

@export var use_prefab_not_model = false
@export var model : Mesh
@export var prefab : PackedScene #treefab
@export var min_scale := 1.5
@export var max_scale := 6.0
@export var max_scale_over_distance := Curve.new()
@export var count := 160
@export var inner_rad := 20.0
@export var outer_rad := 75.0
@export var min_radian := -1.5708
@export var max_radian := 3.14159
@export var grounded = true
@export var skip_invalid = true
var spawned := []

# for grounding
var r
var t
var x
var z
var try_finding_point = false
var points := []

func _ready():
	#delete all spawned objects
	for i in range(len(spawned) - 1, -1, -1):
		spawned[i].queue_free()
	spawned.clear()
	
	# find ground points if needed
	if grounded:
		try_finding_point = true
		await done_finding_ground
	# ungrounded pts
	else:
		points.clear()
		for i in range(count):
			points.append(get_random_radial_point())
	
	# spread stuff around
	for i in range(count):
		r = points[i].length()
		var m = max_scale_over_distance.sample_baked(inverse_lerp(
		inner_rad, outer_rad, r)) * (max_scale - min_scale) + min_scale
		var s = randf_range(min_scale, m)
		var spawn
		if !use_prefab_not_model and model != null:
			spawn = MeshInstance3D.new()
			spawn.name = "Spawn %s" % i
			spawn.mesh = model
		elif prefab != null:
			spawn = prefab.instantiate()
		add_child(spawn)
		spawn.position = points[i]
		spawn.scale = Vector3(s,s,s)
		spawn.rotate(Vector3.UP, randf() * PI * 2.0)
		spawned.append(spawn)


func get_random_radial_point():
	r = randf_range(inner_rad, outer_rad)
	t = randf_range(min_radian, max_radian)
	x = r*sin(t)
	z = r*cos(t)
	return Vector3(x,0.0,z)

signal done_finding_ground

# This is in physics process because raycasts must be done there.
func _physics_process(delta):
	if try_finding_point:
		while len(points) < count:
			try_finding_point = true
			var tries = 0
			while try_finding_point and tries < 500:
				get_random_radial_point()
				# raycasting shenanigans
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(
				Vector3(x,10.0,z) + global_position, Vector3(x,-10.0,z) + global_position)
				var result := space_state.intersect_ray(query)
				if result:
					points.append(result["position"] - global_position)
					try_finding_point = false
				elif skip_invalid:
					points.append(Vector3.DOWN * 100.0)
					try_finding_point = false
				else:
					tries += 1
					if tries == 500:
						points.append(Vector3.DOWN * 100.0)
						printerr("ERROR: Spreader %s couldn't find ground to place something! (%s)" % [
						name, get_path()])
						try_finding_point = false
		try_finding_point = false
		emit_signal("done_finding_ground")
