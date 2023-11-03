@tool
extends GPUParticles3D

class_name GameParticles

@export var _texture = preload("res://Sprites/Particles/basic.png"
	): set = set_texture
@export var h_frames = 1: set = set_h_frames
@export var v_frames = 1: set = set_v_frames
@export var above_sprites := true
@export var flip_if_enemy := true

@export var _process_material = preload(
	"res://Misc/ParticleProcessMat.material"): set = _set_process_material





func _enter_tree() -> void:
	set_texture(_texture)
	_set_process_material(_process_material)
	if !Engine.is_editor_hint():
		sorting_offset += -1.0 + 2.0 * int(above_sprites)

func set_texture(val):
	_texture = val
	draw_pass_1 = draw_pass_1.duplicate() if is_instance_valid(draw_pass_1
	) else preload("res://Misc/PartDrawPass.res")
	draw_pass_1.surface_get_material(0).set("albedo_texture", val)

func set_h_frames(val):
	h_frames = val
	draw_pass_1.surface_get_material(0).set("particles_anim_h_frames", val)

func set_v_frames(val):
	v_frames = val
	draw_pass_1.surface_get_material(0).set("particles_anim_v_frames", val)


func _set_process_material(val):
	_process_material = val.duplicate()
	process_material = _process_material



func get_class_name() -> String:
	return "GameParticles"
