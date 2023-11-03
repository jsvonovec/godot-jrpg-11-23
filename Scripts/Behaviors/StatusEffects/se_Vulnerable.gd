extends StatusEffect

class_name se_Vulnerable

const TICK = TICK_EVENT.AFFECTED_TOOK_DAMAGE
var def_drop := []

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _stacks):
	affected = _affected
	duration = -1
	stacks = _stacks
	if _affected.invulnerable:
		# cancel each other out
		for se in _affected.status_effects_active:
			if se.get_class_name() == "se_Invulnerable":
				se.end_effect()
		end_effect()
		return
	if merge_with_same(true, false, false, false):
		return
	var _icon = preload("res://Sprites/Emoji/twe_pirate.png")
	is_buff = false
	removable = true
	name = "Vulnerable"
	affected.connect("se_took_damage", Callable(self, "vuln_used"))
	_finish_constructor(_caster, _affected, _icon, TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, stacks)

func _apply_status_effect(_arg = null):
	affected.vulnerable = true

func _remove_status_effect(_arg = null):
	affected.vulnerable = false

func vuln_used(_args):
	# if an attack.... reduce stacks
	if TurnManager.action_being_used_right_now and stacks > 0:
		stacks -= 1
		if stacks == 0:
			end_effect()

func get_class_name() -> String:
	return "se_Vulnerable"
