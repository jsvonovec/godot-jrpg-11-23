extends StatusEffect

class_name se_Stunned

const _icon = preload("res://Sprites/Emoji/twe_dizzy.png")
const TICK = TICK_EVENT.BEFORE_AFFECTED_ACT
var stun_action = null

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
#	stacks = 1
	is_buff = false
	allow_move = true
	only_on_screen = false
	name = "Stunned"
	_finish_constructor(_caster, _affected, _icon, TICK, null)


# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

# override this in extending scripts
func _tick_effect(_arg = null):
	if stun_action == null:
		stun_action = action_Stunned.new()
		affected.add_child(stun_action)
	
	# make this their action
	affected.select_action(stun_action, [affected])

# override this in extending scripts
func _remove_status_effect(_arg = null):
	if stun_action != null:
		TurnManager.destroy_on_turn_end(stun_action)


# The The message for when it's applied. Override it!
func _application_message() -> String:
	return "%s is Stunned!" % affected.name

# To be overridden. Updates the name of the SE
#func _get_name():
#	return name


# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, duration)
