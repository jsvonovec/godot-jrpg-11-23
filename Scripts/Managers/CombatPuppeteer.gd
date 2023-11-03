extends Node

@onready var tp = get_node("/root/TurnPlayer")

var default_status_duration := 1.0
var default_move_speed := 30.0
var cam_room = null
var player_party := []

func _ready() -> void:
	#Overworld.connect("player_change_room", self, "on_player_change_rooms")
	pass

func on_player_change_rooms(to):
	if NIU.iiv(cam_room):
		cam_room.cam_exit_room()
	cam_room = to
	to.cam_enter_room()
	if NIU.iiv(Overworld.previous_player_room):
		Overworld.previous_player_room.disconnect("positions_fixed", 
		on_positions_fixed)
	to.connect("positions_fixed", Callable(self, "on_positions_fixed"))
	# now do it real quick
	if TurnManager.battle_going:
		instant_move = true
		fix_paths()
		instant_move = false
		for chara in to.inhabitants:
			place_entering_chara(chara, chara.pup.switching_rooms)
		fix_cam()
		TurnPlayer.camera.size = 25.5 #+ len(to.get_inhabitants())
		

func place_entering_chara(chara, moving_in):
	if moving_in:
		chara.pup.translate(Vector3.FORWARD * 20.0 * pow(-1, 
		int(!chara.on_players_team)))
		add_move(chara.pup, chara.cell.rel_loc(chara))
	else:
		chara.pup.position = Vector3.ZERO
	chara.pup.save_translation()

func on_positions_fixed():
	fix_paths()
	fix_cam()

func fix_cam():
	TurnPlayer.camera.position = (cam_room.position
	+ TurnPlayer.cam_translation)
	TurnPlayer.camera.look_at(Vector3.UP * 4.5
	+ cam_room.position, Vector3.UP)
	# also fix selection spotlight
	TurnPlayer.get_spot().position = (TurnPlayer.camera.position 
	+ TurnPlayer.selection_spot_offset)

# Makes the combat status UI show for a bit, saying something like
# "Justice -> Froggo A, Parisitologist"
# Action Name -> Targets
# Then disappears after x seconds
func show_action(action: Action, user: TurnCharacter = null, 
duration := default_status_duration):
	duration /= TurnManager.battle_speed
	var text := ""
	# Do Nothing
	if action == null:
		text = "%s does nothing!" % user.rname
	else:
		text += action.use_message()
	await CombatUI.set_status(text, duration)

func show_status(text: String, duration := default_status_duration):
	await CombatUI.set_status(text, duration)

func hide_status():
	CombatUI.hide_status()

### Party line stuff
# Party lines should be IDENTICAL and OFFSET from one another
@onready var player_path = get_node("PlayerPath")
@onready var player_follows = player_path.get_children()
@onready var enemy_path = get_node("EnemyPath")
@onready var enemy_follows = enemy_path.get_children()
@onready var default_follow = get_node("PlayerPath/PathFollowDefault")
# Path function: z = c(P-E)x^2.
# c: path curve
# P: number of characters on PLAYER party
# E: number of characters on ENEMY party
const path_curve := 0.015
const curve_strength := 10
const curve_separation_multiplier := 7.0
var path_endpoint_separation := 20.0
const follow_separation := 9.0
var path_length := 35.0
var path_angle := deg_to_rad(10.0) # recap: angles go CCW!! Right hand rule!

func fix_paths():
	# fix the paths
	updated_paths(player_path.curve, enemy_path.curve)
	# update follows
	update_follows()

# Modifies pcurve and ecurve to be the updated paths.
func updated_paths(pcurve: Curve3D, ecurve: Curve3D):
	# For RPG Mania 3, it's straight lines.
	var pathsep := path_separation()
	var camangle : float = -TurnPlayer.camera.rotation.y + PI / 2.0
	var xprime := Vector3(cos(camangle), 0.0, sin(camangle))
	var zprime := Vector3(-sin(camangle), 0.0, cos(camangle))
	var x_offset := 5.0
	# Player Party Curve
	var P := (pathsep / 2.0) * zprime - x_offset * xprime
	var P0 := P - (cos(path_angle) * path_length * xprime / 2.0
	+ sin(path_angle) * path_length * zprime)
	var P1 := 2.0*P - P0
	pcurve.clear_points()
	pcurve.add_point(P0)
	pcurve.add_point(P1)
	#print("PLAYER: P0 = %s, P1 = %s" % [P0, P1])
	# Enemy Party Curve
	P = -(pathsep / 2.0) * zprime - x_offset * xprime
	P0 = P - (cos(path_angle) * path_length * xprime / 2.0
	- sin(path_angle) * path_length * zprime)
	P1 = 2.0*P - P0
	ecurve.clear_points()
	ecurve.add_point(P0)
	ecurve.add_point(P1)
	#print("ENEMY: E0 = %s, E1 = %s" % [P0, P1])
	
	# Update path length
	#path_length = pcurve.get_baked_length()
	
	# Do it all again if our path is too short
#	if path_length < max(len(Overworld.player_room.get_spawned_friends()) * follow_separation,
#	len(Overworld.player_room.get_spawned_enemies()) * follow_separation):
#		path_endpoint_separation += 5.0
#		updated_paths(pcurve, ecurve)

# Returns z-value of path wrt. x.
func path_z_of_x(x):
	return path_curve * ((len(Overworld.player_room.get_spawned_friends()) -
	len(Overworld.player_room.get_spawned_enemies()))*pow(x,2))

# Returns path separation wrt. party sizes.
func path_separation() -> float:
	#return sqrt(len(TurnManager.player_party) + len(TurnManager.enemy_party))
#	return (sqrt(float(len(Overworld.player_room.get_spawned_friends()) 
#	+ len(Overworld.player_room.get_spawned_enemies())))
#	* curve_separation_multiplier)
	return 18.0


# Updates the follows arrays and assigns them to characters.
func update_follows():
	# ADD NEW ONES
	var pparty : Array = Overworld.player_room.get_spawned_friends()
	var eparty : Array = Overworld.player_room.get_spawned_enemies()
	var needed_follows = len(pparty) - len(player_follows)
	var new_follow
	for _i in range(len(player_follows),len(player_follows)+needed_follows,1):
		new_follow = default_follow.duplicate()
		player_path.add_child(new_follow)
		player_follows.append(new_follow)
	
	needed_follows = len(eparty) - len(enemy_follows)
	for _i in range(len(enemy_follows),len(enemy_follows)+needed_follows,1):
		new_follow = default_follow.duplicate()
		enemy_path.add_child(new_follow)
		enemy_follows.append(new_follow)
	
	# DEAL WITH EXISTING ONES
	var curve_center = path_length / 2
	var chara: TurnCharacter
	# there is enough room
	if player_path.curve.get_baked_length() > follow_separation * len(pparty):
		for i in range(len(pparty)):
			# place each follow at center, displaced by pos.
			chara = pparty[i]
			
			player_follows[i].progress = (curve_center + 
			(chara.pos * follow_separation))# + (randi() % 2) * NIU.ftime()*10.0
			#chara.translation = player_follows[i].translation
			move_chara_to_pos(chara, player_follows[i].position)
	# there is not enough room
	else:
		for i in range(len(pparty)):
			# place each follow at center, displaced by pos.
			chara = pparty[i]
			
			player_follows[i].progress_ratio = (chara.pos + 
			(len(pparty) - 1.0) / 2.0)
			#chara.translation = player_follows[i].translation
			move_chara_to_pos(chara, player_follows[i].position)
	if enemy_path.curve.get_baked_length() > follow_separation * len(eparty):
		for i in range(len(eparty)):
			# place each follow at center, displaced by position.
			chara = eparty[i]
			enemy_follows[i].progress = (curve_center + 
			(chara.pos * follow_separation))# + (randi() % 2) * NIU.ftime()*10.0
			#chara.translation = enemy_follows[i].translation
			move_chara_to_pos(chara, enemy_follows[i].position)
	# there is not enough room
	else:
		for i in range(len(eparty)):
			# place each follow at center, displaced by pos.
			chara = eparty[i]
			
			enemy_follows[i].progress_ratio = (chara.pos + 
			(len(eparty) - 1.0) / 2.0) / (len(eparty) - 1.0)
			#chara.translation = player_follows[i].translation
			move_chara_to_pos(chara, enemy_follows[i].position)

func move_chara_to_pos(chara, pos):
	var orig_pos = chara.cell.rel_loc(chara.pup)
	chara.position = pos
	chara.cell.set_rel_loc(chara.pup, orig_pos)
	if !instant_move:
		add_move(chara.pup, pos, default_move_speed, true)
	else:
		add_move(chara.pup, pos, -1.0, true)

func anybody_is_moving() -> bool:
	for chara in Overworld.player_room.gse() + Overworld.player_room.gsf():
		if chara.moving:
			return true
	return false






## ANIMATIONS
## ANIMATIONS
## ANIMATIONS
func _____ANIMATIONS_____(): pass
## ANIMATIONS
## ANIMATIONS
## ANIMATIONS

signal start_anims
signal done_with_anims

var instant_move = false

var anim_queue := []
var delta_time := 1.0/60.0
var move_speed := 30.0
var still_animating = false

# Movement destinations are relative to the cell's origin
func add_move(origin: Node3D, dest: Vector3, _move_speed := move_speed,
simultaneous := true) -> Anim:
	var anim = Anim.new()
	anim.setup_move(origin, dest, _move_speed, simultaneous)
	anim_queue.append(anim)
	return anim

func add_animation_library(origin: Node3D, target: Node3D, path := "", 
speed := 1.0) -> Anim:
	var anim = Anim.new()
	if origin.get_class_name() == "Puppet": origin = origin.c
	anim.setup_anim(origin, target, speed, path)
	anim_queue.append(anim)
	return anim

func add_animation_existing(origin: Node3D, target: Node3D, node = null, 
speed := 1.0) -> Anim:
	var anim = Anim.new()
	if origin.get_class_name() == "Puppet": origin = origin.c
	anim.setup_existing_anim(origin, target, speed, node)
	anim_queue.append(anim)
	return anim

func add_room_change() -> Anim:
	var anim = Anim.new()
	anim.is_room_change = true
	anim.simultaneous = false
	anim_queue.append(anim)
	return anim

# Adds an empty anim for use in applying effects, like
# ending status effects and stuff.
func add_blank() -> Anim:
	var anim = Anim.new()
	anim.simultaneous = false
	anim.blank = true
	anim_queue.append(anim)
	return anim

func add_status_change_to_anim(status_effect, show = null, stacks = null,
dur = null, extra = null) -> void:
	anim_queue[-1].add_effect_se(status_effect,
	show, stacks, dur, extra)

var __curr_anim : Anim = null
func get_current_anim() -> Anim:
	return __curr_anim

func get_last_added_anim() -> Anim:
	return anim_queue[-1] if len(anim_queue) > 0 else add_blank()

func ensure_blank_anim() -> Anim:
	# ANIM: add new blank anim to put effects on
	if len(anim_queue) == 0 or !get_last_added_anim().blank:
		return add_blank()
	return get_last_added_anim()

func play_anims() -> void:
	player_party = TurnPlayer.party
	still_animating = true
	TurnPlayer.unhighlight_all()
	CombatUI.queue_redraw()
	var anims_to_yield_to = []
	var origins = []
	var anim_queue_dupe = anim_queue.duplicate()
	emit_signal("start_anims")
	while len(anim_queue) > 0:
		var anim = anim_queue[0]
		anim_queue.remove_at(0)
		__curr_anim = anim
		# skip this one if there's another simultaneous one for this origin
		# later on
		var skip = false
		if anim.simultaneous:
			for a in anim_queue:
				if !a.simultaneous:
					break
				if a.origin == anim.origin and NIU.iiv(anim.origin):
					skip = true
					break
		if skip:
			continue
		# room change
		if anim.is_room_change:
			on_player_change_rooms(Overworld.player_room)
			continue
		anim.play()
		anims_to_yield_to.append(anim)
		origins.append(anim.origin)
		# do all next simultaneouses
		if anim.simultaneous and len(anim_queue) > 0 and anim_queue[0
		].simultaneous and anim.move == anim_queue[0].move and !origins.has(
		anim_queue[0].origin):
			continue
		# finish simultaneouses
		else:
			for a in anims_to_yield_to:
				if !a.finished:
					await a.done
			anims_to_yield_to.clear()
			origins.clear()
	still_animating = false
	__curr_anim = null
	for chara in Overworld.player_room.inhabitants:
		chara.pup.match_character()
	for anim in anim_queue_dupe:
		if is_instance_valid(anim.animation) and anim.animation.destroy_on_finish:
			if is_instance_valid(anim.parent):
				anim.parent.queue_free()
			else:
				anim.animation.queue_free()
	player_party = TurnPlayer.party
	CombatUI.queue_redraw()
	if !TurnManager.game_lost():
		TurnPlayer.selected_character.highlight_ui()
	emit_signal("done_with_anims")

func _process(delta: float) -> void:
	delta_time = delta
	# DEBUG DEBUG DEBUG DEBUG
#	update_follows()
#	for chara in get_tree().get_nodes_in_group("turn_characters"):
#		chara.pup.translation = chara.translation

