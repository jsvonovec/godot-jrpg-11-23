extends StatusEffect

class_name se_Defending

const ICON_PATH = "res://Sprites/Emoji/twe_shield.png"

func _init(_caster, _affected, dur = 1):
	duration = dur
	affected = _affected
	caster = _caster
	if merge_with_same(false, false, false, true):
		return
	is_buff = true
	only_on_screen = false
	name = "Protected"
	_finish_constructor(_caster, _affected,	preload(ICON_PATH), 
	TICK_EVENT.TURN_END, null)

func _apply_status_effect(_arg = null) -> void:
	affected.protected = true

func _remove_status_effect(_arg = null) -> void:
	affected.protected = false

func _application_message() -> String:
	return "%s is Protected!" % [affected.name]


# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon)
