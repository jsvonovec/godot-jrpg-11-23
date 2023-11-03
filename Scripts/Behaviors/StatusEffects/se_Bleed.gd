extends StatusEffect

# trying to make this one not have ANY user input, just the same
# in all instances

class_name se_Bleed

const ICON_PATH = "res://Sprites/Emoji/twe_blood.png"
const TICK = TICK_EVENT.BEFORE_AFFECTED_ACT
const BLEED_FRACTION = 0.05

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _duration):
	duration = _duration
	stacks = 1
	affected = _affected
	if merge_with_same(false, false, true, false):
		return
	is_buff = false
	big = true
	removable = true
	name = "Bleeding"
	var _icon = load(ICON_PATH)
	_finish_constructor(_caster, _affected, _icon, TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, duration)
# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

# override this in extending scripts
func _tick_effect(_arg = null):
	var damage = int(round(affected.max_hp * BLEED_FRACTION))
	#power, _source, a_type = 1, 
	#a_mult = 1.0, d_mult = 1.0, calc = true):
	affected.take_damage(damage, caster, Action.ATTACK_TYPE.PHYSICAL,
	1.0, 0.0, false)

# override this in extending scripts
#func _remove_status_effect(_arg = null):
#	pass

# The The message for when it's applied. Override it!
#func _application_message() -> String:
#	if is_buff:
#		return "%s is buffed with %s!" % [affected.name, name]
#	return "%s is debuffed with %s!" % [affected.name, name]

# To be overridden. Updates the name of the SE
#func _get_name():
#	return name
