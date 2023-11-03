extends Node

signal rooms_done_setting_up
signal player_change_room
signal all_rooms_done_with_signal

@export var all_rooms := []
var all_Rooms := []
@export var starting_room : NodePath
@export var room_connections : Array

var player_room : Cell
var previous_player_room : Cell

var days_elapsed := 0

# Returns an array of ROOMS.
func get_all_rooms() -> Array:
	var results := []
	# get any non-child rooms; they would be the starting cell,
	# for debug purposes.
	if NIU.get_class_name(get_tree().current_scene) == "Cell":
		var sceneroom = get_tree().current_scene
		starting_room = get_path_to(sceneroom)
		#add_child(sceneroom)
		all_rooms.append(get_path_to(sceneroom))
	results.append_array(convert_to_Rooms(all_rooms))
	all_Rooms = results.duplicate()
	return results

# Converts NodePaths to Rooms.
func convert_to_Rooms(array: Array) -> Array:
	var results := []
	for path in array:
		results.append(get_node(path))
	return results

func _ready() -> void:
	TurnManager.connect("battle_start", Callable(self, "on_battle_start"))
	connect("all_rooms_done_with_signal", Callable(self, "___"))

# Checks for bad cell connections. Probably will help, since
# this system sucks.
func update_connections() -> void:
	var i := 0
	var source : Cell
	var rooms_unchecked := get_all_rooms()
	# clear connections
	for cell in all_Rooms:
		cell.connections_ow_use_only.clear()
	for group in room_connections:
		source = get_node(group[0])
		# break if we've done this source already
		if !rooms_unchecked.has(source):
			if all_Rooms.has(source):
				printerr("ERROR: Array #%d's source, %s, is a dupe!"
				% [i, source.name])
			else:
				printerr("ERROR: Array #%d's source, %s, is not in all_rooms!"
				% [i, source.name])
		for member in convert_to_Rooms(group):
			if member != source and !source.connections_ow_use_only.has(
				member):
				# Everything is in order, good ending
				source.connections_ow_use_only.append(member)
				# Assume two-way for now
				member.connections_ow_use_only.append(source)
		i += 1
	# Spam the log to verify
#	for cell in all_Rooms:
#		for c in cell.connections_ow_use_only:
#			print("%s is connected to %s." % [cell.name, c.name])
	pass

# Returns an array of connected rooms to the source.
func get_connected_rooms(source: Cell) -> Array:
	update_connections()
	return source.connections_ow_use_only.duplicate()

func on_battle_start() -> void:
	days_elapsed = 0
	update_connections()
	# tell rooms player isn't in it
	for cell in get_all_rooms():
		cell.player_exit_room()
	player_go_to_room(get_node(starting_room))
	await get_node(starting_room).all_characters_spawned
	TurnPlayer.party = get_node(starting_room).gsf()
	emit_signal("rooms_done_setting_up")

# Move the player to a different cell with the given characters.
# to: the cell to go to.
# with: the characters to go to the cell with.
# force: ignores any issues any of the characters may have with moving.
func player_go_to_room(to, with := [], force := false) -> void:
	TurnPlayer.switching_rooms = true
	previous_player_room = player_room
	# Translate from nodepath to cell
	if to is NodePath:
		to = get_node(to)
	# Don't move if one of the with's can't move rooms
	for passenger in with:
		if !passenger.can_leave_room and !force:
			return
	if player_room != null:
		# Tell everyone in previous cell that player's not in the cell anymore
		# Note that just because they're not in the same cell as the player
		# doesn't mean they're done with their turn based combat!!!!!!!
		player_room.player_exit_room()
	player_room = to
	if player_room != null:
		await player_room.player_enter_room()
		# TODO: await for this to finish so it can spawn
		# all the enmies, and see what happens
	TurnPlayer.on_change_rooms(to)
	emit_signal("player_change_room", to)
	days_elapsed += 1
	print("Days elapsed: %d" % days_elapsed)


func may_heal_party() -> bool:
	return (player_room.full_heal and TurnManager.player_out_of_combat()
	and !TurnManager.actions_processing)

func heal_player_party():
	if may_heal_party():
		for chara in TurnPlayer.party:
			chara.full_heal(false, false)
			chara.end_all_status_effects()
			chara.free_heals = max(chara.free_heals, 1)
		TurnManager.end_current_turn()
		Overworld.days_elapsed += 1




func get_class_name(): return "Overworld"


var rooms_completed := []
# Like this:
# Overworld.room_done_with_signal(self)
func room_done_with_signal(cell):
	if !rooms_completed.has(cell):
		rooms_completed.append(cell)
		if len(rooms_completed) == len(all_rooms) and TurnManager.waiting_for_signal:
			print("cell %s is the last one done!" % cell.name)
			emit_signal("all_rooms_done_with_signal")
			rooms_completed.clear()


func ___():
	pass

# Like this:
# yield(Overworld.yield_until_all_rooms_signals_done(), "completed")
#func yield_until_all_rooms_signals_done():
#	# Skip the wait if all rooms are somehow already done
#	if len(rooms_completed) == len(all_rooms):
#		emit_signal("all_rooms_done_with_signal")
#	# wait until all rooms return that they're done
#	else:
#		yield(self, "all_rooms_done_with_signal")
#	# reset number
#	rooms_completed.clear()



func _process(_delta: float) -> void:
	# DEBUG: move player to next cell
	if Input.is_action_just_pressed("debug_p"):
		var next = (all_rooms.find(get_path_to(player_room)) + 1
		) % len(all_rooms)
		#print(get_path_to(player_room))
		#print(str(all_rooms[0]))
		print("Moving rooms: %s to %s!" % [player_room.name, all_rooms[next]])
		player_go_to_room(all_rooms[next])
