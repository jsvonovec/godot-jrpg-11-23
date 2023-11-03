extends StatusEffect


class_name se_Parasite

var power : int
var leech_fraction := 0.0
var leech_died := false

func _init(_caster, _affected, _duration, _power, _leech_fraction,
_icon):
	stacks = _power
	caster_death_behavior = CASTER_DEATH_BEHAVIOR.END_EFFECT
	power = _power
	duration = _duration
	leech_fraction = _leech_fraction
	is_buff = false
	_finish_constructor(_caster, _affected, _icon, TICK_EVENT.BEFORE_AFFECTED_ACT, null)
	# IF OUR TARGET IS IMMUNE TO CHEMICALS: kill the leech
	if _affected.def[2] >= 100:
		leech_died = true
		end_effect(true)
		return

func _tick_effect(_arg = null):
	# IF OUR TARGET IS IMMUNE TO CHEMICALS: kill the leech
	if affected.def[2] >= 100:
		leech_died = true
		end_effect(true)
		return
	leech()

# Leeches health. Allows for different values.
func leech(_power = -1, _leech_amt = -1.0, _cast = null, _targ = null):
	_power = _power if _power != -1 else power
	_leech_amt = _leech_amt if _leech_amt != -1.0 else leech_fraction
	_cast = _cast if is_instance_valid(_cast) else caster
	_targ = _targ if is_instance_valid(_targ) else affected
	#_source, self, a_type, power, a_mult, d_mult
	_cast.heal(min(Action.calculate_damage(_cast, _targ, 
	Action.ATTACK_TYPE.CHEMICAL, _power, 1, 1), _targ.hp) 
	* _leech_amt, false)
	_targ.take_damage(_power, _cast, Action.ATTACK_TYPE.CHEMICAL, 1, 1)

func _remove_status_effect(_arg = null):
	if !leech_died:
		caster.resource[1] = min(caster.max_resource[1], 
		caster.resource[1] + 1)
	else:
		# leech died :(
		CombatUI.set_status("The leech died!!", 1.0)
# warning-ignore:return_value_discarded
		se_Parasite_Lost.new(caster, caster, null, 2, false)


func _application_message() -> String:
	return "%s has been Leeched!" % [affected.name]

func _get_name():
	name = "Leech|%s|%d %d" % [affected.name, _time_left, stacks]
	return name

#_caster, _affected, _duration, _power, _leech_fraction,
#_icon
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, _time_left, power,
	leech_fraction, icon)
