extends Node


# signals
signal characters_enter_rooms
signal turn_started
signal characters_exit_rooms
signal begin_action_processing
signal turn_ended
signal battle_start

# variables
@onready var turn_player := get_node("/root/TurnPlayer")
@onready var combat_ui := get_node("/root/CombatUI")
# +- most the speed can be randomized when comparing for turn order.
@export var default_speed_randomization_range = 10.0
var speed_randomization_range: float
# NOTE: Unless we're in the main menu or something,
# battle should ALWAYS be going.
var battle_going := false
var actions_processing := false
var action_being_used_right_now := false
var battle_about_to_end := false
# Animation speed of battles
var battle_speed := 1.0
@export var starting_level = 1
var player_lvl := 1
var player_exp := 0
var eparty := []
# EXP to level: assumes that, each level, the team can handle
# 1.5x the 'danger' (stats of enemies basically) despite only gaining 1.2x
# the stats each level. So a lvl 5 team (2x stats) can handle lvl 5 encounter
# (5x stats).
# ORIGINAL VALUES: [1000, 2500, 4750, 8125]
@export var exp_to_lvl = [10000, 40000, 700000, 1100000, 16000000]
# The max lives player party members should have.
@export var player_max_lives = 3

@export var mute_non_player_room_actions = false
@export var mute_non_player_room_move = false
@export var mute_does_nothing_logs = true

func _ready() -> void:
	randomize()
	
	# RM3
#	for path in tourney_teams_files:
#		tourney_teams.append(load(path).instance())
	# move player team to start room
#	for team in tourney_teams:
#		if team.player:
#			for c in team.charas:
#				team.remove_child(c)
#				Overworld.convert_to_Rooms([Overworld.starting_room]
#				)[0].add_child(c)
				#c.spawn_characters()
	
#	generate_tournament()
	

func _process(_delta):
	if !battle_going and Time.get_ticks_msec() > 500:
		start_battle()
	if(!battle_going): return
	
	# TESTING! Press space to end turn
	if Input.is_action_just_pressed("ui_select"):
		end_current_turn()
	

# start-of-battle stuff
func start_battle():
	if(battle_going): return
	print("Battle starting!")
	
	#reset vars
	speed_randomization_range = default_speed_randomization_range
	
	
	
	# wait until everyones in pos
#	if CombatPuppeteer.anybody_is_moving():
#		yield(CombatPuppeteer, "finished_moving")
#		print("Finished moving!")
	
	turn_player.start_battle(self)
	combat_ui.start_battle()
	
	
	emit_signal("battle_start")
	await Overworld.rooms_done_setting_up
	CombatPuppeteer.add_room_change()
	CombatPuppeteer.call_deferred("play_anims")
	
	#TurnPlayer.select_next_character()
	emit_signal("turn_started")
	if !should_skip_overworld_yield():
		await Overworld.all_rooms_done_with_signal
	reset_signals()
	while player_lvl < starting_level:
		player_level_up(true)
	CombatUI.on_turn_started()
	battle_going = true

var waiting_for_signal = false
func should_skip_overworld_yield() -> bool:
	if len(Overworld.rooms_completed) == len(Overworld.all_rooms):
		Overworld.rooms_completed.clear()
		waiting_for_signal = false
		return true
	else:
		waiting_for_signal = true
		return false

func reset_signals() -> void:
	Overworld.rooms_completed.clear()
	waiting_for_signal = false

func get_last_acting_chara():
	return __last_acting_chara

func get_last_action():
	return __last_action

var __last_acting_chara = null
var __last_action = null

 

func end_current_turn():
	if(!battle_going): return
	
	# STEPS:
	# Check for flee
	# Characters exit rooms
	# Action Processing
	# Turn end
	# End-of-Combat stuff
	# Characters enter rooms
	# Turn start
	
	# First: flee check!
	if TurnPlayer.wants_to_flee():
		TurnPlayer.flee_try()
	
	# If the player is moving rooms,
	# we should tell all player party members to go there.
	if TurnPlayer.destination_room != null and (
		TurnPlayer.may_move() or TurnPlayer.fleeing):
		for chara in TurnPlayer.party:
			TurnPlayer.destination_room.queue_to_enter(chara)
	else:
		TurnPlayer.destination_room = null
	
	print("TM: Begin character cell exiting.")
	# Move characters out of rooms.
	emit_signal("characters_exit_rooms")
	# Only continue when every cell is done moving characters
	
	actions_processing = true
	
	CombatPuppeteer.get_last_added_anim().add_effect_call(TurnPlayer, "turn_off_spot")
	
	# including the one the player is in.
	if !should_skip_overworld_yield():
		print("TM: waiting for characters to exit rooms.")
		await Overworld.all_rooms_done_with_signal
	reset_signals()
	
	# do actions!
	print("TM: Begin action processing.")
	emit_signal("begin_action_processing")
	# Only continue when every cell is done with action processing
	# including the one the player is in.
	if !should_skip_overworld_yield():
		print("TM: waiting for action processing to end.")
		await Overworld.all_rooms_done_with_signal
	reset_signals()
	
	# delete killed peeps
	freeze_dead_characters()
	
	# end turns
	actions_processing = false
	print("TM: Turn is ending.")
	CombatPuppeteer.add_blank()
	emit_signal("turn_ended")
	if !should_skip_overworld_yield():
		print("TM: waiting for turn end signal.")
		await Overworld.all_rooms_done_with_signal
	reset_signals()
	
	
	
	
	# Move the player to the new cell
	if TurnPlayer.destination_room != null:
		await Overworld.player_go_to_room(TurnPlayer.destination_room)
#		var pgtr = Overworld.player_go_to_room(TurnPlayer.destination_room)
#		if pgtr is GDScriptFunctionState:
#			await pgtr.completed
		eparty = TurnPlayer.destination_room.gse()
		TurnPlayer.destination_room = null
		CombatPuppeteer.add_room_change()
	
	# Move characters into rooms.
	print("TM: Begin character cell entering.")
	emit_signal("characters_enter_rooms")
	# Only continue when every cell is done moving characters
	# including the one the player is in.
	if !should_skip_overworld_yield():
		print("TM: waiting for characters to enter rooms.")
		await Overworld.all_rooms_done_with_signal
	reset_signals()
	
	# lvl up if applicable
	print("TM: Checking for level-ups.")
	if player_out_of_combat() and can_lvl_up():
		player_level_up()
	
	# end of combat
	# check for end of combat to steal a unit
	if player_out_of_combat() and len(eparty) > 0:
		player_level_up(true)
		# duplicate a dead enemy
		var newfriend = eparty[randi() % len(eparty)].duplicate()
		newfriend.dead = false
		newfriend.hp = newfriend.max_hp
		newfriend.default_on_players_team = true
		Overworld.player_room.add_character(newfriend)
		#TurnPlayer.party.append(newfriend)
		newfriend._ready()
		newfriend.pup.visible = false
		newfriend.pup.get_node("Center/RCircle").chara = newfriend
		var a = CombatPuppeteer.add_blank()
		a.add_effect_call(newfriend, "show")
		a.add_effect_call(newfriend.pup, "match_character")
		# delete old frenemy
		if len(TurnPlayer.party) > TurnPlayer.max_party_size:
			var old = TurnPlayer.party[-2]
			TurnPlayer.party.remove_at(len(TurnPlayer.party) - 2)
#			a.add_effect_call(Overworld.player_room, 
#			"remove_character", [old])
#			a.add_effect_call(TurnPlayer, 
#			"remove", [len(TurnPlayer.party) - 2]])
			old.hide()
			old.die()
			eparty.clear()
			end_current_turn()
			
			#Overworld.player_room.remove_character(TurnPlayer.party[-2])
			#TurnPlayer.party.remove(len(TurnPlayer.party) - 2)
		
		#Overworld.player_room.fix_positions()
		
		eparty.clear()
		
		destroy_dead_characters()
		#end_tourney_round()
		
	
	# check for loss
	if !game_lost():
		# New turn!
		print("TM: A new turn is starting.")
		CombatPuppeteer.add_blank()
		emit_signal("turn_started")
		if !should_skip_overworld_yield():
			print("TM: waiting for turn start signal.")
			await Overworld.all_rooms_done_with_signal
		reset_signals()
	
	# Now do animations
	CombatPuppeteer.play_anims()
	if CombatPuppeteer.still_animating:
		await CombatPuppeteer.done_with_anims
	
	# show intents
	if !game_lost():
		var i_anim = CombatPuppeteer.add_blank()
		i_anim.effect_dur[Anim.EFFECT.CALL] = 60.0 / SoundOp.tempo
		i_anim.effect_dur[Anim.EFFECT.SET] = (60.0 / SoundOp.tempo) * (
		1.0 - SoundOp.beat_progress())
		i_anim.add_effect_set(self, "name", name)
		for chara in Overworld.player_room.gse():
			i_anim.add_effect_call(chara.pup, "update_intent_icon")
		CombatPuppeteer.get_last_added_anim().add_effect_call(TurnPlayer, "turn_on_spot")
		CombatPuppeteer.play_anims()
		if CombatPuppeteer.still_animating:
			await CombatPuppeteer.done_with_anims
	
	
	# delete things
	for d in destroys_on_turn_end:
		d.queue_free()
	destroys_on_turn_end.clear()
	

# Sorts by action order. [0] goes first, [-1] goes last.
# Takes priority and speed into account.
# Sort: TRUE if a should be before b.
func sort_action_order_descending(a,b):
	var a_priority = a.selected_action.priority if a.selected_action else 0
	var b_priority = b.selected_action.priority if b.selected_action else 0
	
	if a_priority != b_priority:
		return a_priority > b_priority
	return a.final_speed() > b.final_speed()

# Sorts by speed in descending order. Used to calculate turn order.
func sort_speed_descending(a, b):
	if(a.final_speed() > b.final_speed()):
		return true
	return false

func sort_position_ascending(a,b):
	var ca = a.get_chara()
	var cb = b.get_chara()
	var va = is_instance_valid(ca)
	var vb = is_instance_valid(cb)
	if !va and !vb:
		return a.name > b.name
	if !va or (va and vb and ca.pos < cb.pos):
		return true
	return false


# Returns the character OR CHARACTERS we are within attack_range from.
# This means that each edge characters can see the enemy on the same edge.
func targets_in_range(character, close_range, target_self, 
					target_enemies = true, target_friends = true, 
					atk_range := 3, ignore_custom_rules = false):
	# if atk range is too low: just target self
	if !target_enemies and !target_friends: return [character]
	
	# Don't fix positions, because it could cause many issues
	#fix_positions()
	atk_range = 9999
	close_range = false
	# figure out who's team this is on and who's targetable
	var player_party = character.cell.get_spawned_friends()
	var enemy_party = character.cell.get_spawned_enemies()
	var party
	var targetable_party = Array()
	if character.on_players_team:
		party = player_party
		if target_enemies:
			targetable_party.append_array(enemy_party)
		if target_friends:
			targetable_party.append_array(player_party)
	else:
		party = enemy_party
		if target_enemies:
			targetable_party.append_array(player_party)
		if target_friends:
			targetable_party.append_array(enemy_party)
	# Don't target self if we aren't allowed to
	if !target_self and targetable_party.has(character):
		targetable_party.erase(character)
	# follow custom initial target rules
	for i in range(len(targetable_party) - 1, -1, -1):
		if !ignore_custom_rules and !character.custom_initial_targets_rule(
		targetable_party[i]):
			targetable_party.remove_at(i)
	# just target nothing if we can't target anything
	if len(targetable_party) == 0: return []
	
	var bottom_edge_chars = []
	var top_edge_chars = []
	if len(player_party) > 0 and targetable_party.has(player_party[0]):
		bottom_edge_chars.append(player_party[0])
		top_edge_chars.append(player_party[-1])
	if len(enemy_party) > 0 and targetable_party.has(enemy_party[0]):
		bottom_edge_chars.append(enemy_party[0])
		top_edge_chars.append(enemy_party[-1])
	
	# if only party member: target all
	if len(party) == 1:
		#return _finish_targetables(targetable_party)
		return targetable_party
	
	# if far range: target all
	if !close_range:
		#return _finish_targetables(targetable_party)
		return targetable_party
	
	# edge character checks
	var bottom_edge = character == party[0]
	var top_edge = !bottom_edge and character == party[-1]
	
	# pos limits
	var lower_range = character.pos - (atk_range/2.0 + 0.1)
	var upper_range = character.pos + (atk_range/2.0 + 0.1)
	
	var results = Array()
	
	# get targetables
	for target in targetable_party:
		# bottom edge: many acrosses
		if (bottom_edge and target.pos < lower_range):
			results.append(target)
			
		# in range
		elif (target.pos >= lower_range 
		and target.pos <= upper_range):
			results.append(target)
			
		# top edge
		elif (top_edge and target.pos > upper_range):
			results.append(target)
	
	# if there are no targets: we must be on the bigger team and near edge.
	# Target edge. Like here, X can only target T:
	# O   X   O   O   O   O   O   O   O
	#             T   O   O
	# botom edge
	if len(results) == 0 and len(bottom_edge_chars) > 0:
		if character.pos < bottom_edge_chars[0].pos:
			results.append(bottom_edge_chars[0])
		elif len(bottom_edge_chars) >= 2 and (
			character.pos < bottom_edge_chars[1].pos):
				results.append(bottom_edge_chars[1])
	# top edge
	if len(results) == 0 and len(top_edge_chars) > 0:
		if character.pos > top_edge_chars[0].pos:
			results.append(top_edge_chars[0])
		elif len(top_edge_chars) >= 2 and (
			character.pos > top_edge_chars[1].pos):
				results.append(top_edge_chars[1])
	
	#return _finish_targetables(results)
	return results

# This is for when we start targeting POSITIONS instead of CHARACTERS.
#func _finish_targetables(characters):
#	var positions := []
#	for chara in characters:
#		positions.append(chara.pos)
#	return positions


var dead_charas := []
func freeze_dead_characters():
	for c in dead_charas:
		c.visible = false

func destroy_dead_characters():
	for i in range(len(dead_charas) - 1, -1 ,-1):
		dead_charas[i].queue_free()
	dead_charas.clear()

var destroys_on_turn_end := []
func destroy_on_turn_end(object: Object):
	destroys_on_turn_end.append(object)

# if ANY player's party member is ACTING, we cannot FLEE
func player_can_flee_due_to_acting():
	for chara in Overworld.player_room.get_spawned_friends():
		if (chara.selected_action != null
		and chara.selected_action.name != "Defend"
		and chara.selected_action.name != "Flee"):
			return false
	return true

# if ANY player's party member is FLEEING, we cannot ACT
func player_can_act_due_to_fleeing():
	for chara in Overworld.player_room.get_spawned_friends():
		if (chara.selected_action != null
		and chara.selected_action.flee):
			return false
	return true

func player_out_of_combat() -> bool:
	return len(Overworld.player_room.gse()) == 0

# Gives the percent of exp the player has this level toward the next.
# Used in EXP bars.
func exp_fraction_to_lvl() -> float:
	var lower = (exp_to_lvl[player_lvl - 2] if player_lvl > 1 else 0)
	return inverse_lerp(lower, exp_to_lvl[player_lvl - 1], player_exp)

func give_exp_to_player(xp: int):
	player_exp += xp
	print("TM: %d EXP gained! (Total: %d EXP)" % [xp, player_exp])
	if can_lvl_up():
		print("TM: Level up! Will take effect when out-of-combat.")

func can_lvl_up() -> bool:
	return false

func player_level_up(force = false):
	while can_lvl_up() or force:
		force = false
		print("TM: LVL UP: %d to %d!" % [player_lvl, player_lvl + 1])
		player_lvl += 1
		for chara in TurnPlayer.party:
			chara.set_level(player_lvl)

func game_lost() -> bool:
	return len(TurnPlayer.party) == 0


func get_class_name(): return "TurnManager"


#
#
#
#func _____RPG_MANIA_III_____():
#	pass
#
#
## groups of character placeholders. PackedScenes.
#export (Array, String, FILE) var tourney_teams_files := []
#var tourney_teams := []
#var tourney_matches := []
#var current_match = 0
#var seed_furthest_match := []
#var seed_lost := [false, false, false, false, false, false, 
#false, false, false, false, false, false, false, false, false, false]
#var seeds := []
#
#var tourney_seeds := 16
#
#func sort_team_danger_descending(a, b):
#	if a.danger_level > b.danger_level:
#		return true
#	elif a.danger_level < b.danger_level:
#		return false
#	else:
#		return a.name < b.name
#
##func rand_t(d, lvl):
##	if len(d[lvl]) == 0:
##		return rand_t(d, (lvl - 1) % 4)
##	var i = randi() % len(d[lvl])
##	var t = d[lvl][i]
##	d[lvl].remove(i)
##	return t
#
## Sets up tourney_matches.
#func generate_tournament():
#	# TOURNEY SEEDS:
#	#	41	21	21	31	41	31	21	21
#	var shuffled_teams = tourney_teams.duplicate()
#	shuffled_teams.shuffle()
#	# danger
#	var d := [[],[],[],[]]
#	var pt
#	for t in shuffled_teams:
#		if t.player:
#			pt = t
#			continue
#		d[t.danger_level - 1].append(t)
##
##	for i in range(0, tourney_seeds, 2):
##		tourney_matches.append([shuffled_teams[i], shuffled_teams[i+1]])
##
#	# player division
#	var tm = [[],[],[]]
#	tm[0].append([pt, rand_t(d, 0)]) # PLAYER vs 1
#	tm[0].append([rand_t(d, 1), rand_t(d, 0)]) # 2 vs 1
#	tm[1].append([rand_t(d, 1 + randi() % 2), rand_t(d, randi() % 2)]) # 2/3 vs 2/1
#	tm[1].append([rand_t(d, 2), rand_t(d, randi() % 2)]) # 3 vs 2/1
#
#	# final boss division
#	tm[2].append([rand_t(d, 1), rand_t(d, 0)]) # 2 vs 1
#	tm[2].append([rand_t(d, 3), rand_t(d, randi() % 4)]) # 4 vs 3/2/1
#	tm[2].append([rand_t(d, 2), rand_t(d, randi() % 3)]) # 3 vs 2/1
#	tm[2].append([rand_t(d, 2), rand_t(d, randi() % 3)]) # 3/2/1 vs 2/1
#
#	# jumble them up
#	for m in tm[0] + tm[1] + tm[2]:
#		m.shuffle()
#	tm[0].shuffle()
#	tm[1].shuffle()
#	tm[2].shuffle()
#	tourney_matches.append_array(tm[0] + tm[1] + tm[2])
#
#	print("TOURNEY GENERATED:")
#	for i in range(len(tourney_matches)):
#		print("MATCH %d: %s (Lv. %s) vs. %s (Lv. %s)" % [i+1, 
#		tourney_matches[i][0].name, tourney_matches[i][0].danger_level,
#		tourney_matches[i][1].name, tourney_matches[i][1].danger_level])
#		seed_furthest_match.append_array([0,0])
#		seeds.append_array(tourney_matches[i])
#
#	for t in shuffled_teams:
#		get_tree().root.call_deferred("add_child", t)
#
#func start_tourney_round():
#	# get player's opponent and player to next room
#	for m in tourney_matches:
#		if m[0].player or m[1].player:
#			var eteam = m[0] if !m[0].player else m[1]
#			# find some random cell to put em in
#			for c in get_tree().get_nodes_in_group("cell"):
#				if len(c.get_inhabitants()) == 0:
#					for e in eteam.charas:
#						eteam.remove_child(e)
#						c.add_child(e)
#						c.chara_placeholders.append(e)
#					TurnPlayer.set_destination_room(c)
#					end_current_turn()
#					break
#					break
#	print("TOURNEY NEXT ROUND:")
#	for i in range(len(tourney_matches)):
#		print("MATCH %d: %s vs. %s" % [i+1, tourney_matches[i][0].name,
#		tourney_matches[i][1].name])
#
#
#func get_round_winner(team1, team2) -> Node:
#	var winner
#	var loser
#	# team2 won
#	if team2.danger_level > team1.danger_level or (
#	team2.danger_level == team1.danger_level and randf() > 0.5):
#		winner = team2
#		loser = team1
#	else:
#		winner = team1
#		loser = team2
#
#	# give winner a member of loser
#	if !winner.player:
#		var cph = loser.get_child(randi() % loser.get_child_count()).duplicate()
#		#loser.remove_child(cph)
#		winner.add_child(cph)
#		cph.min_charas = 1
#		cph.max_charas = 1
#	var cph = loser.get_child(randi() % loser.get_child_count()).duplicate()
#	#loser.remove_child(cph)
#	winner.add_child(cph)
#	cph.min_charas = 1
#	cph.max_charas = 1
#	seed_furthest_match[seeds.find(loser)] = current_match
#	seed_furthest_match[seeds.find(winner)] = current_match + 1
#	seed_lost[seeds.find(winner)] = false
#	seed_lost[seeds.find(loser)] = true
#	return winner
#
#func end_tourney_round():
#	var new_matches = []
#	for i in range(0, len(tourney_matches), 2):
#		new_matches.append(
#		[get_round_winner(tourney_matches[i][0], tourney_matches[i][1]),
#		get_round_winner(tourney_matches[i+1][0], tourney_matches[i+1][1])])
#	tourney_matches = new_matches
#	current_match += 1
#
#	BracketUI.end_of_round_movement()
