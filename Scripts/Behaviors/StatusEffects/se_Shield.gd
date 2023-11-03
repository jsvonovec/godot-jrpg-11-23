extends StatusEffect

class_name se_Shield

const TICK = TICK_EVENT.TURN_END

var prev_hp : int
# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _icon, _duration, _amount):
	duration = _duration
	stacks = _amount
	is_buff = true
	name = "Shield"
	prev_hp = _affected.hp
# warning-ignore:return_value_discarded
	_caster.connect("se_took_damage", Callable(self, "negate_damage"))
	_finish_constructor(_caster, _affected, _icon, TICK, null)


# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

func negate_damage(_args):
	if affected.hp < prev_hp:
		var dmg = prev_hp - affected.hp
		var overdmg = max(dmg - stacks, 0)
		var protection = min(dmg, stacks)
		# reduce shield by the protected amount
		stacks -= protection
		affected.hp += protection
		# reduce hp by overdraw amount
		affected.hp -= overdmg
		# end it if we have no stacks left
		if stacks <= 0:
			end_effect()

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



# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, _time_left, stacks)
