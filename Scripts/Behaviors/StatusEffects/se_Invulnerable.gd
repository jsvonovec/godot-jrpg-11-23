extends StatusEffect

class_name se_Invulnerable

const TICK = TICK_EVENT.TURN_END
func get_class_name() -> String: return "se_Invulnerable"

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _stacks, _duration):
	affected = _affected
	stacks = _stacks
	duration = _duration
	if _affected.vulnerable:
		# cancel each other out
		for se in _affected.status_effects_active:
			if se.get_class_name() == "se_Vulnerable":
				se.end_effect()
		end_effect()
		return
	if merge_with_same(true, false, false, true):
		return
	is_buff = true
	removable = true
	name = "Invulnerable"
	affected.connect("se_took_damage", Callable(self, "invuln_used"))
	_finish_constructor(_caster, _affected, 
	preload("res://Sprites/Emoji/twe_oko.png"), TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, duration)
# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

func _apply_status_effect(_arg = null):
	affected.invulnerable = true

func _remove_status_effect(_arg = null):
	affected.invulnerable = false

func invuln_used(_args):
	# if an attack.... reduce stacks
	if TurnManager.action_being_used_right_now and stacks > 0:
		stacks -= 1
		if stacks == 0:
			end_effect()
