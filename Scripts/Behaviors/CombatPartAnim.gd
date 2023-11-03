@tool
class_name CombatPartAnim
extends AnimationPlayer

signal anim_completed

# Short for Combat Particles Animation.
# Not to be confused with the Anim custom class.
# Each CombatPartAnim is the root node for all animations
# the involved skill uses.
# As an AnimationPlayer, this node holds animation libraries
# and animations; only one animation can be played by default, 
# as set by the 'animation' property.
# A RESET track MUST be defined in 'RESET_animation'. This will
# be 'played' at the end of the animation (in finish_anim) to
# reset all objects to their original positions.
# There is a node that takes the place of the 'origin' of the 
# animation, called 'origin_marker'. Changes made to this marker
# in animation are applied to the origin during runtime.
# This is, again, why it's important to have a RESET track.
# Same goes for 'target' and 'target_marker'.
# Finally, there is a PathToFrom between the origin and target 
# (or their markers if you're in the editor), in 'path_to_from'.
# All of these nodes may have children on them that would necessarily
# move with their parents. Use this to create complex animations
# using additional paths and path follows, and animate their properties
# in interesting ways.

var origin : Node3D
var target : Node3D
var origin_marker : Node3D:
	get:
		return $OriginStart/OriginMarker
var target_marker : Node3D:
	get:
		return $TargetStart/TargetMarker
var path_to_from : PathToFrom:
	get:
		return $PathToFrom
var animation : String:
	get:
		if animation != "":
			return animation
		for a in get_animation_list():
			if "RESET" not in a:
				animation = a
				return a
		return ""
var RESET_animation : String:
	get:
		if RESET_animation != "":
			return RESET_animation
		for a in get_animation_list():
			if "RESET" in a:
				RESET_animation = a
				return a
		return ""
var destroy_on_finish := false
# if true, this will be
# duplicated for each additional target after the first one,
# and the dupes will be temporary.
@export var duplicate_for_each_target := false
@export var duplication_delay := 0.25 # in beats :)

var anim = null
var cell = null
var all_children = []

func _ready():
	#name = get_parent().name + " CPA"
	if !Engine.is_editor_hint():
		origin_marker.texture = null
		target_marker.texture = null
	all_children = find_children("*")

func play_anim(_origin: Node3D, _target: Node3D, on_players_team):
	origin = _origin
	target = _target
	cell = NIU.find_cell(origin)
	$OriginStart.global_transform = origin.global_transform
	$TargetStart.global_transform = target.global_transform
	# flip if hostile and each GameParticle asks for it
	for node in all_children:
		if node is GameParticles and node.flip_if_enemy and !on_players_team:
			node.draw_pass_1.surface_get_material(0).uv1_scale = Vector3(-1.0, 1.0, 1.0)
	play(animation)
	finish_anim()

# When the attack is supposed to apply its effects, like damage and stuff
func hit():
	anim.hit(self)

func finish_anim():
	await self.animation_finished
	emit_signal("anim_completed")
	anim.finished_cpas += 1
	await get_tree().create_timer(3.0).timeout
	stop(true)
	play(RESET_animation)
	if destroy_on_finish and !Engine.is_editor_hint():
		queue_free()

# These are UNTESTED!!!!!!!!!!
var o_shake := Vector3.ZERO
func origin_shake(mag: float, dur: float):
	var m
	var tstart = Time.get_ticks_msec()
	while Time.get_ticks_msec() < tstart + (dur * 1000):
		m = mag * (1.0 / exp(5.0*(Time.get_ticks_msec() - tstart)))
		origin.position -= o_shake
		o_shake = Vector3.FORWARD.rotated(Vector3.UP, randf() * 2*PI) * m
		origin.position += o_shake
		print("SHAKING: %s" % str(o_shake))
		await self.processing
	origin.position -= o_shake
	o_shake = Vector3.ZERO

# These are UNTESTED!!!!!!!!!!
var t_shake := Vector3(0.0,0.0,0.0)
func target_shake(mag: float, dur: float):
	var m
	var tstart = Time.get_ticks_msec()
	while Time.get_ticks_msec() < tstart + (dur * 1000):
		m = mag * (1.0 / exp(5.0*(float(Time.get_ticks_msec() - tstart)/1000.0)))
		target.position -= t_shake
		t_shake = Vector3.FORWARD.rotated(Vector3.UP, randf() * 2.0*PI) * m
		target.position += t_shake
		print("SHAKING: %s" % str(t_shake))
		await self.processing
	target.position -= t_shake
	t_shake = Vector3(0.0,0.0,0.0)

signal processing
# DEBUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
var prev_effects := []
const check_effects = false
func CHECK_EFFECTS():
	# Actually is fine......?
	# Merging se_Poison causes this to activate.
	if check_effects and is_instance_valid(anim):
		if len(prev_effects) > len(anim.effects):
			printerr("ANIM LOST AN EFFECT!!!!!!!!\n" + str(get_stack()))
			breakpoint
		prev_effects = anim.effects.duplicate()

func _process(_delta: float) -> void:
	CHECK_EFFECTS()
	
	if Engine.is_editor_hint():
		if !NIU.iiv($OriginStart):
			var os = Node3D.new()
			add_child(os)
			os.name = "OriginStart"
			os.owner = get_tree().edited_scene_root
			os.position = Vector3.ZERO
		if !NIU.iiv($TargetStart):
			var ts = Node3D.new()
			add_child(ts)
			ts.name = "TargetStart"
			ts.owner = get_tree().edited_scene_root
			ts.position = Vector3.FORWARD * 5.0
		
		if !NIU.iiv(origin_marker):
			print("making new origin marker.")
			var om = Sprite3D.new()
			$OriginStart.add_child(om)
			om.owner = get_tree().edited_scene_root
			om.texture = preload("res://Sprites/Emoji/twe_fullmoon.png")
			om.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			om.name = "OriginMarker"
			om.position = Vector3.ZERO
		if !NIU.iiv(target_marker):
			print("making new target marker.")
			var tm = Sprite3D.new()
			$TargetStart.add_child(tm)
			tm.texture = preload("res://Sprites/Emoji/twe_crystalball.png")
			tm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tm.name = "TargetMarker"
			tm.owner = get_tree().edited_scene_root
			tm.position = Vector3.ZERO
		
		if !NIU.iiv(path_to_from):
			print("making new pathtofrom.")
			var ptf = PathToFrom.new()
			ptf.name = "PathToFrom"
			add_child(ptf)
			ptf.owner = get_tree().edited_scene_root
			ptf.start_node_path = ptf.get_path_to(origin_marker)
			ptf.end_node_path = ptf.get_path_to(target_marker)
			ptf.update_curve()
		
		origin = origin_marker
		target = target_marker
	
	else:
		# make animation default if none are found (Ranged)
		if !NIU.iiv(get_animation(animation)):
			printerr("ERROR: There is NO ANIMATION set on "
			+ "%s %s! (Path = %s)\nCreating an empty one now." % [
			get_class_name(), name, get_path()])
			var new_a = preload("res://Animations/Ranged.res")
			get_animation_library(get_animation_library_list()[
			0]).add_animation("atk", new_a)
		
		# make reset animation empty if none are found
		if !NIU.iiv(get_animation(RESET_animation)):
			printerr("ERROR: There is NO RESET track set on "
			+ "%s %s! (Path = %s)\nCreating an empty one now." % [
			get_class_name(), name, get_path()])
			var new_a = Animation.new()
			get_animation_library(get_animation_library_list()[
			0]).add_animation("RESET", new_a)
	
	emit_signal("processing")
	
	if is_playing():
		if !is_instance_valid(origin) or !is_instance_valid(target):
			printerr("ERROR: Origin or target is null!")
			breakpoint
			if !Engine.is_editor_hint():
				origin = Overworld.player_room.gsf()[0].get_node("Puppet")
				target = Overworld.player_room.gse()[0].get_node("Puppet")
		# keep up with target and origin locations
		else:
			if origin != origin_marker:
				origin.global_transform = origin_marker.global_transform
			if target != target_marker and target != origin:
				target.global_transform = target_marker.global_transform


func get_class_name() -> String:
	return "CombatPartAnim"
