extends StatusEffect

class_name se_Bloodthirsty

const TICK = TICK_EVENT.TURN_END
const ICON_PATH = "res://Sprites/Emoji/twe_juicebox.png"
const BLEED_CHANCE = 0.5
const BLEED_DURATION = 3
const DAMAGE_MULT = 1.5

func get_class_name() -> String:	return "se_Bloodthirsty"

var boosted = false

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _duration):
	caster = _caster
	affected = _affected
	duration = _duration
#	stacks = 1
	is_buff = true
	removable = true
	if merge_with_same(false, false, false, true):
		return
	var _icon = load(ICON_PATH)
	name = "Bloodthirsty"
	_finish_constructor(_caster, _affected, _icon, TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, duration)
# override this in extending scripts
func _apply_status_effect(_arg = null):
	affected.connect("se_damaged_other", Callable(self, "on_attack"))
	for i in range(len(affected.atk)):
		affected.atk[i] *= DAMAGE_MULT
	boosted = true

func on_attack(target):
	# maybe apply bleed
	if randf() < BLEED_CHANCE:
		se_Bleed.new(affected, target, BLEED_DURATION)

# override this in extending scripts
func _remove_status_effect(_arg = null):
	if boosted:
		affected.disconnect("se_damaged_other", Callable(self, "on_attack"))
		for i in range(len(affected.atk)):
			affected.atk[i] /= DAMAGE_MULT

# The The message for when it's applied. Override it!
#func _application_message() -> String:
#	if is_buff:
#		return "%s is buffed with %s!" % [affected.name, name]
#	return "%s is debuffed with %s!" % [affected.name, name]

# To be overridden. Updates the name of the SE
#func _get_name():
#	return name
