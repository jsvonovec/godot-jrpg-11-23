class_name Puppet
extends Node3D

@export var dancing_sprite_path: NodePath
var dancing_sprite
# how many beats should the dance loop?
@export var dance_duration = 1
# how far into the beat to switch to/from dance sprite
@export var dance_ticks : Array[float] = [0.0, 0.5]
@export var intent_height := 3.5
@export var intent_amplitude := 0.3
@export var intent_period := 8.0
@export var intent_pos_offset := 3.0
@export var intent_fade : Curve
@export var intent_fade_scale : Curve
@export var intent_fade_dur := 1.0


@onready var chara := get_parent()
@onready var compup := get_node("/root/CombatPuppeteer")
var action = null
var move_speed := 35.0
var distance_forward := 4.0
var distance_from_targ := 3.0
var moving := false
var switching_rooms := false
var destination := Vector3.ZERO
var orig_position : Vector3
var walktimer = null
@onready var c = $Center
var matching_character := false

var dead := false
var death_anim_playing := false
var hp := 100
var max_hp := 100: set = set_max_hp
var res := {}
var max_res := {}
var status_effects := []
@onready var card = chara.find_child("CombatCard")
var targets : Array
var pos := 0.0

func _ready() -> void:
	$Center/Intent.hide()
	#yield(get_tree(), "idle_frame")
	$"/root/CombatPuppeteer".connect("start_anims", 
	on_start_anims)
	$"/root/CombatPuppeteer".connect("done_with_anims", 
	on_done_with_anims)
	if !dancing_sprite_path.is_empty():
		dancing_sprite = get_node(dancing_sprite_path)
		$"/root/SoundOp".connect("new_beat", Callable(self, "on_beat"))
	for i in randi() % 3:
		increment_dance()

# relative to cell
var orig_translation : Vector3
func save_translation():
	orig_translation = chara.cell.rel_loc(self)

func load_translation():
	chara.cell.set_rel_loc(self, orig_translation)

# sets the visual resource the player can see. May drain slowly or something.
# idk.
func set_resource(idx: int, val: int):
	res[idx] = val
	if !matching_character:
		CombatUI.queue_redraw()

func set_max_resource(idx: int, val: int):
	max_res[idx] = val
	if !matching_character:
		CombatUI.queue_redraw()

func set_hp(val: int, sound_type: int):
	hp = val
	SoundOp.play_hit_sound(sound_type)
	if !matching_character:
		CombatUI.queue_redraw()

func set_max_hp(val: int):
	max_hp = val
	if !matching_character:
		CombatUI.queue_redraw()

func set_status_effect(se, _show = null, stacks = null,
dur = null, extra = null):
	#card.set_status_effect_icon_info(se, show, stacks, dur, extra, se.icon)
	# add to circle. All code involved is in setter of circleSE's status_effect
	var secircle = $Center/RCircle.find_circle_se(se)
	secircle.set_status_effect(se, _show, stacks, dur, extra)
	if !matching_character:
		CombatUI.queue_redraw()

func die():
	if dead: return
	dead = true
	hp = 0
	if !matching_character:
		CombatUI.queue_redraw()

func match_character():
	matching_character = true
	dead = chara.dead
	visible = !dead
	hp = chara.hp
	max_hp = chara.max_hp
	pos = chara.pos
	res = {}
	for i in len(chara.resource):
		set_resource(i, chara.resource[i])
	for i in len(chara.max_resource):
		set_max_resource(i, chara.max_resource[i])
	var chara_sea = chara.status_effects_active
	for se in status_effects:
		set_status_effect(se, chara_sea.has(se), se.stacks, 
		se._time_left, se.extra_info)
	status_effects = chara_sea.duplicate()
	
	matching_character = false
	CombatUI.queue_redraw()

## ALL animation functions should yield something for compup to wait for!

# Steps toward the enemy group, or in front of the target (if action
# is melee).
func step_forward():
	var act = chara.selected_action
	var targs = chara.selected_targets
	orig_position = chara.cell.rel_loc(chara)
	# TOWARD TARGET
	if act.melee and len(targs) > 0:
		if targs[0].get_class_name() == "TurnCharacter":
			destination = targs[0].position
		elif targs[0].get_class_name() == "StatusEffect":
			destination = targs[0].affected.position 
		if chara.on_players_team:
			destination -= Vector3(0.0, 0.0, distance_from_targ)
		else:
			destination += Vector3(0.0, 0.0, distance_from_targ)
	# FORWARD
	else:
		if chara.on_players_team:
			destination = orig_position + Vector3(0.0, 0.0, 
			distance_forward)
		else:
			destination = orig_position - Vector3(0.0, 0.0, 
			distance_forward)
	
	CombatPuppeteer.add_move(self, destination, move_speed, false)

# Steps back to formation.
func step_back():
	CombatPuppeteer.add_move(self, chara.cell.rel_loc(chara), 
	move_speed, false)

# Strike a pose! For using actions. Casting, attacking, etc. Offense.
func play_atk_animation():
	# spin intent out
	spin_intent_out()
	if !is_instance_valid(action) or action.melee:
		play_animation("atk melee")
	else:
		play_animation("atk ranged")

const spinout_scale := 0.05
const spinout_opacity := 0.05

func spin_intent_out():
	# skip if intent is invisible
	if !$Center/Intent.visible:
		return
	
	intent_fade_dur = 120.0 / SoundOp.tempo
	var start_time = NIU.ftime()
	var t = 0.0
	while t < intent_fade_dur:
		var T = t / intent_fade_dur
		#shrink it!
		$Center/Intent.scale = Vector3(1.0, 1.0, 1.0
		) * intent_fade_scale.sample(T)
		# opacity it!
		$Center/Intent.transparency = intent_fade.sample(T)
		await get_tree().physics_frame
		t = NIU.ftime() - start_time
	$Center/Intent.scale = Vector3(1.0, 1.0, 1.0)
	$Center/Intent.transparency = 1.0
	$Center/Intent.hide()

func spin_intent_in():
	$Center/Intent.show()
	
	intent_fade_dur = 120.0 / SoundOp.tempo
	var start_time = NIU.ftime()
	var t = 0.0
	while t < intent_fade_dur:
		var T = 1.0 - t / intent_fade_dur
		#shrink it!
		$Center/Intent.scale = Vector3(1.0, 1.0, 1.0
		) * intent_fade_scale.sample(T)
		# opacity it!
		$Center/Intent.transparency = 1.0 - intent_fade.sample(T)
		await get_tree().physics_frame
		t = NIU.ftime() - start_time
	$Center/Intent.scale = Vector3(1.0, 1.0, 1.0)
	$Center/Intent.transparency = 0.0

func play_animation(a_name: String) -> void:
	if has_node("AnimationPlayer") and $AnimationPlayer.has_animation(a_name):
		$AnimationPlayer.play(a_name)

func on_start_anims():
	#$Center/Intent.hide()
	pass

func on_done_with_anims():
#	switching_rooms = false
#	action = null
#	targets = []
#	update_intent_icon()
	pass

func update_intent_icon():
	# Update intent icon
	var was_visible = $Center/Intent.visible
	$Center/Intent.visible = !chara.on_players_team and NIU.iiv(
		chara.selected_action) and !TurnManager.actions_processing
	if !was_visible and $Center/Intent.visible:
		spin_intent_in()
	if $Center/Intent.visible:
		# do lethal instead of damage if it will kill
		var cat = chara.selected_action.skill_category
		if cat == chara.selected_action.CATEGORY.Damage:
			for t in chara.selected_targets:
				if (t.get_class_name() == "TurnCharacter" 
				and chara.selected_action.calc_dmg(t) >= t.hp):
					cat = chara.selected_action.CATEGORY.Lethal
					break
		$Center/Intent.texture = load(
			chara.INTENT_PATHS[
			str(chara.selected_action.CATEGORY.keys()[cat])])

func on_beat(count):
	# don't dance if our dance is still going
	if (count - 1) % dance_duration != 0:
		return
	var timers := []
	for tick in dance_ticks:
		timers.append(SoundOp.wait_for_beats(tick))
	# dance! wait interval to alternate between sprites
	# we already checked if we have a dancing sprite, so we should be good
	for timer in timers:
		if timer.time_left > 0.0:
			await timer.timeout
		# alternate!
		increment_dance()

func increment_dance():
	if NIU.iiv(dancing_sprite):
		dancing_sprite.frame = (dancing_sprite.frame + 1
		) % dancing_sprite.sprite_frames.get_frame_count(
			dancing_sprite.sprite_frames.get_animation_names()[0])

func _process(_delta: float) -> void:
	# float the intent
	if visible and $Center/Intent.visible:
		var t = (fmod(SoundOp.total_beat_count() + (
		pos * intent_pos_offset), intent_period) / intent_period)
		$Center/Intent.position = Vector3(0.0, 
		intent_height + intent_amplitude * sin(2.0 * PI * t), 0.0)

var end_of_life_destroy_now = false
var death_pos : Vector3
var time_since_death := 0.0
func _physics_process(delta: float) -> void:
	# death anim
	if death_anim_playing and visible:
		position = Vector3(position.x,
		death_pos.y + (-5.0*pow(2.0*time_since_death - 1.0,2) + 5.0),
		position.z)
		time_since_death += delta * TurnManager.battle_speed
		if position.y < -50.0:
			position.y = -51.0
			if !end_of_life_destroy_now:
				visible = false
				#TurnManager.destroy_on_turn_end(self)
				end_of_life_destroy_now = true
	elif moving:
		position = position.move_toward(destination, 
		move_speed * delta * TurnManager.battle_speed)
#		translation += (
#			destination - translation).normalized() * (
#				move_speed * delta * TurnManager.battle_speed)

func get_class_name(): return "Puppet"

func get_chara(): 
	if NIU.iiv(chara):
		return chara
	return get_parent()
