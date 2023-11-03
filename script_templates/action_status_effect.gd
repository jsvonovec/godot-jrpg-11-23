extends Action

@export var se_icon : Texture2D
@export var effect_duration = 1
@export var tick_event = StatusEffect.TICK_EVENT.BEFORE_AFFECTED_ACT


# Called when the node enters the scene tree for the first time.
func _use(_targets):
	for target in _targets:
	# warning-ignore:return_value_discarded
		#se_Parasite.new(character, target, 
		#effect_duration, power, leech_fraction, se_icon)
		pass



#func _update_usability():
#	usable = true
#	return usable

# list of possible targets to start targeting
#func possible_initial_targets() -> Array:
#	return get_node("/root/TurnManager").targets_in_range(
#	character, target_range, target_enemies, target_friendlies)


# Extra rules to follow when determining whether
# a target can be multitargetted after a given one.
#func _custom_multitarget_follow_rules(_targets, _candidate) -> bool:
#	return true
