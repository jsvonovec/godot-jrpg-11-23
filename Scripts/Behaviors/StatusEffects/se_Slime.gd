extends StatusEffect

class_name se_Slime

const TICK = TICK_EVENT.TURN_START

var remove_should_be_ignored = false
var base_duration : int

func _ready() -> void:
	if remove_should_be_ignored:
		queue_free()

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _icon, _duration, _base_name = ""):
	duration = _duration
	base_duration = _duration
#	stacks = 1
	is_buff = true
	name = "Slimey"
	removable = false
	InfoSingleton.slime_count += 1
	base_name = _affected.name if _base_name == "" else _base_name
	_affected.name = base_name + " " + str(InfoSingleton.slime_count)
	_finish_constructor(_caster, _affected, _icon, TICK, null)
	increment_name()


# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

# override this in extending scripts
#func _tick_effect(_arg = null):
#	pass
var base_name : String
func increment_name():
	affected.name = base_name + " " + str(InfoSingleton.slime_count)

# override this in extending scripts
func _remove_status_effect(_arg = null):
	# first, skip if we're duplicated from a previous se_Slime
	# and shouldn't exist
	if remove_should_be_ignored: return
	remove_should_be_ignored = true
	# un-name affected
	affected.name = base_name
	# duplicate affected
# warning-ignore:return_value_discarded
	var packed_scene := PackedScene.new()
	# reapply this
	get_script().new(affected, affected, icon, base_duration)
	# WARNING: This may cause issues with node ownership, or
	# anything else ---- pack() is dangerous!!!!!!
	packed_scene.pack(affected)
	# duplicate affected
	var dupe = packed_scene.instantiate()
	affected.cell.add_character(dupe, affected.pos - 0.5 + randf())
	dupe.name = base_name
	dupe.default_hp = affected.hp
	dupe.hp = affected.hp
	dupe.default_res = affected.resource.duplicate()
	# apply status effects
	for se in affected.status_effects_active.duplicate():
		if se.get_script() != get_script():
			se._duplicate(dupe)
	dupe.on_turn_started()

# The The message for when it's applied. Override it!
func _application_message() -> String:
	return "%s is %s!" % [affected.name, name]

# To be overridden. Updates the name of the SE
#func _get_name():
#	return name


# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, _time_left, base_name)
