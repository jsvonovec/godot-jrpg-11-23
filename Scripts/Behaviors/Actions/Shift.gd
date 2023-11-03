extends Action

@export var speed_threshold = 100
var max_moves := 1

func _use(_targets):
	var targ = _targets[0]
	character.change_position(character.pos + (int(targ.name) * 1.01))
	pass


func use_message():
	var m = ""
	var t = character.pup.targets[0]
	if t.name[0] == "-":
		for _left in int(t.name[1]):
			m += "<< "
	m += character._get_name()
	if t.name[0] == "+":
		for _right in int(t.name[1]):
			m += " >>"
	return m



#func _update_usability():
#	usable = true
#	return usable

# list of possible targets to start targeting
func possible_initial_targets() -> Array:
	var positions := []
	var party = character.get_party()
	party.erase(character)
	# get possible positions to switch to
	for chara in party:
		if abs(chara.pos - character.pos
		) < max(4 if TurnManager.player_out_of_combat() else 1, 
		min(4,character.speed / speed_threshold)) + 0.1:
			positions.append(chara.pos)
	# turn into objects
	var results := []
	for p in positions:
		var diff = p - character.pos
		diff = round(diff)
		var diffname = str(diff) if diff<0 else "+" + str(diff)
		for child in get_children():
			if child.name == diffname:
				results.append(child)
	return results

var spot_or_spots := "spot"
func get_desc(targ_highlighted = null) -> String:
	max_moves = int(max(1, min(4,character.speed / speed_threshold)))
	spot_or_spots = "spot" + NIU.plur_s(max_moves)
	return super.get_desc(targ_highlighted)

# Extra rules to follow when determining whether
# a target can be multitargetted after a given one.
#func _custom_multitarget_follow_rules(_targets, _candidate) -> bool:
#	return true
