extends StatusEffect

class_name se_ActionOnDeath

const TICK = TICK_EVENT.TURN_END
var action : Action

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _icon, _duration, _action):
	duration = _duration
	action = _action
#	stacks = 1
	is_buff = true
	removable = true
	only_on_screen = false
	keep_through_lvl_up = true
	if _action != null:
		name = "%s on Death" % _action.name
	else:
		name = "Action on Death"
	_affected.connect("se_about_to_die", Callable(self, "on_death"))
	_finish_constructor(_caster, _affected, _icon, TICK, null)

func set_action(_action):
	action = _action
	if _action != null:
		name = "%s on Death" % _action.name
	else:
		name = "Action on Death"

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, duration)

func on_death():
	affected.disconnect("se_about_to_die", Callable(self, "on_death"))
	affected.evasion = 0
	if action != null and is_instance_valid(action):
		var initial = action.possible_initial_targets()
		initial = [initial[randi() % len(initial)]]
		action.gameplay_use(initial + action._auto_targets(initial))
	end_effect()


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
