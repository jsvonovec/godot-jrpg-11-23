extends Action


# Replaces this skill with the last-used one of the target.
func _use(_targets):
	for target in _targets:
		var new_action = target.last_used_action.duplicate()
		if NIU.iiv(new_action):
			var p = get_parent()
			var i = p.get_children().find(self)
			p.add_child(new_action)
			p.remove_child(self)
			p.move_child(new_action, i)
			character.update_action_lists()
			CombatUI.set_status("%s copied %s's %s!" % [
			character._get_name(), target._get_name(), new_action.name], 3.0)

func replace_in_action_list(list, new_action):
	for i in range(len(list)):
		var j = list[i].find(self)
		if j != -1:
			list[i][j] = new_action
			return


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
