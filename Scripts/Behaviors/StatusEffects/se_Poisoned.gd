extends StatusEffect

class_name se_Poisoned

const ICON_PATH = "res://Sprites/Emoji/twe_avocado.png"
const DMG_FRACTION = 32

func _init(_caster, _affected, _duration):
	affected = _affected
	stacks = 0
	duration = _duration
	extra_info = "!"
	is_buff = false
	big = true
	name = "Poisoned"
	var _icon = load(ICON_PATH)
	for se in affected.status_effects_active:
		# grant stack to other poison
		if se.get_class_name() == get_class_name():
			se.upgrade()
			end_effect(true)
			return
		# don't add if any poison already exists on affected
		if "se_Poisoned" in se.get_class_name() and se.get_class_name() != get_class_name():
			end_effect(true)
			return
	if merge_with_same(false, false, false, true):
		return
	_finish_constructor(_caster, _affected, _icon, 
	TICK_EVENT.TURN_END, null)

func calc_dmg(target):
	return int(round(float(target.max_hp) / float(DMG_FRACTION)))

func _tick_effect(_arg = null):
	affected.take_damage(calc_dmg(affected), caster, 
	Action.ATTACK_TYPE.CHEMICAL, 1.0, 1.0, false)


func upgrade():
	# add bad poison
	se_Poisoned_Badly.new(caster, affected, _time_left)
	# delete self
	end_effect(true)


func _application_message() -> String:
	return "%s is Poisoned!" % [affected.name]


func _get_name():
	name = "Poisoned|%s|%d %d" % [affected.name, _time_left, stacks]
	return name


# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, _time_left)



func get_class_name() -> String: return "se_Poisoned"
