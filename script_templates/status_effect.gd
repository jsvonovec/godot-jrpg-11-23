extends StatusEffect

class_name se_Status_Effect_Name

const TICK = TICK_EVENT.BEFORE_AFFECTED_ACT

func get_class_name() -> String:	return super.get_class_name()

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _icon, _duration):
	duration = _duration
#	stacks = 1
	is_buff = false
	removable = true
	name = "Status Effect"
	_finish_constructor(_caster, _affected, _icon, TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, duration)
# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

# override this in extending scripts
#func _tick_effect(_arg = null):
#	pass

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
