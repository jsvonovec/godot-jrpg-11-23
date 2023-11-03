extends Action

class_name action_Stunned

func _init() -> void:
	super._init()
	target_self = true
	target_friendlies = true
	

func _use(_targets):
	pass


func use_message():
	return "%s is Stunned!" % character.name
 

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
