extends Node3D

class_name Cell

signal turn_started
signal turn_ended
signal positions_fixed
#signal combatant_killed
# warning-ignore:unused_signal
signal all_characters_spawned

# Connections to adjacent rooms. First thing is the ROOM's NODE PATH,
# and the second thing is the DIRECTION (a vector3). If set to (0,0,0),
# it will automatically assign the direction to be the line between the 
# two rooms spatially.
#export (Dictionary) var connections : Dictionary
@export var full_heal = false
@export var force_simulate = false

# If true, this cell may do actions and stuff even when the
# player isn't there.
var simulate := false
var player_in_room := false
# The TurnCharacters within this cell. Which team they're on is
# determined by their on_players_team parameters.
var inhabitants : Array
var chara_placeholders : Array
var se_added_this_turn := []
# DO NOT TOUCH! OVERWORLD USE ONLY!!!!!!!!!!!
var connections_ow_use_only := []
var exit_inhab_queue := []
var enter_inhab_queue := []

func _ready() -> void:
	simulate = simulate or force_simulate
	# Get each child and see if they're either a character or placeholder
	for child in get_children():
		if child is TurnCharacter:
			add_character(child)
			child.player_in_same_room = false
		elif child is CharacterPlaceholder:
			chara_placeholders.append(child)
	
	# Subscriptions!
	TurnManager.connect("battle_start", on_battle_start)
	TurnManager.connect("turn_started", on_turn_started)
	TurnManager.connect("begin_action_processing", on_actions_processing)
	TurnManager.connect("turn_ended", on_turn_ended)
	TurnManager.connect("characters_exit_rooms",
	on_characters_exit_rooms)
	TurnManager.connect("characters_enter_rooms",
	on_characters_enter_rooms)
	
	# Spawn placeholders if we're ismulating already
	if simulate:
		start_simulating()

func on_battle_start():
	if simulate:
		start_simulating()

func _process(_delta):
	visible = player_in_room

func on_actions_processing() -> void:
	for chara in inhabitants:
		chara.pup.save_translation()
	if simulate:
		var turn_order = calculate_turn_order()
		
		
		for turn_character in turn_order:
			# Remove characters if they're not here
			for se in turn_character.status_effects_active:
				if !is_instance_valid(se.caster) or se.caster.cell != self:
					se._on_caster_died([])
			turn_character.emit_signal("se_action_phase_started")
		
		se_added_this_turn.clear()
		for turn_character in turn_order:
			if !inhabitants.has(turn_character):
				continue
			# Do actions
			turn_character.perform_action()
			se_added_this_turn.clear()
	call_on_inhabitants("on_action_processing", [])
	# Tell overworld we're done with the signal
	Overworld.room_done_with_signal(self)

func on_characters_enter_rooms() -> void:
	# Add all characters queued to enter this cell.
	for chara in enter_inhab_queue.duplicate():
		if !chara.dead:
			add_character(chara, null, false)
	if TurnPlayer.switching_rooms:
		CombatPuppeteer.instant_move = true
	fix_positions()
	if TurnPlayer.switching_rooms:
		CombatPuppeteer.instant_move = false
	enter_inhab_queue.clear()
	Overworld.room_done_with_signal(self)

func on_characters_exit_rooms() -> void:
	# First, TICK ALL NON-TURN-START STATUS EFFECTS!
	for chara in exit_inhab_queue.duplicate():
		for se in chara.status_effects_active:
			if [StatusEffect.TICK_EVENT.ACTION_PROCESSING_START,
			StatusEffect.TICK_EVENT.AFTER_AFFECTED_ACT,
			StatusEffect.TICK_EVENT.AFTER_CASTER_ACT,
			StatusEffect.TICK_EVENT.BEFORE_AFFECTED_ACT,
			StatusEffect.TICK_EVENT.BEFORE_CASTER_ACT,
			StatusEffect.TICK_EVENT.TURN_END].has(se._tick_event):
				se.on_tick_event()
		# Now remove them if they died
		if chara.dead:
			exit_inhab_queue.erase(chara)
			
	# Remove all characters queued to leave from this cell.
	for chara in exit_inhab_queue.duplicate():
		remove_character(chara)
	exit_inhab_queue.clear()
	Overworld.room_done_with_signal(self)

func on_turn_started() -> void:
	call_on_inhabitants("on_turn_started", [])
	emit_signal("turn_started")
	Overworld.room_done_with_signal(self)

func on_turn_ended() -> void:
	checked_e_l = false
	checked_p_l = false
	call_on_inhabitants("on_turn_ended", [])
	emit_signal("turn_ended")
	clear_dead_characters_from_parties()
	fix_positions()
	Overworld.room_done_with_signal(self)

# Returns an array of TurnCharacters to go in order when action phase begins.
func calculate_turn_order(random = true) -> Array:
	var order := inhabitants.duplicate()
	
	# randomize it a little bit
	if random:
		for tc in order:
			tc.speed_fudge = randf_range( 
				-TurnManager.speed_randomization_range,
				TurnManager.speed_randomization_range)
	
	# sort it!
	order.sort_custom(Callable(TurnManager, "sort_action_order_descending"))
	
	return order

func call_on_inhabitants(method: String, args := []):
	var speed_order = calculate_turn_order()
	for inhab in speed_order:
		inhab.callv(method, args)
	

# Used whenever a turn-based character dies.
func combatant_killed(_character):
	fix_positions()
	call_on_inhabitants("on_character_killed", [_character])

# put positions near each other and resolve same positions
func fix_positions():
	# Actually don't, if battle isn't happening
	if !TurnManager.battle_going:
		return
	# sort
	#clear_dead_characters_from_parties()
	var player_party := []
	var enemy_party := []
	for chara in inhabitants:
		if chara.on_players_team:
			player_party.append(chara)
		else:
			enemy_party.append(chara)
	player_party.sort_custom(Callable(TurnManager, "sort_position_ascending"))
	enemy_party.sort_custom(Callable(TurnManager, "sort_position_ascending"))
	
	# go through them
	# make it so that the middle pos will be 0 and uneven middle positions
	# will be -0.5 and 0.5
	var i = -float(len(player_party)) / 2.0 + 0.5
	for tc in player_party:
		tc.pos = i
		i += 1
	i = -float(len(enemy_party)) / 2.0 + 0.5
	for tc in enemy_party:
		tc.pos = i
		i += 1
	
	call_on_inhabitants("on_positions_fixed", [])
	emit_signal("positions_fixed")


# removes dead characters from parties and deletes them
func clear_dead_characters_from_parties():
	var inhabs = inhabitants.duplicate()
	for chara in inhabs:
		if chara.dead:
			remove_character(chara, true, true)

func add_character(chara, pos = null, fixpos = true) -> void:
	if chara.is_part_of_a_room():
		# skip if we're adding to ourself
		if chara.cell == self:
			return
		chara.cell.remove_character(chara)
	
	if pos is float:
		chara.pos = pos
	chara.cell = self
	chara.destination_room = null
	chara.player_in_same_room = player_in_room
	chara.visible = player_in_room
#	connect("turn_started", chara, "on_turn_started")
#	connect("turn_ended", chara, "on_turn_ended")
#	connect("combatant_killed", chara, "on_character_killed")
#	connect("positions_fixed", chara, "on_positions_fixed")
	inhabitants.append(chara)
	if NIU.iiv(chara.get_parent()):
		chara.get_parent().remove_child(chara)
	add_child(chara)
	if fixpos:
		fix_positions()
	if (Overworld.player_room == self and chara.on_players_team 
	and !TurnPlayer.party.has(chara)):
		TurnPlayer.party.append(chara)
	print_in_room("%s moved into this cell." % chara.name)

func remove_character(chara, fixpos = true, keep_in_room = false) -> void:
	inhabitants.erase(chara)
#	disconnect("turn_started", chara, "on_turn_started")
#	disconnect("turn_ended", chara, "on_turn_ended")
#	disconnect("combatant_killed", chara, "on_character_killed")
#	disconnect("positions_fixed", chara, "on_positions_fixed")
	if !keep_in_room:
		chara.cell = null
		remove_child(chara)
	if fixpos: fix_positions()
	print_in_room("%s moved out of this cell." % chara.name)
	#breakpoint

# What to do when the palyer enters this cell.
func player_enter_room() -> void:
	# Spawn all characters
	spawn_placeholders(true)
	await self.all_characters_spawned
	player_in_room = true

func cam_enter_room() -> void:
	visible = true
	# Tell all inhabitants that they're in the cell
	# (all this does is makes them visible)
	for inhab in inhabitants:
		inhab.on_player_enters_room()

func player_exit_room() -> void:
	player_in_room = false

func cam_exit_room() -> void:
	visible = false
	# Tell all inhabitants that they're in the cell
	# (all this does is makes them visible)
	for inhab in inhabitants:
		inhab.on_player_exits_room()

func get_inhabitants() -> Array:
	return inhabitants

func get_all_placeholders() -> Array:
	return chara_placeholders

func gse() -> Array: return get_spawned_enemies()
func get_spawned_enemies() -> Array:
	var results := []
	for inhab in inhabitants:
		if !inhab.on_players_team:
			results.append(inhab)
	return results

func gsf() -> Array: return get_spawned_friends()
func get_spawned_friends() -> Array:
	var results := []
	for inhab in inhabitants:
		if inhab.on_players_team:
			results.append(inhab)
	return results

func get_inhab_in_pos(pos: float, players_team: bool):
	var party = gsf() if players_team else gse()
	
	var closest = null
	for chara in party:
		if !NIU.iiv(closest) or abs(
		chara.pos - pos) < abs(closest.pos - pos):
			closest = chara
	return closest

func positions_are_whole(on_players_team: bool) -> bool:
	var p = gsf() if on_players_team else gse()
	if len(p) == 0:
		return true
	return int(abs(p[0].pos * 2.0)) % 2 == 0

var player_lethals := []
var checked_p_l = false
var enemy_lethals := []
var checked_e_l = false
func get_lethals(on_player) -> Array:
	if on_player and checked_p_l: return player_lethals
	if !on_player and checked_e_l: return enemy_lethals
	var results := []
	var party = gse() if on_player else gsf()
	# Run check-for-lethal on player party - get possible kills
	for c in party:
		for lethal in c.ai.damage_check(false, true):
			results.append(lethal)
	if on_player:
		player_lethals = results
		checked_p_l = true
	else:
		enemy_lethals = results
		checked_e_l = true
	return results

# Returns true if all the inhabitants of this cell have been spawned.
func all_inhabitants_spawned() -> bool:
	return len(chara_placeholders) == 0

func start_simulating() -> void:
	if !simulate:
		print("Cell %s has started simulating.")
	spawn_placeholders(true)

func get_connected_rooms() -> Array:
	return Overworld.get_connected_rooms(self)

func queue_to_enter(chara):
	# Just skip if they're already here or entering
	if exit_inhab_queue.has(chara) or enter_inhab_queue.has(chara):
		return
	if is_instance_valid(chara.destination_room):
		chara.destination_room.remove_from_queue(chara)
	
	chara.switching_rooms = true
	chara.pup.switching_rooms = true
	# Add them to the enter queue
	enter_inhab_queue.append(chara)
	chara.destination_room = self
	# Also add them to their cell's exit queue
	if is_instance_valid(chara.cell):
		chara.cell.queue_to_exit_only(chara)

func queue_to_exit_only(chara):
	# Break if they should not be calling this function
	if chara.cell != self or !get_inhabitants().has(chara):
		printerr("ERROR: %s tried to queue to exit %s, but is not an"
		+ " inhabitant of that cell! (%s %s)"
		% [chara.name, name, chara.cell != self, 
		!get_inhabitants().has(chara)])
		return
	# Just skip if they're already leaving
	if exit_inhab_queue.has(chara):
		return
	
	chara.switching_rooms = true
	chara.pup.switching_rooms = true
	# Add them to the exit queue! Get in line!!
	exit_inhab_queue.append(chara)

func remove_from_queue(chara):
	if exit_inhab_queue.has(chara):
		exit_inhab_queue.erase(chara)
	if enter_inhab_queue.has(chara):
		enter_inhab_queue.erase(chara)

# Returns the characters spawned by the palceholders and
# destroys the placeholders.
func spawn_placeholders(_start_simulating := false) -> Array:
	var results := []
	for i in range(len(chara_placeholders) - 1, -1, -1):
		results.append_array(chara_placeholders[i].spawn_characters())
		chara_placeholders.remove_at(i)
	if _start_simulating: simulate = true
	#inhabitants.append_array(results)
	call_deferred("fix_positions")
	call_deferred("emit_signal", "all_characters_spawned")
	return results

# May or may not work :)
#func get_direction_to(cell: NodePath) -> Vector3:
#	var roomindex = connections.keys().find(get_node(cell))
#	# When we have a custom direction to that cell
#	if roomindex >= 0 and connections.values()[roomindex] != Vector3.ZERO:
#		return connections.values()[roomindex]
#	# When we do not, or if they're simply not in the connections list
#	else:
#		return (get_node(cell).translation - translation).normalized()

func print_in_room(text):
	if !(!player_in_room and TurnManager.mute_non_player_room_move):
		print(("[%s] " % name) + text)


func rel_loc(spatial: Node3D):
	return spatial.global_transform.origin - global_transform.origin

func set_rel_loc(spatial: Node3D, loc: Vector3):
	spatial.global_transform.origin = global_transform.origin + loc

static func abs_loc(spatial: Node3D):
	return NIU.abs_loc(spatial)

static func set_abs_loc(spatial: Node3D, loc: Vector3):
	NIU.set_abs_loc(spatial, loc)

static func find_cell(node: Node):
	return NIU.find_cell(node)

func get_class_name(): return "Cell"




