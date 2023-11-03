extends StatusEffect

class_name se_Parasite_Lost

const ICON_PATH = "res://Sprites/Emoji/twe_friedshrimp.png"
const TICK = TICK_EVENT.TURN_END
var remove_leech_on_spawn = true

func _init(_caster, _affected, _icon, _duration, _remove_leech):
	duration = _duration
	remove_leech_on_spawn = _remove_leech
	stacks = -1
	is_buff = false
	only_on_screen = false
	name = "Lost Parasite"
	# new icon
	if _icon == null: _icon = load(ICON_PATH)
	_finish_constructor(_caster, _affected, _icon, TICK, null)


# override this in extending scripts
func _apply_status_effect(_arg = null):
	if remove_leech_on_spawn:
		caster.set_resource(1, min(caster.max_resource[1], 
		caster.resource[1] - stacks))

# override this in extending scripts
#func _tick_effect(_arg = null):
#	pass

# override this in extending scripts
func _remove_status_effect(_arg = null):
	caster.set_resource(1, min(caster.max_resource[1], 
	caster.resource[1] - stacks))

# The The message for when it's applied. Override it!
#func _application_message() -> String:
#	if is_buff:
#		return "%s is buffed with %s!" % [affected.name, name]
#	return "%s is debuffed with %s!" % [affected.name, name]

# To be overridden. Updates the name of the SE
#func _get_name():
#	return name

#_caster, _affected, _icon, _duration, _remove_leech
# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, _time_left, 
	remove_leech_on_spawn)
