extends StatusEffect

class_name se_Burning
# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"

func _init(_caster, _affected, _icon, _duration, _damage):
	affected = _affected
	stacks = _damage
	duration = _duration
	if merge_with_same(true, false, false, true):
		return
	is_buff = false
	big = true
	name = "Burning"
	_finish_constructor(_caster, _affected, _icon, 
	TICK_EVENT.BEFORE_AFFECTED_ACT, null)

func _tick_effect(_arg = null):
	affected.take_damage(stacks, caster, Action.ATTACK_TYPE.MAGICAL, 1.0, 1.0)


func _application_message() -> String:
	return "%s is Burning!" % [affected.name]


func _get_name():
	name = "Burning|%s|%d %d" % [affected.name, _time_left, stacks]
	return name


# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, _time_left, stacks)



func get_class_name() -> String: return "se_Burning"
