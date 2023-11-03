extends Action

# Every character can either FLEE or DEFEND, NO ACTING WHEN FLEEING

func _use(_target):
	if !character.on_players_team:
		character.queue_to_change_rooms(character.cell)


func use_message():
	return "%s couldn't escape!" % character.name
