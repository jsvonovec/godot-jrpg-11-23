@icon("res://Sprites/action.png")
extends Node

class_name Action
#signal apply_action

@export var rname := ""
# True: Primary action. False: Secondary action.
@export var primary = true
# The holder of this action.
var character
# Close: can only target 2-3 across or 2 adjacent characters.
# Far: Can target anyone.
@export var close_range = true
@export var target_self = false
# If true, will always target self. This assumes the target doesn't matter.
@export var skip_targeting = false
# Category is used for AI to determine what to do.
enum CATEGORY {Lethal, Rescue, Debuff, Damage, Buff, Heal}
@export var skill_category = CATEGORY.Damage
# Cooldown. Ticks down on turn end. Unusable while on cooldown.
@export var cooldown = 0
var cd_left := 0
# Radius of the action, for AOE purposes. 0 or less means single target.
#export(int) var radius = 0
# resource costs - index relates to that index resource
@export var costs: Array[float]
@export var refund_cost_on_miss = [false, false, false, false]
@export var target_friendlies: bool = true
@export var target_enemies: bool = true
# True: if also ranged, will target the original target (if not hard_to_hit).
# False: will always target the POSITION, not the character.
@export var follow: bool = false

# whether this action is usable in combat right now. If not, it's greyed out
@export var usable = true
# whether the action is available in the UI or to AIs. If not, it's like
# it doesn't exist... unless select_action ignores usability.
@export var visible = true
# True: friends appear at the top of the targets list.
@export var beneficial = false
# True: Action is performed before the actual action processing,
# and before characters are moved. Think pursuit from pokemon, or
# a priority roar.
@export var before_room_movement = false

# enum, in case we want more than 2 attack types
enum ATTACK_TYPE {PHYSICAL, MAGICAL, CHEMICAL, SPIRITUAL}
@export var attack_type: ATTACK_TYPE
@export var power: int = 0
@export var accuracy = 100
@export var can_miss = true
@export var priority = 0
@export var icon := load("res://Sprites/action.png")
@export_multiline var description
@export var atk_multiplier = 1.0
@export var def_multiplier = 1.0
# Deternimes whether the user steps to the target or just a little forward
# Also the range. Melee can only target adjacent characters.
@export var melee = false 
# If true, will attempt a flee if on the player's team.
@export var flee = false

## Area of Effect
@export var aoe = 0.0 # Range of extra positions to hit
@export var aoe_other_team = false # enemies in range also get hit
# Reduction in range when hitting the other team than targetted
@export var aoe_other_team_range_change = -1.0
@export var sfx_default: SoundOpScript.SOUND_TYPE

## Multitarget
# Number of targets we can target. Minimum: 0? For global effects?
@export var max_targets = 1
# True: we can multitarget the same character multiple times.
@export var allow_same_target = true
# True: we can multitarget the same person consecutively.
# Non-applicable if we can't target the same person twice anyway.
@export var allow_same_target_consec = true
# The range from the MOST RECENT TARGET that the NEXT TARGET may be.
# If <0, this is ignored.
@export var multi_target_consec_max_range = -1
# The range from the FIRST TARGET that ANY TARGET may be.
# If <0, this is ignored.
@export var multi_target_initial_max_range = -1
# The range from the MOST RECENT TARGET that the NEXT TARGET must be.
# If <0, this is ignored. minrange = min(minrange, maxrange).
@export var multi_target_consec_min_range = -1
@export var require_max_targets = false
# If true, the character selects only the initial target, then the rest
# are automatically selected. 
@export var multi_autotarget = false
# If true, targets will be automatically found in bulk - which means
# they'll all be picked at the same time. Not good for if the last
# targeted character matters, like if consec max range is nonzero.
@export var multi_auto_bulk = true
# If true, non-initial multiattacks can take place
# outisde of the usual attack range. If false, it all has to 
# be within atk range.
@export var multi_ignores_atk_range = false
# If true, non-initial multiattacks may only be made to the
# party that the initial attack is made against.
@export var multi_one_team = false

const burning_icon := preload("res://Sprites/Emoji/twe_fire.png")
var burning_se := load(
	"res://Scripts/Behaviors/StatusEffects/se_Burning.gd")
var poisoned_se := load(
	"res://Scripts/Behaviors/StatusEffects/se_Poisoned.gd")
var poisoned_badly_se := load(
	"res://Scripts/Behaviors/StatusEffects/se_Poisoned_Badly.gd")
var poisoned_lethally_se := load(
	"res://Scripts/Behaviors/StatusEffects/se_Poisoned_Lethally.gd")

var part_anim : CombatPartAnim = null
var anim : Anim = null

func _ready():
	if !is_in_group("actions"):
		add_to_group("actions")
	# get our character
	for tc in get_tree().get_nodes_in_group("turn_characters"):
		if tc.is_ancestor_of(self):
			character = tc
			break
	
	# fix costs array
	for _i in range(len(CombatUI.RESOURCE_NAMES) - len(costs)):
		costs.append(0.0)
	
	# get anim if applicable
	for child in get_children():
		if NIU.get_class_name(child) == "CombatPartAnim":
			part_anim = child
			break
	
	# connect on turn end
	if NIU.iiv(character) and NIU.iiv(character.cell):
		character.cell.connect("turn_ended", Callable(self, "on_turn_end"))
	else:
		TurnManager.connect("turn_ended", Callable(self, "on_turn_end"))

func on_turn_end():
	cd_left -= 1

static func calculate_damage(attacker, target, type, p, amult, _dmult) -> int:
	if is_instance_valid(target) and target.invulnerable:
		return 0
	var atk := 100
	#var def := 50
	
	if is_instance_valid(attacker): #and attacker.on_players_team:
		atk = attacker.atk[type]
	#if is_instance_valid(target): def = target.def[type]
	var vulnerability := 1.0 if !is_instance_valid(
	target) else (1.0 + float(target.vulnerable)
	) * (1.0 - float(target.protected) / 2.0)
	atk *= amult
	#def *= dmult
	#def = int(max(1, def))
	
	# final calculation
	var result : int = int(round(p * float(atk) / 100.0))
#	var before_redux : int = int(ceil((atk*amult/100.0) 
#	* p 
#	* min(1.0, 1.0 - (def*dmult/100.0))))

	# end now if it's healing
	if result < 0:
		return result
	
	var dr = target.damage_reduction if target != null else 0
	result = int(max(0, result - dr))
	# double dmg if vulnerable, half if protected
	result = int(float(result * vulnerability))
	return result

func calc_dmg(target = null):
	if target == null:
		target = CombatUI.targ_highlighted
	return Action.calculate_damage(character, target, 
	attack_type, power, atk_multiplier, def_multiplier)

func preview_dmg(target = null) -> String:
	if target == null:
		target = CombatUI.targ_highlighted
		#if target == null:
			#return "(???)"
	return str(calc_dmg(target))

# power, _source, a_type = 0, a_mult = 1, d_mult = 1
func deal_basic_damage(target) -> int:
	var killed = target.dead
	var dmg = target.take_damage(power, character, 
	attack_type, atk_multiplier, def_multiplier, true)
	if killed != target.dead:
		killed = true
		# ANIM: Store kill
		#anim.add_effect_kill(target.pup)
	#else:
		# ANIM: Store damage
		#anim.add_effect_hp(target.pup, target.hp, 
		#character.selected_targets.find(target))
	return dmg

# find aoe targets and returns it in an array of arrays,
# each arrray corresponding to that target
func get_aoe_targets(_targets, grouped = true) -> Array:
	var aoes = []
	if aoe > 0:
		for targ in _targets:
			var targs = TurnManager.targets_in_range(targ, true, 
			false, false, true, aoe)
			if grouped: aoes.append(targs)
			else: aoes.append_array(targs)
			if aoe_other_team and aoe + aoe_other_team_range_change > 0:
				targs = TurnManager.targets_in_range(targ, true, false, 
				true, false, aoe + aoe_other_team_range_change)
				if grouped: aoes.append(targs)
				else: aoes.append_array(targs)
	return aoes

func use(_targets):
	TurnManager.action_being_used_right_now = true
	TurnManager.__last_action = self
	
	# use resources
	for i in range(len(CombatUI.RESOURCE_NAMES)):
		#character.resource[i] -= costs[i]
		character.set_resource(i, character.resource[i] - costs[i]) 
	
	gameplay_use(_targets)
	
	TurnManager.action_being_used_right_now = false

func gameplay_use(_targets):
	var __targets = _targets.duplicate()
	# dodge check
	if can_miss:
		already_missed = false
		for i in range(len(__targets) - 1, -1, -1):
			if !is_instance_valid(__targets[i].get_chara()) or (beneficial 
			and __targets[i].on_players_team == character.on_players_team):
				continue
			var hitcheck = Action.hit_check(accuracy, __targets[i].get_chara().evasion)
			if !hitcheck[0]:
				# We missed!
				# accuracy hit; eva was the problem
				if hitcheck[1]:
					character.cell.print_in_room("The target, %s, dodged! (%d)"
					% [__targets[i]._get_name(), __targets[i].evasion])
				else:
					character.cell.print_in_room("The attack, %s, missed! (%d)"
					% [name, accuracy])
				on_miss(__targets[i])
				__targets.remove_at(i)
	# if we require max targets, then cancel the move
	if require_max_targets and len(__targets) != max_targets:
		__targets = []
	## create animation
	# add the anim
	anim = CombatPuppeteer.add_animation_existing(character.pup, 
	null, part_anim, 1.0)
	anim.set_group_to_find_middle_of(__targets)
	anim.action = self
	# add use resource effects
	for i in range(len(costs)):
		if costs[i] != 0:
			anim.add_effect_res(character.pup, i, character.resource[i], 
			true)
	_use(__targets)
	# update the status effect to NOW, if a target is a status effect
	for t in __targets:
		if t.get_class_name() == "StatusEffect":
			t.queue_anim_update_card_icon()
	cd_left = cooldown

func apply_burn(target, stacks: int, duration := 3) -> void:
	burning_se.new(character, target,
	burning_icon, duration, stacks)

func apply_poison(target, duration : int, level := 0) -> void:
	# create new
	match level:
		0:
			poisoned_se.new(character, target, duration)
		1:
			poisoned_badly_se.new(character, target, duration)
		2:
			poisoned_lethally_se.new(character, target, duration)

# Returns an array; item 0 is the RESULT, item 1 is IF ACC HIT
static func hit_check(acc, eva) -> Array:
	var roll = randi() % 100	 # 0 to 99
	# hits on roll=0 acc = 1, miss on roll=0 acc = 0
	var hitacc = roll < acc
	roll = randi() % 100	 # 0 to 99
	var hiteva = roll < 100 - eva
	return [hitacc and hiteva, hitacc]

var already_missed = false
func on_miss(_missed_target) -> void:
	# Things that can repeat
	
	# (nothing...)
	
	# Things that should only happen once per action use
	if !already_missed:
		# Refund if applicable
		for i in range(len(costs)):
			if (i <= len(refund_cost_on_miss) 
			and refund_cost_on_miss[i]):
				#character.resource[i] -= costs[i]
				character.set_resource(i, character.resource[i] + costs[i]) 
	
	_on_miss(_missed_target)
	
	already_missed = true

# Override. May happen multiple times during casting, if it's
# a multitarget or aoe or something.
# If you want it to only happen once per casting,
# check for already_missed.
func _on_miss(_missed_target) -> void:
	pass

# What happens when this action is used during the turn.
# Apparently this is already a virtual function; just define
# use() in a derived class and it will use that one.
func _use(_targets):
	pass

# overridable. Called when usability is in question (like the UI.)
# Should NOT change in the middle of a unit's action selection phase,
# for the player OR AI.
func _update_usability(ignore_equipped := false) -> bool:
	usable = len(possible_initial_targets()) > 0 and cd_left <= 0
	usable = usable and (visible and (character.primary_actions.has(self)
	or character.secondary_actions.has(self)) or ignore_equipped
	) and character.has_resources_for_action(self)
	return usable

# list of possible targets to start targeting.
# May be overridden. When overriding, please still use targets_in_range()!
# Then trim or add as needed!
func possible_initial_targets() -> Array:
	return TurnManager.targets_in_range(
	character, close_range, target_self, target_enemies, target_friendlies)


# The thing to show in the status text. Can be overridden.
func use_message():
	var text := ""
	text += name
	if len(character.pup.targets) > 0:
		text += " -> "
		var targnames = character.pup.targets[0]._get_name()
		for i in range(1, len(character.pup.targets)):
			targnames += ", " + character.pup.targets[i]._get_name()
		text += targnames
	return text

# Gives the formatted description with "{damage}" or "{stacks}" or something.
# Can also give values from the target
# or character using "character." or "target." before a parameter.
# This can also be found in near-identical form in NIU.
func get_desc(targ_highlighted = null) -> String:
	var actdesc: String = description
	var newdesc := actdesc
	var i := 0
	var j := -1
	var origval : String
	var val : String
	var substitution : String
	var subject : Node = null
	for c in actdesc:
		if c == '{'[0]:
			j = actdesc.findn('}', i)
			if j > 0:
				origval = ""
				val = ""
				substitution = ""
				# grab whatever's between { and }
				origval = actdesc.right(-(i+1)).left(j-i-1)
				# DOT DETECTED: character
				if origval.findn("character.") != -1:
					val = origval.right(origval.findn("character.") + 10)
					subject = character
				# DOT DETECTED: Target
				elif origval.findn("target.") != -1:
					val = origval.right(origval.findn("target.") + 7)
					# We are highlighting a target button
					if targ_highlighted != null:
						subject = targ_highlighted
					# We are NOT highlighting a target button
					else:
						substitution = "[i](Target's %s)[/i]" % val
				# if no DOTS: just do it normal
				else:
					val = origval
					subject = self
				# Now determine if it's a parameter or a fxn we need.
				# SUBSTITUTE ACTUALLY
				if substitution != "":
					newdesc = newdesc.format(
							[[origval, substitution]])
				# PARAMETER
				if val.findn("()") == -1:
					newdesc = newdesc.format(
						[[origval, str(subject.get(val))]])
				# VOID METHOD
				else:
					j = val.findn("(")
					newdesc = newdesc.format(
						[[origval, str(subject.call(val.left(j)))]])
		i += 1
	return newdesc

func sort_targets_by_benefitting_party(a,b):
	var ca = a.get_chara()
	var cb = b.get_chara()
	var va = is_instance_valid(ca)
	var vb = is_instance_valid(cb)
	if (!va and !vb) or (va and vb and 
	ca.on_players_team == cb.on_players_team): 
		return TurnManager.sort_position_ascending(a,b)
	if !va or (beneficial and ca.on_players_team) or (
		!beneficial and !ca.on_players_team):
		return true
	return false

# overridable. Array is the sfx to play per target.
func get_sfx() -> Array:
	var results = []
	while len(results) < max(len(character.selected_targets), 1):
		results.append(sfx_default)
	return results

#func get_anim(target, speed := 1.0) -> Anim:
#	if !is_instance_valid(anim) or anim.finished:
#		anim = Anim.new()
#		if is_instance_valid(part_anim):
#			anim.setup_existing_anim(character.pup, target, speed, part_anim)
#		else:
#			anim.setup_anim(character.pup, target, speed, part_anim_path)
#	return anim


func _get_name():
	return name if rname == "" else rname

func get_cell():
	return character.cell

## MULTITARGET
func ________MULTITARGET________(): pass

# Returns an array of additional targets to consider.
# Use for status effect targets! Override it!
func _add_initials_to_follow() -> Array:
	return []

# returns list of possible targets to target next
func possible_following_targets(targets) -> Array:
	# Return none if we cannot target any more peeps
	if len(targets) >= max_targets:
		return []
	var results = []
	var initials = (character.cell.get_inhabitants() +
					_add_initials_to_follow())
	for initial in initials:
		# Only calculate whether we can target them from the LAST one we got
		if can_follow_target_with_this_target(targets, initial):
			results.append(initial)
	
	return results

# returns bool, whether or not the given character is targetable 
# given another, already-selected target
func can_follow_target_with_this_target(targets, candidate) -> bool:
	# Assume targets has at least 1 member. If it doesn't,
	# something broke. Let it error out.
	# Roughly in an order that would save CPU cycles, hopefully
	# same target stuff
	if targets.has(candidate) and !allow_same_target:
		return false
	if targets[-1] == candidate and !allow_same_target_consec:
		return false
	
	# Grab units
	var cand_unit = null
	if candidate.get_class_name() == "StatusEffect": 
		cand_unit = candidate.affected
	elif candidate.get_class_name() == ("TurnCharacter"): 
		cand_unit = candidate
	var t0_unit = null
	if targets[0].get_class_name() == ("StatusEffect"): 
		t0_unit = targets[0].affected
	elif targets[0].get_class_name() == ("TurnCharacter"): 
		t0_unit = targets[0]
	var last_unit = null
	if targets[-1].get_class_name() == ("StatusEffect"): 
		last_unit = targets[-1].affected
	elif targets[-1].get_class_name() == ("TurnCharacter"): 
		last_unit = targets[-1]
	
	# Same team
	if multi_one_team and NIU.iiv(cand_unit) and NIU.iiv(t0_unit
	) and cand_unit.on_players_team != t0_unit.on_players_team:
		return false
	# range
	if is_instance_valid(cand_unit) and is_instance_valid(last_unit):
		# consecutive
		var dist = abs(cand_unit.pos - last_unit.pos)
		if multi_target_consec_max_range >= 0 and (
		dist > multi_target_consec_max_range + 0.5 or
		dist < min(multi_target_consec_max_range, 
			multi_target_consec_min_range) - 0.5):
			return false
		# initial
		dist = abs(cand_unit.pos - t0_unit.pos)
		if multi_target_initial_max_range >= 0 and (
		dist > multi_target_initial_max_range + 0.5):
			return false
	# outside atk range and not ignored
	if !multi_ignores_atk_range and !possible_initial_targets().has(candidate):
		return false
	# custom
	if !_custom_multitarget_follow_rules(targets, candidate):
		return false
	
	# Got this far. We can follow that target with this one!
	return true

# To be overridden. Extra rules to follow when determining whether
# a target can be multitargetted after a given one.
func _custom_multitarget_follow_rules(_targets, _candidate) -> bool:
	return true

var avpos = 0.0
# Returns a list of characters to automatically target.
# May be overridden by deriving scripts.
# Some example may include: explosive AoE, random chain lightning, etc.
# Only needs to be run once to get all autotargets.
func _auto_targets(initial: Array) -> Array:
	# By default: select the x closest characters on that team.
	# If it's uneven, choose a random tiebreaker.
	# Will get ALL slots filled, or run out of possible targets.
	var spots_left = max_targets - len(initial)
	# Return none if there's no spots left anyway
	if spots_left <= 0:
		return []
	
	
	# get average pos
	avpos = 0.0
	for i in range(len(initial)):
		if initial[i].get_class_name() == "TurnCharacter":
			avpos += initial[i].pos
	avpos /= len(initial)
	
	var results = []
	var possibles: Array = []
	while(spots_left > 0):
		# Grab all possible targets
		possibles.clear()
		possibles += character.cell.get_inhabitants()
		for i in range(len(possibles)-1,-1,-1):
			if !can_follow_target_with_this_target(initial + results, 
			possibles[i]):
				possibles.remove_at(i)
		
		# If we cannot target anything, stop now
		if len(possibles) == 0:
			return results
		
		# Now, we have possible targets.
		# If we have enough cell in max_targets to hold all possibles,
		# then just make them the targets.
		if len(possibles) <= spots_left:
			results += possibles
			spots_left -= len(possibles)
			continue
		
		# Sort!
		_sort_bulk_multitarget_wellness(possibles)
		# possibles should now be in order of how much
		# we want to autotarget them.
		for c in possibles:
			# target them!
			results.append(c)
			spots_left -= 1
			if spots_left <= 0:
				break
		# If there are still spots left, we'll automatically target
		# things again. :)
	
	# When there are no longer any spots open, we have our results.
	return results

# To be overridden. Sorts possible targets in order from most
# desirable to be autotargeted to least. For bulk autotargeting.
func _sort_bulk_multitarget_wellness(possibles):
	# Now, find the closest target to the average initial pos,
	# then the next closest, and so on.
	sort_position = avpos + (0.1*randf() - 0.05)
	possibles.sort_custom(Callable(self, "sort_position_distance_to_point"))
	return possibles

var sort_position = 0.05
# Sorts the characters in ascending order of distance to sort_position.
func sort_position_distance_to_point(a,b):
	if(abs(a.pos-sort_position) < abs(b.pos-sort_position)):
		return true
	return false

# Returns true if the given array of targets can be multitargeted
# by this action, false if not.
func verify_multi_target(targets):
	if !possible_initial_targets().has(targets[0]):
		return false
	
	# now see that they're all viable
	var prev_targs = [targets[0]]
	for i in range(1, len(targets)):
		if !can_follow_target_with_this_target(prev_targs, targets[i]):
			return false
		prev_targs.append(targets[i])
	return true


