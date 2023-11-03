extends Node


signal selecting_character

# this just affects how many characters you carry into each round.
# So if you had a character that created more allies, those creations
# would not follow through rooms.
const max_party_size = 300

var selected_character = null
var party: Array
var selecting_action = false
var selected_action = null
var selecting_target = false
@onready var camera: Camera3D = get_tree().get_nodes_in_group("main_camera")[0]
var cam_translation : Vector3
var destination_room : Node
var room_history := []
var fleeing := false
var switching_rooms := false
var selection_spot_moving := false
var selection_spot_targ = null
var selection_spot_start_time := 0.0
var spot_def_energy := 1.0
var spot_energy := 1.0
const selection_spot_move_duration := 1.5
const selection_spot_lerp_factor := 0.2
const selection_spot_offset := Vector3(30.0, 40.0, 30.0) # used in CombatPuppeteer
const selection_spot_energy_lerp_factor := 0.001 # multiplied by tempo
const selection_spot_pulse_energy := 1.5
const selection_spot_color_lerp_factor := 0.1
func get_spot(): return $SpotLight3D

func _ready() -> void:
	print("Press 'Page Up' to mute music.")
	spot_def_energy = $SpotLight3D.light_energy

func start_battle(_turnmanager):
# warning-ignore:return_value_discarded
	TurnManager.connect("turn_started", Callable(self, "on_turn_started"))
# warning-ignore:return_value_discarded
	TurnManager.connect("turn_ended", Callable(self, "on_turn_ended"))
	cam_translation = camera.position
	SoundOp.connect("new_beat", Callable(self, "pulse_spot"))

func on_turn_started():
	select_character(-1)
	force_move = false
	switching_rooms = false

func on_turn_ended():
	selected_character = null
	

func wants_to_flee() -> bool:
	for pp in party:
		if is_instance_valid(pp.selected_action
		) and pp.selected_action.flee:
			return true
	return false

# Attempts to flee. If unsuccessful, the party stays put.
# If successful, the party moves to the PREVIOUS ROOM.
func flee_try():
	if len(room_history) > 0 and flee_check():
		destination_room = room_history[-1]
		room_history.remove_at(len(room_history) - 1)
		fleeing = true
		print("PLAYER: Successful flee to %s!" % destination_room.name)
	else:
		print("PLAYER: Unsuccessful flee!")

# The function that calculates whether a flee should go through.
func flee_check() -> bool:
	# For now, make it a 50/50.
	return randi() % 2 == 0

# Returns true if fleeing is at all possible.
func flee_possible() -> bool:
	return len(room_history) > 0

# Whether the player may move freely between rooms - 
# all enemies are dead or incapacitated.
func may_move() -> bool:
	if force_move:
		force_move = false
		return true
	# Disallow movement if any enemies exist.
	
	for e in Overworld.player_room.gse():
		return false
	return true

# Called by Room after all the other stuff is handled.
func on_change_rooms(_to):
	if Overworld.previous_player_room != null and !fleeing:
		room_history.append(Overworld.previous_player_room)
	#camera.translate(to_pos - prev_pos)
	fleeing = false


func unhighlight_all():
	for character in get_tree().get_nodes_in_group("turn_characters"):
		if !character.is_queued_for_deletion():
			character.un_highlight_ui()

func _process(_delta):
	if (!TurnManager or !TurnManager.battle_going 
	or TurnManager.actions_processing): return
	# grab all the inputs
	# selecting character
#	if(Input.is_action_just_pressed("ui_down")):
#		select_next_character()
#		selecting_target = false
#		selected_action = null
#	elif(Input.is_action_just_pressed("ui_up")):
#		select_previous_character()
#		selecting_target = false
#		selected_action = null
	
	# Mute/unmute music
	if Input.is_action_just_pressed("ui_page_up"):
		AudioServer.set_bus_mute(2, !AudioServer.is_bus_mute(2))
	
	# Open character sheet
	if Input.is_action_just_pressed("ui_character_sheet"):
		CharacterSheet.toggle()
	
	process_action_selection()
	
	# move selection spotlight, or fade it out
	process_move_spot()
	process_pulse_spot()

func process_move_spot():
	if selection_spot_moving:
		# current pos
		var destination = $SpotLight3D.transform.looking_at(
		selection_spot_targ.global_transform.origin, Vector3.UP)
		var color_dest = selection_spot_targ.p_color
		# jump to destination
		if NIU.ftime() - selection_spot_start_time > selection_spot_move_duration:
			selection_spot_moving = false
			$SpotLight3D.transform = $SpotLight3D.transform.interpolate_with(destination, 1.0)
			$SpotLight3D.light_color = color_dest
		# move slowly to destination
		else:
			$SpotLight3D.transform = $SpotLight3D.transform.interpolate_with(destination,
			selection_spot_lerp_factor)
			$SpotLight3D.light_color = $SpotLight3D.light_color.lerp(
			color_dest, selection_spot_color_lerp_factor)

func pulse_spot(_beat_count):
	$SpotLight3D.light_energy = selection_spot_pulse_energy * spot_energy

func process_pulse_spot():
	var t = selection_spot_energy_lerp_factor * SoundOp.tempo
	$SpotLight3D.light_energy = lerp($SpotLight3D.light_energy, spot_energy, t)

func select_next_character():
	select_character("-1")

func select_previous_character():
	select_character("+1")

func select_character(index):
	# skip if we have no party
	if len(party) == 0:
		selected_character = null
		return
	# unhighlight previous character
	if NIU.iiv(selected_character):
		selected_character.un_highlight_ui()
	# increment or decrement if that's what we want
	if index is String and (index == "+1" or index == "-1"):
		var pos = (int(index == "+1") - 1) * 2 + 1 # -1 or 1
		#index = int(index == "+1") - 1 # -1 or 0
		if selected_character != null:
			#index = (party.find(selected_character) + (index * 2) + 1) # -1 or +1
			pos += selected_character.pos
			pos = pos if pos <= (len(party) / 2.0 - 0.49) else pos - len(party)
			pos = pos if pos >= (-len(party) / 2.0 + 0.49) else pos + len(party)
			selected_character = null
			for chara in party:
				if abs(chara.pos - pos) < 0.25:
					selected_character = chara
			assert(is_instance_valid(selected_character))
	else:
		selected_character = party[index % len(party)]
	
	selected_character.highlight_ui()
	
	emit_signal("selecting_character", selected_character)
	# Update character sheet theme's colors
	CharacterSheet.theme.set_color("font_color", "Label", 
	selected_character.p_color)
	CharacterSheet.theme.set_color("bg_color", "NinePatchRect", 
	selected_character.s_color)
	CharacterSheet.queue_redraw()
	
	# move spotlight
	move_selection_spotlight(selected_character)

func move_selection_spotlight(chara):
	selection_spot_targ = chara
	selection_spot_moving = true
	selection_spot_start_time = NIU.ftime()


var spot_fade_dur := 2.0
func turn_off_spot() -> void:
	selection_spot_moving = false
	create_tween().tween_property(self, "spot_energy", 0.0, 
	spot_fade_dur * SoundOp.beat_dur())

func turn_on_spot() -> void:
	create_tween().tween_property(self, "spot_energy", spot_def_energy, 
	spot_fade_dur * SoundOp.beat_dur())

func process_action_selection():
	pass
#	# character orders
#	# skip if we have no character
#	if !is_instance_valid(selected_character): return
#	#TODO: make this scriipt work! it does nothing in runtime right now!
#
#	# start selecting an action if it's a new character,
#	# and if they have actions to do
#
#	if (selected_character.selected_action == null and !selecting_target and
#		len(selected_character.visible_actions) > 0):
#		selecting_action = true
#	else:
#		selecting_action = false
#
#	# start figuring out target, which should be AFTER action is selected.
#	# So, it's here so we don't accidentally press 1 to select the first
#	# action then in the same frame select the first target.
#	# This ensures at least 1 frame of time between action and target
#	# selection.
#	if selecting_target and !selecting_action:
#		# highlight all possible targets
#		for targ in selected_action.possible_targets():
#			highlight_target(targ)
#		# ui_1, ui_2, ui_3, etc.
#		# selects target 0, 1, 2, etc.
#		for i in range(1,10):
#			if Input.is_action_just_pressed("ui_" + str(i)):
#				var targets = selected_action.possible_targets()
#				selected_character.select_action(selected_action,
#					targets[(i-1) % len(targets)])
#				selecting_action = false
#				selecting_target = false
#				# unhighlight all possible targets
#				for targ in targets:
#					unhighlight_target(targ)
#				# highlight new target
#				#selected_character.selected_target.highlight_ui()
#				select_next_character()
#				break
#
#	# designating actions
#	# only if their action is null (meaning they have none selected)
#	elif selecting_action:
#		# ui_1, ui_2, ui_3, etc.
#		# selects action 0, 1, 2, etc.
#		for i in range(1,10):
#			if Input.is_action_just_pressed("ui_" + str(i)):
#				var action = selected_character.visible_actions[(
#				(i-1) % len(selected_character.visible_actions))]
#				# DO NOT SELECT if we have no resources for this!
#				var NOT_ENOUGH_RESOURCES = false
#				for l in range(len(action.costs)):
#					if selected_character.resource[l] < action.costs[l]: 
#						NOT_ENOUGH_RESOURCES = true
#				if NOT_ENOUGH_RESOURCES: break
#				# ok we have the resources. Select it
#				selected_action = action
#				selecting_action = false
#				selecting_target = true
#				break
#
#	else:
#		# targeting
#		for targ in selected_character.selected_targets:
#			# highlight target
#			highlight_target(targ)

func highlight_target(target):
	if target.is_class("TurnCharacter"):
		target.highlight_ui()
	elif target.is_class("StatusEffect"):
		target.affected.highlight_ui()

func unhighlight_target(target):
	if target.is_class("TurnCharacter"):
		target.unhighlight_ui()
	elif target.is_class("StatusEffect"):
		target.affected.unhighlight_ui()

var force_move = false
func set_destination_room(cell, _force = false):
	destination_room = cell
	force_move = _force
	if is_instance_valid(cell):
		print("The player party is moving to %s this turn." %  cell.name)
	else:
		print("The player party is no longer changing rooms.")

func get_class_name(): return "TurnPlayer"
