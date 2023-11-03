extends StatusEffect

class_name se_Reversal

const TICK = TICK_EVENT.TURN_END

func get_class_name() -> String:	return "se_Reversal"

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _duration):
	duration = _duration
	affected = _affected
	stacks = 1
	if merge_with_same(false, false, false, false):
		return
	is_buff = true
	removable = true
	name = "Reversal"
	affected.connect("se_about_to_be_attacked", about_to_be_attacked.bind(affected),
	CONNECT_ONE_SHOT)
	_finish_constructor(_caster, _affected, 
	preload("res://Sprites/Emoji/twe_mousetrap.png"), TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, duration)

func about_to_be_attacked(attacker, _sender):
	# About to die
	if attacker.selected_action.calc_dmg(_sender) > _sender.hp:
		# cancel the action
		attacker.deselect_action()
		# kill em
		attacker.die()
		
		attacker.cell.print_in_room("%s is killed from Reversal!!!" 
		% attacker._get_name())
	end_effect()
