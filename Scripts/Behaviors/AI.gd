#tool
extends Node

@export var priorities := {"Buff": 1,"Damage": 3,
"Debuff": 2,"Heal": 0,"Lethal": 5,"Rescue": 4}
@export var skip_prio_chance := 0.1
@export var max_comrades_per_prio := {"Buff": 1,"Damage": 1,
"Debuff": 3,"Heal": 2,"Lethal": 2,"Rescue": 2}

var chosen_cat_act_targ := []

@onready var chara = get_parent()

# Returns an array of an action and an array of targets to attack.
func get_AI_action_and_target() -> Array:
	# Go down the list of priorities and choose one.
	chosen_cat_act_targ = []
	for prio in sorted_prios().keys():
		var results := []
		match Action.CATEGORY[prio]:
			Action.CATEGORY.Lethal:
				results = lethal_check(true)
			Action.CATEGORY.Rescue:
				results = rescue_check(true)
			Action.CATEGORY.Heal:
				results = heal_check(true, false)
			Action.CATEGORY.Damage:
				results = damage_check(false, false)
			Action.CATEGORY.Debuff:
				results = debuff_check(false, false)
			Action.CATEGORY.Buff:
				results = buff_check(false, false)
			
		# we have things to do at this priority
		if len(results) > 0:
			results = [results[randi() % len(results)]]
			chosen_cat_act_targ = [prio] + results[0]
			if randf() > skip_prio_chance: break
	# we found nothing to do
	if len(chosen_cat_act_targ) == 0:
		chara.cell.print_in_room("%s found nothing to do." 
		% chara._get_name())
		return []
	
	chara.cell.print_in_room("AI: %s is using %s (Category: %s) on %s." % [
	chara._get_name(), 
	chosen_cat_act_targ[1]._get_name(), 
	chosen_cat_act_targ[0],
	chosen_cat_act_targ[2]._get_name()])
	return [chosen_cat_act_targ[1], chosen_cat_act_targ[2]]

# Check for priority possibilities

# Returns the best action/target pair if it can kill an enemy, 
# [] if none can. Or, can return a full list of all lethals.
# This only returns Lethal-type skills if there are any.
# If there's no Lethal-types, it will return any type (usually Damage.)
func lethal_check(only_best = true) -> Array:
	var result = []
	var bestoverkill := -1
	# check each move
	for action in chara.all_equipped_actions:
		if !action._update_usability(false):
			continue
		# prioritize finishers
		if (len(result) > 0 
		and result[0][0].skill_category == Action.CATEGORY.Lethal 
		and action.skill_category != Action.CATEGORY.Lethal):
			continue
		var initials = action.possible_initial_targets()
		# choose the best initial target that will kill the most ppl
		for initial in initials:
			var acts_bestoverkill = -1
			var autos = action._auto_targets([initial])
			var aoes = action.get_aoe_targets([initial] + autos, false)
			for targ in [initial] + autos + aoes:
				if (targ.get_class_name() != "TurnCharacter" or
				targ.on_players_team == chara.on_players_team): continue
				var dmg = action.calc_dmg(targ)
				if dmg >= targ.hp:
					acts_bestoverkill = max(0, 
					acts_bestoverkill + dmg - targ.hp)
			
			if only_best and acts_bestoverkill > bestoverkill:
				bestoverkill = acts_bestoverkill
				result = [[action, initial]]
			elif !only_best and acts_bestoverkill >= 0:
				if (action.skill_category == Action.CATEGORY.Lethal
				and (len(result) == 0 
				or result[0][0].skill_category != Action.CATEGORY.Lethal)):
					# delete everything if we found our first lethal
					result = [[action, initial]]
				else:
					# add it to list
					result.append([action, initial])
	
	
	return result

# Returns the Damage-type skill that does the most damage to
# the most enemies, and will prioritize those that kill.
func damage_check(only_best = true, only_lethal = false) -> Array:
	var result = []
	var best_dmg := -1
	var best_lethal := false
	# check each move
	for action in chara.all_equipped_actions:
		if !action._update_usability(false):
			continue
		if action.skill_category == Action.CATEGORY.Heal:
			continue
		var initials = action.possible_initial_targets()
		# choose the best initial target that will kill the most ppl
		for initial in initials:
			var ini_dmg = 0
			var lethal = false
			var autos = action._auto_targets([initial])
			var aoes = action.get_aoe_targets([initial] + autos, false)
			for targ in [initial] + autos + aoes:
				if (targ.get_class_name() != "TurnCharacter" or
				targ.on_players_team == chara.on_players_team): continue
				var dmg = action.calc_dmg(targ)
				ini_dmg += min(dmg, targ.hp)
				if dmg >= targ.hp:
					lethal = true
			
			if !only_lethal or lethal:
				if only_best and ini_dmg > best_dmg and (
				lethal or !best_lethal):
					best_lethal = lethal
					best_dmg = ini_dmg
					result = [[action, initial]]
				elif !only_best and ini_dmg > 0:
					result.append([action, initial])
	
	return result


# Returns the best (or all) action/target pair that will
# save a friend's life, or [] if none can.
# Includes Rescue-type moves, and damaging moves that
# will kill before the killer can act.
func rescue_check(only_best = true) -> Array:
	var results := []
	var lethals := get_opposing_lethals()
	# Rescue-types
	for act in chara.all_equipped_actions:
		if !act._update_usability(false):
			continue
		if act.skill_category == Action.CATEGORY.Rescue:
			for lethal in lethals:
				if lethal[1] in act.possible_initial_targets():
					results.append([act, lethal[1]])
	# if we have any rescues, do those instead of heals
	if len(results) > 0:
		if only_best: return [results[randi() % len(results)]]
		else: return results
	# No rescues - try to kill a killer instead
	var kills = damage_check(false, true)
	for act in chara.all_equipped_actions:
		if !act._update_usability(false):
			continue
		if (act.skill_category == Action.CATEGORY.Damage
		or act.skill_category == Action.CATEGORY.Lethal):
			for lethal in lethals:
				# we're faster and can kill
				if (((act.priority == lethal[0].priority
				and chara.speed >= lethal[0].character.speed)
				or act.priority > lethal[0].priority)
				and lethal[0].character in kills):
					results.append([act, lethal[0].character])
					if only_best: return results
	# STILL no rescues - just do a Rescue-type
	for act in chara.all_equipped_actions:
		if !act._update_usability(false):
			continue
		if act.skill_category == Action.CATEGORY.Rescue:
			for c in act.possible_initial_targets():
				results.append([act, c])
	return results

# Returns the best (or all) action/target pairs where the action
# is a heal and the target is a friend that's missing HP.
# Will only return heals that will save a friend's life
# if only_lethal is true and there are any times where
# healing would indeed save a life.
func heal_check(only_best = true, only_lethal = true) -> Array:
	var results := []
	# ONLY LETHALS
	if only_lethal:
		for act in chara.all_equipped_actions:
			if !act._update_usability(false):
				continue
			if act.skill_category == Action.CATEGORY.Heal:
				for lethal in get_opposing_lethals():
					if (lethal[1] in act.possible_initial_targets() 
					and lethal[1].get_class_name() == "TurnCharacter" 
					and lethal[1].on_players_team == chara.on_players_team
					and abs(act.power * act.atk_multiplier)
					> lethal[0].calc_dmg(lethal[1]) - lethal[1].hp):
						results.append([act, lethal[1]])
		if len(results) > 0 and only_best: 
			return [results[randi() % len(results)]]
		elif len(results) > 0:
			return results
	
	# return the heals that wouldn't save any lives
	var most_heal = -1
	for act in chara.all_equipped_actions:
		if !act._update_usability(false):
			continue
		if act.skill_category == Action.CATEGORY.Heal:
			for c in act.possible_initial_targets():
				if (c.get_class_name() == "TurnCharacter" 
				and c.on_players_team == chara.on_players_team
				and c.hp < c.max_hp 
				and (!only_best 
				or min(c.hp - act.power * act.atk_multiplier, 
				c.max_hp) - c.hp > most_heal)):
					most_heal = min(c.hp - act.power 
					* act.atk_multiplier, c.max_hp) - c.hp
					results.append([act, c])
	return results

# Returns all action/target pairs where the action
# is a debuff and the target is an enemy.
# Will only target would-be killers if only_lethal is true
# and there are any enemies that could kill this turn. Otherwise,
# it simply returns all debuffs that can occur.
func debuff_check(only_one = false, only_lethal = false) -> Array:
	var results := []
	# ONLY LETHALS
	if only_lethal:
		for act in chara.all_equipped_actions:
			if !act._update_usability(false):
				continue
			if act.skill_category == Action.CATEGORY.Debuff:
				for lethal in get_opposing_lethals():
					if (lethal[1].get_class_name() == "TurnCharacter" 
					and lethal[1].on_players_team == chara.on_players_team
					and lethal[0].character in act.possible_initial_targets()
					):
						results.append([act, lethal[0].character])
	
	# find nonlethals
	if len(results) == 0:
		for act in chara.all_equipped_actions:
			if !act._update_usability(false):
				continue
			if act.skill_category == Action.CATEGORY.Debuff:
				for c in act.possible_initial_targets():
					if ((c.get_class_name() == "TurnCharacter" 
					and c.on_players_team != chara.on_players_team)
					or (c.get_class_name() == "StatusEffect"
					and !c.is_buff)):
						results.append([act, c])
	return results if (!only_one or len(results) < 2
	) else [results[randi() % len(results)]]

# Returns all action/target pairs where the action
# is a buff and the target is an friend.
# Will only target would-be deaths if only_lethal is true
# and there are any friends that could die this turn. Otherwise,
# it simply returns all buffs that can occur.
func buff_check(only_one = false, only_lethal = false) -> Array:
	var results := []
	# ONLY LETHALS
	if only_lethal:
		for act in chara.all_equipped_actions:
			if !act._update_usability(false):
				continue
			if act.skill_category == Action.CATEGORY.Buff:
				for lethal in get_opposing_lethals():
					if (lethal[1] in act.possible_initial_targets() 
					and lethal[1].get_class_name() == "TurnCharacter" 
					and lethal[1].on_players_team == chara.on_players_team):
						results.append([act, lethal[1]])
	
	# find nonlethals
	if len(results) == 0:
		for act in chara.all_equipped_actions:
			if !act._update_usability(false):
				continue
			if act.skill_category == Action.CATEGORY.Buff:
				for c in act.possible_initial_targets():
					if ((c.get_class_name() == "TurnCharacter" 
					and c.on_players_team == chara.on_players_team)
					or (c.get_class_name() == "StatusEffect"
					and c.is_buff)):
						results.append([act, c])
	return results if (!only_one or len(results) < 2
	) else [results[randi() % len(results)]]


# Prediction

# Returns all action/target pairs that will kill friends.
func get_opposing_lethals() -> Array:
	return chara.cell.get_lethals(chara.on_players_team)




func sorted_prios():
	# Sort it!!!!
	var newprio := Dictionary()
	var too_many_comrades_prios := []
	# counting down to get the highest-value priority first
	var i = 0
	for j in range(priorities.size() - 1, -1, -1):
		var key = priorities.keys()[priorities.values().find(j)]
		if too_many_comrades_on_prio_check(key):
			too_many_comrades_prios.append(key)
		else:
			newprio[key] = i
			i += 1
	# do too many comrades list at the end, in case 
	# the character can't find anything to do with the non-
	# filled prios
	for prio in too_many_comrades_prios:
		newprio[prio] = i
		i += 1
	return newprio

# Returns true if there are already a maximum or more friends doing
# a certain priority, false if it's okay to do this prio.
# Having a 0 in max_comrades_per_prio means there is no limit.
func too_many_comrades_on_prio_check(prio) -> bool:
	if max_comrades_per_prio[prio] <= 0: return false
	
	var spots_left = max_comrades_per_prio[prio]
	for c in chara.get_party():
		if c == chara: 
			continue
		if len(c.ai.chosen_cat_act_targ
		) == 3 and c.ai.chosen_cat_act_targ[0] == prio:
			spots_left -= 1
			if spots_left <= 0:
				return true
	return false


func _________EDITOR____________() -> void:

#var changed_entry := {0:0}
#var reordering_priority = false
#var going_up = false
#func update_prio(val : Dictionary):
#	if reordering_priority: return
#	reordering_priority = true
#	for i in range(Action.CATEGORY.size()):
#		if len(priorities) <= i:
#			priorities[Action.CATEGORY.keys()[i]] = val[val.keys()[i]] if (
#			i < val.size()) else i
#	# find what changed
#	for i in range(val.size()):
#		if val.values()[i] != priorities.values()[i]:
#			changed_entry = {val.keys()[i]: clamp(val.values()[i], 0,
#			Action.CATEGORY.size() - 1)}
#			going_up = val.values()[i] > priorities.values()[i]
#			break
#
#	# now change it
#	if changed_entry != {0:0}:
#		take_priority(changed_entry.keys()[0], changed_entry.values()[0])
#		changed_entry = {0:0}
#	# bring lowest to 0
#	var low = priorities.values().min()
#	for k in priorities.keys():
#		priorities[k] -= low
#	# now bring down all priorities
#	for i in range(priorities.size()):
#		if !(i in priorities.values()):
#			# find lowest but above i, and bring it down to i
#			var lowest = -1
#			var lowkey = ""
#			for key in priorities.keys():
#				if priorities[key] > i and (priorities[key] < lowest
#				or lowest == -1):
#					lowest = priorities[key]
#					lowkey = key
#			priorities[lowkey] = i
#

# The key takes the given value and bumps any that
# are already in that spot up by one.
#func take_priority(key, value):
#	if key is int: return
#	priorities[key] = value
#	for k in priorities.keys():
#		if k != key and priorities[k] == value and k != changed_entry.keys()[0]:
#			take_priority(k, value + (1 if value >= (changed_entry.values()[0]
#			+ 0.01 * int(going_up))
#			 else -1))


#var _editor_run = 0
#func _editor_changed():
#	if !Engine.editor_hint || !is_inside_tree():
#		return
#	_editor_run += 1
#	var _run = _editor_run
#	yield(get_tree().create_timer(0.25), "timeout")
#	if _run == _editor_run:
#		property_list_changed_notify()
#		_editor_run = 0

	pass
