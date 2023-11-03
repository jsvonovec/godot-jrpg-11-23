@tool
extends SpotLight3D


@export var rot_speed = 0.0
@export var pulse = false
@export var pulse_offset = 0.0
@export var pulse_amp = 1.5

var spot_energy
func _ready():
	spot_energy = light_energy




func _physics_process(delta: float) -> void:
	rotate_object_local(Vector3(0,0,1), delta * rot_speed)

func _process(_delta):
	if pulse:
		process_pulse_spot()


func process_pulse_spot():
	if !Engine.is_editor_hint():
		var t = fmod(SoundOp.beat_progress() + pulse_offset, 1.0)
		light_energy = lerp(pulse_amp, 1.0, t) * spot_energy
