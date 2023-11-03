@icon( "res://Sprites/hourglass.png")
extends Node

class_name StatusEffect
@export var icon: Texture2D
@export var ability: bool = false
@export_multiline var ability_desc

var caster : TurnCharacter
var affected : TurnCharacter
# Big SEs have a circle effect around the affected.
# They also have infinite duration, no stacks, and prevent other big SEs from
# being applied.
@export var big := false
@export var duration: int = 1
var _time_left : int = -1
var stacks := 0 
var extra_info := ""
# when to tick the duration down
enum TICK_EVENT {BEFORE_AFFECTED_ACT, AFTER_AFFECTED_ACT,
				BEFORE_CASTER_ACT, AFTER_CASTER_ACT,
				AFFECTED_TOOK_DAMAGE, AFFECTED_DEALT_DAMAGE,
				TURN_START, TURN_END, ACTION_PROCESSING_START, CUSTOM}
@export var _tick_event: TICK_EVENT
# Has 3 things: [CONNECTION HOST, SIGNAL, ARG]
var _tick_connection = [null,null, null]
var _tick_connection_set_up = false
enum CASTER_DEATH_BEHAVIOR {NOTHING, END_EFFECT, MOVE_TO_AFFECTED}
@export var caster_death_behavior: CASTER_DEATH_BEHAVIOR
@export var is_buff := true
@export var removable := true  
# All status effects are removed on lvl up, unless this is true.
@export var keep_through_lvl_up := false
# If all enemies have SEs that allow_move, the player may
# move between rooms at will.
@export var allow_move := false
@export var only_on_screen := true
var ending := false

# arg is the thing to give to _tick_effect. It could be something
# like number of enemies, or name, or whatever.
# Has no use by default; it's only useful for a status
# effect that specifically requests it.
# arg can be any type, including an array.

func _finish_constructor(the_caster, the_affected, _icon, tickevent, arg):
	# Invulnerability prevents negative status effects from applying
	if the_affected.invulnerable and !is_buff:
		end_effect()
		return
	# do not apply if we're big and affected already has a big
	if big:
		for se in the_affected.status_effects_active:
			if se.big and se != self:
				end_effect()
				return
	# We are a child of the affected
	if get_parent() != the_affected:
		the_affected.call_deferred("add_child", self)
	# Bigs last infinitely
	_time_left = duration if !ability and !big else -1
	caster = the_caster
	affected = the_affected
	icon = _icon
	set_tick_event(tickevent, arg)
	_apply_status_effect(arg)
	affected.add_status_effect(self)
	if !ability:
		the_caster.cell.se_added_this_turn.append(self)
		CombatPuppeteer.get_last_added_anim().add_effect_se(self, true, 
		stacks, duration, extra_info)

# tick event stuff
func set_tick_event(tick_event_to_switch_to, arg = null):
	# disconnect first
	# actually, is that necessary? no
	#_disconnect_prev_tick_event()
	if _tick_connection_set_up: return
	
	# now get the args
	_tick_event = tick_event_to_switch_to
	if _tick_event == TICK_EVENT.BEFORE_AFFECTED_ACT:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_about_to_act"
	elif _tick_event == TICK_EVENT.AFTER_AFFECTED_ACT:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_done_acting"
	elif _tick_event == TICK_EVENT.BEFORE_CASTER_ACT:
		_tick_connection[0] = caster
		_tick_connection[1] = "se_about_to_act"
	elif _tick_event == TICK_EVENT.AFTER_CASTER_ACT:
		_tick_connection[0] = caster
		_tick_connection[1] = "se_done_acting"
	elif _tick_event == TICK_EVENT.AFFECTED_DEALT_DAMAGE:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_damaged_other"
		_tick_connection[2] = arg
	elif _tick_event == TICK_EVENT.AFFECTED_TOOK_DAMAGE:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_took_damage"
		_tick_connection[2] = arg
	elif _tick_event == TICK_EVENT.ACTION_PROCESSING_START:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_action_phase_started"
	elif _tick_event == TICK_EVENT.TURN_START:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_turn_started"
	elif _tick_event == TICK_EVENT.TURN_END:
		_tick_connection[0] = affected
		_tick_connection[1] = "se_turn_ended"
	elif _tick_event == TICK_EVENT.CUSTOM:
		print("WARNING: YOU SHOULD USE set_tick_event_custom INSTEAD")
	
	# connect it
	_connect_tick_event()

func set_tick_event_custom(connection_host, sig, arg = null):
	if _tick_connection_set_up: return
	#_disconnect_prev_tick_event()
	_tick_event = TICK_EVENT.CUSTOM
	_tick_connection = [connection_host, sig, arg]
	_connect_tick_event()

func _disconnect_prev_tick_event():
	# disconnect first
	if (_tick_connection != null and _tick_connection[0] != null
	and _tick_connection[0].is_connected(_tick_connection[1], Callable(self, "on_tick_event"))):
		_tick_connection[0].disconnect(_tick_connection[1], Callable(self, "on_tick_event"))
	_tick_connection.clear()

func _connect_tick_event():
	if _tick_connection[0] == null: return
	# no arg - it is null.
	if _tick_connection[2] == null:
		_tick_connection[0].connect(
			_tick_connection[1],
			on_tick_event)
		return
	# arg is NOT null.
	_tick_connection[0].connect(
		_tick_connection[1],
		on_tick_event.bind(_tick_connection[2]))

var on_caster_died_done := false
func _on_caster_died(_arg):
	if on_caster_died_done: return
	on_caster_died_done = true
	if caster_death_behavior == CASTER_DEATH_BEHAVIOR.NOTHING: return
	if caster_death_behavior == CASTER_DEATH_BEHAVIOR.END_EFFECT:
		end_effect()
	elif caster_death_behavior == CASTER_DEATH_BEHAVIOR.MOVE_TO_AFFECTED:
		if _tick_event == TICK_EVENT.AFTER_CASTER_ACT:
			set_tick_event(TICK_EVENT.AFTER_AFFECTED_ACT)
		else:
			set_tick_event(TICK_EVENT.BEFORE_AFFECTED_ACT)

func on_tick_event(_arg = null):
	if ending or (!affected.on_players_team and 
	only_on_screen and !affected.player_in_same_room): return
	# ANIM: add new blank anim to put effects on
	CombatPuppeteer.ensure_blank_anim()
	_tick_effect(_arg)
	reduce_duration(1)
	queue_anim_update_card_icon()


# Returns true if we are merged with similar, false if we're unique.
func merge_with_same(add_stacks, max_stacks, add_time, max_time) -> bool:
	for se in affected.status_effects_active:
		if se.get_class_name() == get_class_name():
			if max_stacks:
				se.stacks = max(se.stacks, stacks)
			elif add_stacks:
				se.stacks += stacks
			if max_time:
				if _time_left < 0:
					se.set_duration(max(se._time_left, duration))
				else:
					se.set_duration(max(se._time_left, _time_left))
			elif add_time:
				if _time_left < 0 and duration >= 0:
					se.extend_duration(duration)
				elif _time_left >= 0:
					se.extend_duration(_time_left)
			end_effect(true)
			se.queue_anim_update_card_icon()
			return true
	return false

func end_effect(force_end = false):
	# do NOT do this if it's not removable
	if !force_end and _time_left > 0 and !removable: return
	# Don't do anything if it's already ending
	if ending: return
	# Don't remove abilities, unless forced to
	if ability and !force_end: return
	
	CombatPuppeteer.ensure_blank_anim()
	_remove_status_effect()
	affected.remove_status_effect(self)
	if !is_queued_for_deletion():
		TurnManager.destroy_on_turn_end(self)
		ending = true

func set_duration(amt):
	var diff = amt - _time_left
	extend_duration(diff)

func extend_duration(amt):
	if duration < 0: return
	if amt < 0:
		reduce_duration(-amt)
		return
	duration += amt
	_time_left += amt

func reduce_duration(amt):
	if duration < 0 or _time_left < 0: return
	if amt < 0:
		extend_duration(-amt)
		return
	_time_left -= amt
	if  _time_left <= 0:
		end_effect()

func queue_anim_update_card_icon():
	#se, show = null, stacks = null, dur = null, 
	#extra = null, texture = null
	CombatPuppeteer.get_last_added_anim().add_effect_se(self, !ending, stacks,
	_time_left, extra_info)

# THINGS TO OVERRIDE
# override this in extending scripts
func _apply_status_effect(_arg = null):
	pass

# override this in extending scripts
func _tick_effect(_arg = null):
	pass

# override this in extending scripts
func _remove_status_effect(_arg = null):
	pass

# The The message for when it's applied. Override it!
func _application_message() -> String:
	if is_buff:
		return "%s is buffed with %s!" % [affected.name, name]
	return "%s is debuffed with %s!" % [affected.name, name]

# To be overridden. Updates the name of the SE
func _get_name():
	return name

# To be overridden
func _duplicate(_new_affected = null):
	return self.duplicate()

func get_chara():
	return affected

func get_class_name(): return "StatusEffect"
