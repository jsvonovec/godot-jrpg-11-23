extends StatusEffect

class_name se_Poisoned_Badly

const ICON_PATH = "res://Sprites/Emoji/twe_avocado.png"
const DMG_FRACTION = 16

func _init(_caster, _affected, _duration):
	affected = _affected
	stacks = 0
	duration = _duration
	extra_info = "!!!"
	for se in affected.status_effects_active:
		# grant stack to other poison
		if se.get_class_name() == get_class_name():
			se.upgrade()
			end_effect(true)
			return
		# replace little poison
		elif se.get_class_name() == "se_Poisoned":
			duration = max(se.duration, duration)
			se.end_effect(true)
			break
		# don't add if any poison already exists on affected
		if "se_Poisoned" in se.get_class_name() and se.get_class_name() != get_class_name():
			end_effect(true)
			return
	if merge_with_same(false, false, false, true):
		return
	is_buff = false
	big = true
	name = "Badly Poisoned"
	var _icon = load(ICON_PATH)
	_finish_constructor(_caster, _affected, _icon, 
	TICK_EVENT.TURN_END, null)

func calc_dmg(target):
	return int(round(float(target.max_hp) / float(DMG_FRACTION)))

func _tick_effect(_arg = null):
	affected.take_damage(calc_dmg(affected), caster, 
	Action.ATTACK_TYPE.CHEMICAL, 1.0, 1.0, false)


func upgrade():
	# add bad poison
	se_Poisoned_Lethally.new(caster, affected, _time_left)
	# delete self
	end_effect(true)


func _application_message() -> String:
	return "%s is Badly Poisoned!" % [affected.name]


func _get_name():
	name = "Badly Poisoned|%s|%d %d" % [affected.name, _time_left, stacks]
	return name


# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, _time_left)



func get_class_name() -> String: return "se_Poisoned_Badly"
