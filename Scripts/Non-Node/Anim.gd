class_name Anim
extends RefCounted

signal done

var is_room_change = false
var origin : Node3D
var target : Node3D
var targets_to_find_middle_of := []
var free_target_on_finish := false
var speed := 1.0
var animation : CombatPartAnim
var move := false
var blank := false
# if true, all following simul. moves will happen at the same time
var simultaneous := true 
var finished := false
var effects := []
var action = null
enum EFFECT {RES, MAX_RES, HP, MAX_HP, SE, KILL, SET, CALL}
const def_effect_dur = {
	EFFECT.RES: 0.0,
	EFFECT.MAX_RES: 0.25,
	EFFECT.HP: 0.25,
	EFFECT.MAX_HP: 0.25,
	EFFECT.SE: 0.0,
	EFFECT.KILL: 0.75,
	EFFECT.SET: 0.0,
	EFFECT.CALL: 0.0
}
var effect_dur : Dictionary
var parent = null
var source : String

func handle_null_targ(_orig, _targ, _compartanim_node) -> Node3D:
	if !is_instance_valid(_targ):
		_targ = Node3D.new()
		_targ.name = "TEMPNulltarg %s" % _orig.get_chara().name
		var c = NIU.find_cell(_orig)
		_orig.add_child(_targ)
		var opt = (_orig.get_chara().on_players_team if 
			_orig.has_method("get_chara") else false)
		var offset = (_compartanim_node.target_marker.position
			if is_instance_valid(_compartanim_node) else 5.0)
		
		c.set_rel_loc(_targ, c.rel_loc(_orig)
		+ offset * Vector3.FORWARD * pow(-1, int(opt)))
#		_targ.global_transform.origin = (_orig.global_transform.origin
#		+ offset * Vector3.FORWARD * pow(-1, int(opt)))
		free_target_on_finish = true
	return _targ

func _init() -> void:
	effect_dur = def_effect_dur.duplicate()
	effects = []

func setup_anim(_orig, _targ, _spd, _anim_path = "", _action = null) -> void:
	source = str(get_stack())
	if _anim_path == "":
		_anim_path = "res://Scenes/Prefabs/Animations/PSlash.tscn"
	
	var anim_scene = load(_anim_path)
	
	# Instance and set up the animation
	animation = anim_scene.instantiate()
	# make the animation keep its name - must be on its own as a child
	parent = Node.new()
	parent.name = "TEMPParent Anim %s" % _orig.get_chara().name 
	NIU.find_cell(_orig).add_child(parent)
	parent.add_child(animation)
	animation.destroy_on_finish = true
	
	# create a target if we aren't provided one
	_targ = handle_null_targ(_orig, _targ, animation)
	origin = _orig
	target = _targ
	speed = _spd
	move = false
	action = _action
	animation.speed_scale = speed
	animation.origin = origin
	animation.target = target
	animation.anim = self
	if Engine.is_editor_hint():
		animation.name = origin.get_chara().name + "-" + animation.name

func setup_existing_anim(_orig, _targ, _spd, _compartanim_node = null,
_action = null) -> void:
	# create a target if we aren't provided one
	_targ = handle_null_targ(_orig, _targ, _compartanim_node)
	
	# do defaults if no node is given
	if !is_instance_valid(_compartanim_node):
		setup_anim(_orig, _targ, _spd)
		return
	source = str(get_stack())
	
	origin = _orig
	target = _targ
	speed = _spd
	move = false
	action = _action
	
	
	animation = _compartanim_node
	animation.speed_scale = speed
	animation.origin = origin
	animation.target = target
	animation.anim = self
	if Engine.is_editor_hint():
		animation.name = origin.get_chara().name + "-" + animation.name

# Destination is relative to the origin of cell.
func setup_move(_orig, destination, _spd, _simultaneous = true,
_action = null) -> void:
	source = str(get_stack())
	origin = _orig
	speed = _spd
	move = true
	simultaneous = _simultaneous
	target = Node3D.new()
	target.name = "Move target: %s" % _orig.get_chara().name
	target.translate(destination)
	action = _action

func set_group_to_find_middle_of(targets):
	if len(targets) == 1:
		target = targets[0].get_chara().pup.c
		targets_to_find_middle_of = [target]
		free_target_on_finish = false
		return
	if len(targets) == 0:
		return
	targets_to_find_middle_of = targets.duplicate()
	for i in range(len(targets)):
		targets_to_find_middle_of[i] = targets[i].get_chara().pup.c
	free_target_on_finish = true

# Use EFFECT in e_type.
# RESOURCES: val should be array: [index, value].
# HP: val is desired HP: int.
# SE: val is [se: StatusEffect, apply: bool or null, duration: int or null]
# KILL: val is target is killed: bool
func add_effect(e_type : int, affected_pup, val):
	effects.append([e_type, affected_pup, val])

func add_effect_res(affected_pup: Puppet, idx, val, cost = false):
	add_effect(EFFECT.RES, affected_pup, [idx, val, cost])

func add_effect_max_res(affected_pup: Puppet, idx, val):
	add_effect(EFFECT.MAX_RES, affected_pup, [idx, val])

func add_effect_hp(affected_pup: Puppet, val, _type_num):
	if is_instance_valid(action):
		add_effect(EFFECT.HP, affected_pup, [val, 0])
	else:
		add_effect(EFFECT.HP, affected_pup, [val, 4])

func add_effect_max_hp(affected_pup: Puppet, val):
	add_effect(EFFECT.MAX_HP, affected_pup, val)

func add_effect_se(se, show = null, stacks = null,
dur = null, extra = null):
	add_effect(EFFECT.SE, se.affected.pup, [se, show, stacks, dur, extra])

func add_effect_kill(affected_pup: Puppet):
	add_effect(EFFECT.KILL, affected_pup, null)

func add_effect_set(obj: Object, property: String, value):
	add_effect(EFFECT.SET, obj, [property, value])

func add_effect_call(obj: Object, method: String, args := []):
	add_effect(EFFECT.CALL, obj, [method, args])

# Applies this given effect triple array.
func apply_effect(effect: Array):
	var e_type = effect[0]
	var affected_pup = effect[1]
	var val = effect[2]
	
	match e_type:
		EFFECT.RES:
			affected_pup.set_resource(val[0], val[1])
		EFFECT.MAX_RES:
			affected_pup.set_max_resource(val[0], val[1])
		EFFECT.HP:
			affected_pup.set_hp(val[0], val[1])
		EFFECT.MAX_HP:
			affected_pup.set_max_hp(val)
		EFFECT.SE:
			affected_pup.set_status_effect(val[0], val[1], val[2], val[3], 
			val[4])
		EFFECT.KILL:
			affected_pup.die()
		EFFECT.SET:
			# In this case, "affected_pup" may not be a puppet at all
			affected_pup.set(val[0], val[1])
		EFFECT.CALL:
			# In this case, "affected_pup" may not be a puppet at all
			affected_pup.callv(val[0], val[1])
	
	var delay_time = effect_dur[e_type]
	if delay_time > 0.0:
		await SoundOp.wait_for_beats(delay_time).timeout

func finalize_target_pos():
	if len(targets_to_find_middle_of) == 0:
		return
	
	# place 'target' marker in avg pos of targets...
	var middle_of_targs = Node3D.new()
	middle_of_targs.name = "TEMPMid Targs %s" % origin.name
	var cell = NIU.find_cell(origin)
	cell.add_child(middle_of_targs)
	var avg_count = len(targets_to_find_middle_of)
	for t in targets_to_find_middle_of:
		if t == origin:
			avg_count -= 1
		elif NIU.get_class_name(t) == "TurnCharacter":
			middle_of_targs.position += cell.rel_loc(t.pup.c)
		elif NIU.get_class_name(t) == "Node3D":
			middle_of_targs.position += cell.rel_loc(t)
		else:
			avg_count -= 1
	if avg_count > 0:
		middle_of_targs.position /= avg_count
		target = middle_of_targs
	# ..or 5 units forward
	else:
		middle_of_targs.queue_free()

var finished_cpas := 0
func play():
	finished = false
	finished_cpas = 0
	finalize_target_pos()
#	print("Anim playing:\n\torigin = %s\n\ttarget = %s"
#	% [origin.name if NIU.iiv(origin) else "(null)"
#	, target.name if NIU.iiv(target) else "(null)"]
#	+ "\n\tblank = %s\n\tmove = %s"  % [blank, move] +
#	"\n\teffects: %s" % [effects])
	if !blank:
		var pup = get_puppet(origin)
		# Actions
		if !move:
			if NIU.iiv(action):
				CombatPuppeteer.show_action(action, pup.chara, -1)
			if is_instance_valid(pup):
				pup.play_atk_animation()
			# play the combatpartanim(s)
			animation.anim = self
			# MANY ANIMATIONS AT ONCE
			# duplicate animation a bunch of times
			var extra_animations = []
			if animation.duplicate_for_each_target:
				animation.target = targets_to_find_middle_of[0]
				for i in range(len(targets_to_find_middle_of) - 1):
					var extra = animation.duplicate()
					extra.name = (animation.name + " (DUPE %s)" % i)
					extra.destroy_on_finish = true
					extra.target = targets_to_find_middle_of[i + 1]
					extra.anim = self
					animation.add_sibling(extra, true)
					extra_animations.append(extra)
			else:
				animation.target = target
				# now play em
			animation.play_anim(origin, animation.target, pup.get_chara().on_players_team)
			for extra in extra_animations:
				if animation.duplication_delay > 0.0:
					await SoundOp.wait_for_beats(animation.duplication_delay).timeout
				extra.play_anim(origin, extra.target, pup.get_chara().on_players_team)
			# await for all of them to finish
			while finished_cpas < len(extra_animations) + 1:
				await animation.get_tree().process_frame
			#animation.play_anim(origin, target)
			#await animation.anim_completed
			if NIU.iiv(action):
				CombatPuppeteer.hide_status()
			if free_target_on_finish:
				target.queue_free()
		# Moves
		else:
			if is_instance_valid(pup):
				pup.play_animation("move")
			await move_origin(target.position)
			if is_instance_valid(pup):
				pup.play_animation("idle")
			target.queue_free()
	else:
		await hit(null)
	finished = true
	emit_signal("done")

# When the attack is supposed to make contact!
func hit(cpa: CombatPartAnim):
	effects.sort_custom(Callable(self, "sort_effects_in_order"))
	var remaining_effects = []
	for effect in effects:
		if (!NIU.iiv(cpa) 
		or !cpa.duplicate_for_each_target
		or !effect[1].has_method("get_chara")
		or !cpa.target.has_method("get_chara")
		or cpa.target.get_chara() == effect[1].get_chara()
		or !cpa.origin.has_method("get_chara")
		or cpa.origin.get_chara() == effect[1].get_chara()):
		# wait for all effects to finish - pauses and such
			await apply_effect(effect)
		else:
			remaining_effects.append(effect)
	effects = remaining_effects

const effect_order = {
	EFFECT.RES: 2, 
	EFFECT.MAX_RES: 5,
	EFFECT.HP: 1, 
	EFFECT.MAX_HP: 4,
	EFFECT.SE: 3,
	EFFECT.KILL: 0,
	EFFECT.SET: 6,
	EFFECT.CALL: 7
}
func sort_effects_in_order(a,b):
	# the cost of the ability takes priority
	if a[0] == EFFECT.RES and a[2][2]:
		return true
	if b[0] == EFFECT.RES and b[2][2]:
		return false
	if effect_order[a[0]] > effect_order[b[0]]:
		return true
	return false

func get_puppet(node):
	if !is_instance_valid(node):
		return null
	if NIU.get_class_name(node) == "Puppet":
		return node
	if is_instance_valid(node.get_parent()
	) and NIU.get_class_name(node.get_parent()) == "Puppet":
		return node.get_parent()
	return null

const MOVE_EASE = Tween.EASE_IN_OUT
const MOVE_TRANS = Tween.TRANS_SINE

func move_origin(dest):
	dest += NIU.find_cell(origin).global_transform.origin
	
	var t = origin.create_tween()
	t.bind_node(origin)
	t.tween_property(origin, "position", 
	dest - origin.global_transform.origin 
	+ origin.position, max((dest - origin.global_transform.origin).length() 
	/ speed, 0.01)).from(origin.position)
	await t.finished
	t.kill()
	origin.global_transform.origin = dest


func get_sfx(idx: int):
	if !is_instance_valid(action) or len(action.get_sfx()) == 0:
		return SoundOp.SOUND_TYPE.HIT_Physical1
	return action.get_sfx()[min(idx, len(action.get_sfx()))]
