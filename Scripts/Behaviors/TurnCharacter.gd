@icon("res://Sprites/sword.png")
extends Node3D

class_name TurnCharacter
#signal killed # arg: self, so that if multiple killeds go to the same fxn
# we know who called it
#signal update_ui_now # tells the ui above our head to update
# status-effect signals
signal se_about_to_act # arg: self
# warning-ignore:unused_signal
signal se_about_to_be_attacked # arg: attacker
signal se_done_acting
signal se_turn_ended
signal se_turn_started
signal se_took_damage # arg: [source, dmg]
signal se_damaged_other # arg: the other that we damaged
# warning-ignore:unused_signal
signal se_action_phase_started
signal se_about_to_die

signal custom_initial_target_rule_check

# Nodes to find
@onready var turn_manager := get_node("/root/TurnManager")
@onready var ai := $AI
#@onready var comcard := $Puppet/Center/TurnCharacterViewport/SubViewport/CombatCard
@onready var pup := $Puppet

@export var avi: Texture2D
@export var rname := name
@export  var p_color: Color
@export  var s_color: Color

### GAMEPLAY MECHANICS STUFF
# Stats!
@export var max_lives = 1
@export var lives = 1
# amount of hp to return to life with after losing a life
@export var revive_hp_fraction = 0.75
# pretty sure all characters will be the same level
@export var level := 1
@export var gain_stats_on_lvl := false
@export var exp_reward := 100 # 1000, 2500, 4750, 8125
@export var lvl_up_boost := 0.0
const DEF_PLAYER_LVL_BOOST := 1.18921 # 1.18921^4 = 2
const DEF_ENEMY_LVL_BOOST := 1.49535  # 1.49535^4 = 5
# speed. 100 is base. Higher speed = move FIRST
@export var default_speed = 100
var base_speed : int
#export (float) var lvl_speed_boost = 1.20 # 1.2^4 ~= 2.00. Max level = 2*lvl1.
var speed: int: get = __get_speed, set = __set_speed
func __set_speed(val): base_speed = val
func __get_speed():
	return int(round(base_speed *
		(se_stat_changes["spd"] + 100)/100))
# max hp. hp can't go higher, PERIOD.
@export var default_max_hp = 100
var base_max_hp : int
#export (float) var lvl_max_hp_boost = 1.20
var max_hp: int: get = __get_max_hp, set = __set_max_hp
func __set_max_hp(val):
	base_max_hp = val
func __get_max_hp():
	return int(round(base_max_hp *
		(se_stat_changes["hp"] + 100)/100))
# hp. Goes below 0 and this character dies.
@export var default_hp = 100
var hp: int
# multiplier of attack power / 100
# Physical, Magical, Chemical, Spiritual
@export var default_atk = [100, 100, 100, 100] # (Array, int)
var base_atk : Array
#export (Array, float) var lvl_atk_boost = [1.20, 1.20, 1.20, 1.20]
var atk : Array: get = __get_atk, set = __set_atk
func __set_atk(val): base_atk = val
func __get_atk():
	var a = base_atk.duplicate()
	for i in range(len(a)):
		a[i] = int(round(a[i] *
		(se_stat_changes["atk"] + 100)/100))
	return a

# % of damage to ignore. xx%. Negative values = take more damage
@export var default_def = [0, 0, 0, 0] # (Array, int)
var base_def : Array
#export (Array, float) var lvl_def_boost = [1.20, 1.20, 1.20, 1.20]
var def: Array: get = __get_def, set = __set_def
func __set_def(val): base_def = val
func __get_def():
	def = base_def.duplicate()
	for i in range(len(def)):
		def[i] = int(round(def[i] *
		(se_stat_changes["def"] + 100)/100))
	return def
# either PLAYER'S TEAM or NOT
@export var default_on_players_team = true
var on_players_team: bool
# flat damage reduction
@export var default_damage_reduction = 0
var damage_reduction: int: get = __get_dr, set = __set_dr
func __set_dr(val): default_damage_reduction = val
func __get_dr():
	damage_reduction = int(round(default_damage_reduction +
		se_stat_changes["dr"]/100))
	return damage_reduction
# chance to dodge incoming attacks. Multiplicative w/ accuracy.
# AKA if EVA is 60 and ACC is 40, the chance to hit is (1-0.6)(0.4)=(0.4)^2=0.16.
# A percent. If negative, will make low-accuracy attacks
# easier to hit.
@export var default_evasion = 0
var base_eva : int
#export (float) var lvl_evasion_boost = 1.20
@export var evasion = 0: get = __get_eva, set = __set_eva
func __set_eva(val): base_eva = val
func __get_eva():
	evasion = int(round(base_eva +
		se_stat_changes["eva"]/100))
	return evasion
# se_StatIncrease adds itself to this array, and those numbers
# are used in calculating stats.
var se_stat_changes := {
	"atk": 0,
	"def": 0,
	"hp": 0,
	"dr": 0,
	"spd": 0,
	"eva": 0
	}
# pos in battle. Actual value does not matter, just who's next
# in line. So being -2 between a -5 and a 1 is the same as being
# -4 through 0. Two characters having the same pos are shuffled.
@export var pos = 0.0
var start_position := 0.0
var turn_start_pos: float
# resources. Mana, stamina, rage, energy, flux, corruption, psi, focus, ......
# maybe have it like ToME: only one or two resources revealed for spells you
# have unlocked, then if you happen to get a new resource-costing spell, that
# character has that resource bar revealed? And all characters already have
# these resources, they just don't have a use for them?
# RESOURCES:
# Mana, Leeches, Divine Favor
var RESOURCES_COUNT : int
@export var default_max_res: Array[int]
var base_max_res : Array
#export (Array, float) var lvl_max_res_boost = [1.20, 1.20, 1.20]
@export var default_res: Array[int]
var max_resource : Array
var resource : Array
@export var revealed_resource: Array[int]
# how much mana to regen each turn
@export var stamina_regen = 10
var base_stamina_regen : int
# 1 free heal is regained every time a Heal cell is used
@export var free_heals = 1
#export (float) var lvl_mana_regen_boost = 1.20
# true: when a spell costing favor is used or a character dies and
# causes favor to drop below 0, it'll hit 0 and take the rest out of HP
# false: just drops to 0. (for everyone who isn't especially pious)
# TODO: Also powers up certain faith moves?
@export var favor_overdraw_hurts = false
# True: allows overdraw for this resource, meaning that resource
# may be negative.
@export var allow_res_overdraw = [false, false, true]


# other stuff
# amount randomness changes speed when calculating turn order. 
# Changes every turn.
var speed_fudge := 0.0
# All possible actions.
var all_actions := Array()
# Array of arrays. Each element of this array represents the
# skills available at that level - [0] is all skills @ level 1.
var possible_primary_actions := []
var possible_secondary_actions := []
var unlockable_primary_actions := []
var unlockable_secondary_actions := []
# Primary actions usable in battle now. Should be 2 ish.
@export var max_primary_actions = 2
var primary_actions := Array()
# Secondary actions usable in battle now. Should be 1-5?
func max_secondary_actions(): return (100)
var secondary_actions := Array()
# Defend and Shift, if those are allowed to be used.
# Player characters are always allowed to shift and defend.
@export var may_use_defend = false
@export var may_use_shift = false
var usable_basic_actions := []
var all_equipped_actions : Array: get = get_all_equipped_actions
# All VISIBLE actions. The AI and Player don't know it exists if not visible.
var visible_actions = Array()
# The action selected to be used this turn. May be null if none are selected
var selected_action: Action = null
# The action last used. This is used for the Imitate action.
var last_used_action: Action = null
var possible_targets = Array()
# The targets for our action.
var selected_targets: Array = []
var targets_orig_positions: Array = []
var orig_targets := []
# True: characters targeting us cannot follow with their action;
# they'll attack whoever's in our wake instead.
var hard_to_follow := false
var dead = false
var status_effects_active = Array()
var abilities := []
var can_leave_room := true
var player_in_same_room := false: get = get_player_in_same_room
func get_player_in_same_room(): return cell == Overworld.player_room
var cell = null
var switching_rooms = true
var invulnerable = false
var vulnerable = false
var protected = false

const INTENT_PATHS = {
	"Lethal": "res://Sprites/Emoji/twe_skullbones.png",
	"Rescue": "res://Sprites/Emoji/twe_shield.png",
	"Debuff": "res://Sprites/Emoji/twe_microbe.png",
	"Damage": "res://Sprites/Emoji/twe_explosion.png",
	"Buff": "res://Sprites/Emoji/twe_mecharm.png",
	"Heal": "res://Sprites/Emoji/twe_stethoscope.png"}




# _ready is called when the node and all children are READY to do code
func _ready():
	RESOURCES_COUNT = len(CombatUI.RESOURCE_NAMES)
	if rname.is_empty(): 
		rname = name
		if rname.find("@") != -1: rname = rname.split("@")[1]
	# starting up stats and variables
	# lengthen resource list
	for _i in range(RESOURCES_COUNT - len(default_max_res)):
		default_max_res.append(0)
	for _i in range(RESOURCES_COUNT - len(default_res)):
		default_res.append(0)
	for _i in range(RESOURCES_COUNT - len(resource)):
		resource.append(0)
	for _i in range(RESOURCES_COUNT - len(allow_res_overdraw)):
		allow_res_overdraw.append(false)
	# match up defaults!
	on_players_team = default_on_players_team
	if lvl_up_boost == 0.00:
		lvl_up_boost = (DEF_PLAYER_LVL_BOOST if on_players_team 
		else DEF_ENEMY_LVL_BOOST)
	update_stats()
	speed = base_speed
	max_hp = base_max_hp
	hp = default_hp
	if on_players_team: max_lives = TurnManager.player_max_lives
	lives = max_lives
	atk = base_atk.duplicate()
	for _i in range(len(Action.ATTACK_TYPE) - len(atk)):
		atk.append(0)
	def = base_def.duplicate()
	for _i in range(len(Action.ATTACK_TYPE) - len(def)):
		def.append(0)
	damage_reduction = default_damage_reduction
	evasion = base_eva
	max_resource = base_max_res.duplicate()
	for i in range(min(len(resource), len(base_max_res))):
		resource[i] = base_max_res[i]
	#print("%s's on_players_team = %s." % [name, str(on_players_team)])
	
	pup.match_character()
	#comcard.chara = self
	
	# get all actions
	initialize_action_lists()
	
	# reset status effects
	status_effects_active = []
	
	update_resources()

var random_action_order := []
func initialize_action_lists():
	random_action_order = range(len(all_actions))
	random_action_order.shuffle()
	update_action_lists()

func update_action_lists():
	# Do basic skills: Defend and Shift
	usable_basic_actions.clear()
	if on_players_team or may_use_defend:
		usable_basic_actions.append($Defend)
	if on_players_team or may_use_shift:
		usable_basic_actions.append($Shift)
	
	# req_lvl is used to assign level unlocks.
	var req_lvl := []
	all_actions.clear()
	visible_actions.clear()
	for child in get_children():
		# Actions outside of levels - Defend, Flee, monster moves
		if child.is_in_group("actions"):
			all_actions.append(child)
			req_lvl.append(-1)
		# Level-defined actions - for PCs.
		elif child.name.begins_with("L"):
			for cc in child.get_children():
				all_actions.append(cc)
				req_lvl.append(int(child.name.right(1)))
				#print(child.name.right(1))
	
	# find usable actions out of the possible ones
#	for action in all_actions:
#		if action.visible:
#			visible_actions.append(action)
	
	unlockable_primary_actions.clear()
	unlockable_secondary_actions.clear()
	for _i in range(5):
		unlockable_primary_actions.append([])
		unlockable_secondary_actions.append([])
	
	# Assign possible primary and secondary skills
	for i in range(len(all_actions)):
		var action = all_actions[i]
		if (action.name == "Defend" or action.name == "Flee" 
		or action.name == "Shift"):
			continue
		if action.primary:
			possible_primary_actions.append(action)
		else:
			possible_secondary_actions.append(action)
			#if on_players_team:
				#unlockable_secondary_actions[req_lvl[i] - 1].append(action)
	
	# add random possible skills to the unlockables arrays
	if on_players_team:
		if len(random_action_order) == 0:
			random_action_order = range(len(all_actions))
		for i in random_action_order:
			var idx = req_lvl[i] - 1
			var act = all_actions[i]
			if possible_primary_actions.has(act) and (
			len(unlockable_primary_actions[idx]) < max_unlockable_p(idx + 1)):
				unlockable_primary_actions[idx].append(act)
			elif possible_secondary_actions.has(act) and (
			len(unlockable_secondary_actions[idx]) < max_unlockable_s(idx + 1)):
				unlockable_secondary_actions[idx].append(act)
	
	# Shuffle each skill deck
	# Wait isn't the order random anyways from the previous block?
#	if on_players_team:
#		for i in range(5):
#			unlockable_primary_actions[i].shuffle()
#			unlockable_secondary_actions[i].shuffle()
	
	# Assign primary and secondary actions
	if on_players_team:
		assign_primary_actions(unlockable_primary_actions[0])
		assign_secondary_actions(unlockable_secondary_actions[0])
		visible_actions = (
		unlockable_primary_actions + unlockable_secondary_actions)
	else:
		assign_primary_actions(possible_primary_actions)
		assign_secondary_actions(possible_secondary_actions)
		visible_actions = (
		possible_primary_actions + possible_secondary_actions)

# Returns the number of unlockable primary skills on levelup at level 'lvl'.
func max_unlockable_p(lvl: int) -> int:
	return 2 if lvl == 1 else 1

# Returns the number of unlockable secondary skills on levelup at level 'lvl'.
func max_unlockable_s(_lvl := 0) -> int:
	return 3

# Assigns this character's primary actions.
func assign_primary_actions(acts: Array):
	primary_actions.clear()
	for act in acts:
		if len(primary_actions) >= max_primary_actions:
			break
		if act.primary and can_equip_action(act):
			primary_actions.append(act)
	if TurnManager.battle_going and on_players_team:
		CombatUI.update_action_buttons_array()
	update_resources()

# Assigns this character's secondary actions.
func assign_secondary_actions(acts: Array):
	secondary_actions.clear()
	for act in acts:
		if on_players_team and len(secondary_actions) >= max_secondary_actions():
			break
		if !act.primary and can_equip_action(act):
			secondary_actions.append(act)
	if TurnManager.battle_going and on_players_team:
		CombatUI.update_action_buttons_array()
	update_resources()

func get_all_equipped_actions() -> Array:
	return primary_actions + secondary_actions + usable_basic_actions

# Returns all actions that can be equipped in battle.
# If a unit is using an action NOT part of this list,
# something is wrong!!!!!
func all_equipable_actions() -> Array:
	if !on_players_team:
		return possible_primary_actions + possible_secondary_actions
	var acts := []
	#print("lvl = %d" % level)
	for i in range(level):
		acts.append_array(unlockable_primary_actions[i])
		acts.append_array(unlockable_secondary_actions[i])
	return acts

# Returns whether we can equip a skill. False means it cannot be added NOW.
# True means it CAN be added NOW. Doesn't mean it can't be added
# if some slots are freed by unequipping other skills.
func can_equip_action(action: Action) -> bool:
	# Is even allowed to use it
	return all_equipable_actions().has(action) and (
	# We have enough slots to use it
	(action.primary and len(primary_actions) < max_primary_actions
	and !(action in primary_actions)) or (!action.primary 
	and len(secondary_actions) < max_secondary_actions()
	and !(action in secondary_actions)))

func action_is_equipped(action: Action) -> bool:
	return (action in primary_actions 
	or action in secondary_actions)

# Fills empty skill slots with skills that can be used, if there are 
# empty slots.
func fill_action_slots():
	# Primary
	for _i in range(max_primary_actions - 1, len(primary_actions) - 1, -1):
		for j in range(level - 1, -1, -1):
			for act in unlockable_primary_actions[j]:
				if !primary_actions.has(act) and can_equip_action(act):
					assign_primary_actions(primary_actions + [act])
	# Secondary
	for _i in range(max_secondary_actions() - 1, len(secondary_actions) - 1, -1):
		for j in range(level - 1, -1, -1):
			for act in unlockable_secondary_actions[j]:
				if !secondary_actions.has(act) and can_equip_action(act):
					assign_secondary_actions(secondary_actions + [act])

# Returns false if this action cannot be cast because of resource
# deficiency. Takes the amount of resources and allow_res_overdraw
# into account.
func has_resources_for_action(_action : Action):
	return len(resources_action_exceeds(_action)) == 0

# Returns how much more resources the character needs to cast this,
# or 0 if they have enough. If we allow overdraw, that resource will be
# ignored!
func resources_action_exceeds(_action: Action):
	var results = []
	for i in range(len(_action.costs)):
		if !allow_res_overdraw[i] and resource[i] < _action.costs[i]:
			results.append(i)
	return results

# Used in TurnManager.targets_in_range(). To be overridden.
# If false, _query cannot be targeted.
var custom_initial_target_rule_passed = true
func custom_initial_targets_rule(_query) -> bool:
	custom_initial_target_rule_passed = true
	emit_signal("custom_initial_target_rule_check", self, _query)
	return custom_initial_target_rule_passed

# Select an action, if it's one of ours.
func select_action(action: Action, targets: Array, 
	ignore_usability = false):
	# do nothing if either action or target is not there
	if (dead or !action or NIU.iiv(targets) or len(targets) == 0
	or ((!action.usable	or !action.visible) 
	and !(ignore_usability and all_actions.has(action))
	and (action.name != "Defend" or may_use_defend) 
	and (action.name != "Shift" or may_use_shift))
	or targets.has(null)):
		deselect_action()
		return null
	
	# skip if we cannot afford this
	if !has_resources_for_action(action): 
		return null
	
	# skip if it's multitarget and the array is bad
	if !action.verify_multi_target(targets):
		print_in_room("Warning: %s had a bad array of targets with %s." % [name, action.name])
		print_in_room("Bad array of targets: %s" % str(targets))
		breakpoint
		return null
	
	# select it
	selected_action = action
	selected_targets = targets.duplicate()
	orig_targets = targets.duplicate()
	possible_targets = selected_action.possible_initial_targets()
	turn_start_pos = pos
	for targ in selected_targets:
		var chara = null
		if NIU.get_class_name(targ) == "TurnCharacter": chara = targ
		elif NIU.get_class_name(targ) == "StatusEffect": chara = targ.affected
		if chara != null:
			targets_orig_positions.append(chara.pos)
		print_in_room("%s is targeting %s with %s out of %d targets." % 
		[name, targ.name, action.name, len(possible_targets)])
	if is_instance_valid(selected_targets[0].get_chara()):
		initial_target_team = selected_targets[0].get_chara().on_players_team
	return action

func deselect_action():
	selected_action = null
	selected_targets.clear()
	targets_orig_positions.clear()

# Sets our targets to be this new group.
func change_targets(targets, force_allow_FF = true,
				force_allow_EF = true,
				force_allow_self = true,
				ignore_range = true):
	var oldtargs = selected_targets.duplicate()
	selected_targets.clear()
	orig_targets.clear()
	# break in some way
	for target in targets:
		var chara = null
		if NIU.get_class_name(target) == "TurnCharacter":
			chara = target
		elif NIU.get_class_name(target) == "StatusEffect":
			chara = target.affected
		if chara == null: continue
		if chara.on_players_team == on_players_team and (chara != null and
			!selected_action.target_friendlies and !force_allow_FF):
			print_in_room("%s did NOT change targets to %s: FRIENDLY FIRE" % 
			[name, target.name])
			continue
		if chara.on_players_team != on_players_team and (chara != null and
			!selected_action.target_enemies and !force_allow_EF):
			print_in_room("%s did NOT change targets to %s: ENEMY FIRE" % 
			[name, target.name])
			continue
		if chara != null and chara == self and !force_allow_self:
			print_in_room("%s did NOT change targets to %s: SELF FIRE" % 
			[name,target.name])
			continue
		if !selected_action.possible_initial_targets().has(target) and !ignore_range:
			print_in_room("%s did NOT change targets to %s: OUT OF RANGE" % 
			[name,target.name])
			continue
		# if it didn't break yet, add them to targs
		print("%s changed their target to %s!" % 
		[name, target])
		selected_targets.append(target)
	
	# If we got any new targets, delete the old ones
	if len(selected_targets) < 0:
		selected_targets = oldtargs.duplicate()
	oldtargs.clear()


# Select a random action.
func select_action_random():
	var ai_targs = ai.get_AI_action_and_target()
	#print("AI target decision: %s" % str(ai_targs))
	if len(ai_targs) > 0:
		return select_action(ai_targs[0], [ai_targs[1]]
		+ ai_targs[0]._auto_targets([ai_targs[1]]))
	var usable_actions = []
	for act in visible_actions:
		if act._update_usability() and has_resources_for_action(act):
			usable_actions.append(act)
	# skip if we have no usable actions
	if len(usable_actions) == 0: return select_action(null, [null])
	var action = usable_actions[randi() % len(usable_actions)]
	var targets = action.possible_initial_targets()
	var target = targets[randi() % len(targets)]
	targets = action._auto_targets([target])
	return select_action(action, [target] + targets)


# When THE TURN STARTS.
func on_turn_started():
	deselect_action()
	#print("Turn started for " + name)
	emit_signal("se_turn_started")
	
	start_position = pos
	
	# IF AN AI: select a random move to do
	if(!on_players_team and !dead):
		select_action_random()
	
	_on_turn_started_override()
	
	update_resources()
	pup.load_translation()

# Overridable.
func _on_turn_started_override():
	pass

func on_action_processing():
	pass

var initial_target_team : bool

# When anybody dies. Use for whatever. called after turnmanager handles
# their stuff for when a character dies.
func on_character_killed(chara):
	
	# do on_target_killed or whatever
#	if selected_targets.has(chara):
#		on_target_killed_before_action()
	
	# do on_caster_killed on all our se's
	for se in status_effects_active:
		if chara == se.caster:
			se._on_caster_died(null)

var acting = false

# When IT'S OUR TURN TO DO SOMETHING.
func perform_action():
	if self.is_queued_for_deletion() or dead: 
		print_in_room("%s is DEAD before status effects, and " % name
			+ " is not going to do anything!")
		return
	
	# Figure out validity of targets real quick
	#on_target_killed_before_action()
	
	acting = true
	TurnManager.__last_acting_chara = self
	emit_signal("se_about_to_act",self)
	
	pup.action = selected_action
	pup.targets = selected_targets.duplicate()
	
	# Tell targets we're about to attack them
	if is_instance_valid(selected_action) and (
	selected_action.power > 0) and !selected_action.beneficial:
		for targ in selected_targets.duplicate():
			if NIU.iiv(targ) and NIU.iiv(targ.get_chara()):
				targ.get_chara().emit_signal(
				"se_about_to_be_attacked", self)
	
	# Now that we've done status effects, we may be dead.
	if dead:
		print_in_room("%s is dead after status effects, " % name
			+ "and is not going to do anything!")
		acting = false
		return
	
	
	# skip if not doing anything
	# ANIM: Show the name of the action they're doing
	if (selected_action == null or len(selected_targets) <= 0
	or (selected_action.require_max_targets and 
	len(selected_targets) != selected_action.max_targets)):
		# ANIM: Show that they're doing nothing
		if !TurnManager.mute_does_nothing_logs:
			print_in_room("(%.2f) %s does nothing!" % [speed + speed_fudge, 
			name])
	
	else:
		# ANIM: Step forward or toward target(s)
		pup.step_forward()
		
		var targnames = selected_targets[0].name
		for i in range(1, len(selected_targets)):
			targnames += ", " + selected_targets[i].name
		print_in_room("(%.2f) %s uses %s on %s!" % 
			[speed + speed_fudge, self.name, 
			selected_action.name, targnames])
		
		
		# ANIM: strike a pose
		if player_in_same_room:
			#pose_o()
			pass
		
		# ANIM: particles and such
		# Yield should end the moment the effects should be applied,
		# which should vary from animation to animaiton
		# So like a fire move should do a bunch of flames then as
		# the targets are in the particles they all get affected,
		# and they get the status effects and HP loss and stuff
		var targs_before = selected_targets.duplicate()
		var targ_hp_before = []
		for target in selected_targets:
			if target.is_class("TurnCharacter"):
				targ_hp_before.append(target.hp) # remember previous hp
			elif target.is_class("StatusEffect"):
				targ_hp_before.append(target.affected.hp)
		# do the action!
		await selected_action.use(selected_targets)
#		var useact = selected_action.use(selected_targets)
#		if useact is GDScriptFunctionState:
#			await useact.completed
		
		
		# ANIM: Show final effects. "Garfield has been defeated!"
		
		for i in range(len(targ_hp_before)):
			if targs_before[i].hp != targ_hp_before[i]:
				emit_signal("se_damaged_other", targs_before[i])
		
		# ANIM: Step back into formation
		pup.step_back()
		
		# DIVINE FAVOR
		var favor_overdraw = calc_favor_overdraw(0)
		if favor_overdraw and favor_overdraw_hurts:
#			yield(CombatUI.set_status("%s incurred %d divine disfavor!" % [name, 
#			favor_overdraw], CombatPuppeteer.default_status_duration), 
#			"completed")
			pay_favor(0)
		
		# Show each new status effect added
	#	for se in TurnManager.se_added_this_turn:
	#		yield(CombatUI.set_status(se._application_message()
	#		, compup.default_status_duration), "completed")
	
	last_used_action = selected_action
	
	acting = false
	
	emit_signal("se_done_acting")

# When THE TURN ENDS.
func on_turn_ended():
	resource[3] = min(max_resource[3], resource[3] + stamina_regen
	+ max_resource[3] * int(TurnManager.player_out_of_combat()))
	CombatPuppeteer.get_last_added_anim().add_effect_res(pup, 3, resource[3])
	emit_signal("se_turn_ended")
	deselect_action()
	hard_to_follow = false
	switching_rooms = false
	handle_dead_at_turn_end()


# the final calculation of speed
func final_speed():
	return speed + speed_fudge

func set_resource(res_index, amt):
	resource[res_index] = min(amt, max_resource[res_index])
	#if revealed_resource.has(res_index):

func refill_resources():
	for i in range(len(resource)):
		set_resource(i, max_resource[i])

# Changes pos to be at the new relative pos.
# Good to do .25's here.
func change_position(new_pos, evasively = false):
	pos = new_pos
	if evasively:
		hard_to_follow = true
	cell.fix_positions()

func swap_positions(friend):
	var t = pos
	pos = friend.pos
	friend.pos = t
	turn_manager.fix_positions()

func on_positions_fixed():
	# check for target follows
	if len(selected_targets) > 0 and TurnManager.actions_processing:
		var seltargs = selected_targets.duplicate()
		for i in range(len(seltargs)):
			var targ = null
			if NIU.get_class_name(seltargs[i]) == "TurnCharacter": 
				targ = seltargs[i]
			elif NIU.get_class_name(seltargs[i]) == "StatusEffect": 
				targ = seltargs[i].affected
			if targ == null: continue
			var targeted_pos = targets_orig_positions[i]
			# the pos our new should be in/near
			var p = targeted_pos + (pos - start_position
			) if (selected_action.close_range or 
			selected_action.skip_targeting) else targeted_pos
			# Can't follow - target's evasive, or attack doesn't follow,
			# or one of us moved >0.5 positions away
			if (abs(targ.pos - p) > 0.6 or 
			!selected_action.possible_initial_targets().has(targ)
			) and (targ.hard_to_follow or !selected_action.follow
			or selected_action.close_range or 
			selected_action.skip_targeting):
				# Redirect!
				# target the original target, if that's possible
				var breakout = false
				for orig in orig_targets:
					if !(NIU.get_class_name(orig) in "TurnCharacterStatusEffect"):
						continue
					if abs(orig.pos - p) < 0.6:
						selected_targets[i] = orig
						breakout = true
						break
				if breakout:
					break
				# If not, target the one in that spot, if possible
				var t = cell.get_inhab_in_pos(p, 
				targ.on_players_team)
				if NIU.iiv(t):
					selected_targets[i] = t
					break
				# If not, target the next closest target to that location
				var eparty = (cell.gsf() if targ.on_players_team
				else cell.gse())
				# look at rightmost target
				if p + 0.1 > float(len(eparty) - 1) / 2.0:
					selected_targets[i] = cell.get_inhab_in_pos(p,
					targ.on_players_team)
					break
				# now leftmost
				if p - 0.1 < -float(len(eparty) - 1) / 2.0:
					selected_targets[i] = cell.get_inhab_in_pos(p,
					targ.on_players_team)
					break
				# now swirl around
				var j := 1.0 if (cell.positions_are_whole(
				targ.on_players_team)) == (int(abs(p * 2.0)) % 2 == 0
				) else 0.5
				var bias = sign(targ.pos - p)
				while !breakout:
					t = cell.get_inhab_in_pos(p + (j * bias), 
					targ.on_players_team)
					if !NIU.iiv(t):
						j *= -1.0
						if j > 0:
							j += 1.0

# take damage. Returns amount of damage taken.
func take_damage(power, _source, a_type = 1, 
			a_mult = 1.0, d_mult = 1.0, calc = true) -> int:
	if dead or power == 0: return 0
	if power * a_mult < 0: # heal instead
		return -heal(-power * a_mult, false)
	var calc_dmg = Action.calculate_damage(_source, self, a_type,
	power, a_mult, d_mult) if calc else power
	print_in_room("%s took %s damage!" % [name, str(calc_dmg)])
	hp -= calc_dmg
	emit_signal("se_took_damage", [_source, calc_dmg])
	if is_instance_valid(_source): 
		_source.emit_signal("se_damaged_other", self)
	CombatPuppeteer.get_last_added_anim().add_effect_hp(pup, hp, 
	a_type)
	if hp <= 0:
		die(_source)
	#elif calc_dmg != 0:
		#SoundOp.play_hit_sound(a_type)
	
	return int(min(hp + calc_dmg, calc_dmg))

func heal(amount : int, allow_overheal = false):
	if amount == 0: return 0
	if amount < 0: # hurt instead
		return -take_damage(-amount, self, 0, 1.0, 0.0)
	if allow_overheal:
		print_in_room("%s heals for %s!" % [name, str(amount)])
		hp += amount
		return
	amount = int(min(max_hp, hp + amount) - hp)
	print_in_room("%s heals for %s!" % [name, str(amount)])
	hp = int(min(max_hp, hp + amount))
	# ANIM: heal
	CombatPuppeteer.get_last_added_anim().add_effect_hp(pup, hp, 
	0)
	return amount

func set_max_hp(maxhp):
	maxhp = max(maxhp, 1)
	max_hp = maxhp
	hp = int(min(max_hp, hp))

# die
var time_since_death := 0.0
var death_pos : Vector3
var death_room
func die(_killer = null):
	if dead:
		return
	
	dead = true
	emit_signal("se_about_to_die")
	if !dead:
		return
	CombatPuppeteer.get_last_added_anim().add_effect_kill(pup)

# Actually get removed from play at turn end when dead.
# OR lose a life.
func handle_dead_at_turn_end():
	if !dead:
		return
	# lose a life instead of going away forever
	if lives > 1:
		lives -= 1
		hp = int(round(max_hp * revive_hp_fraction))
		dead = false
		#SoundOp.play_death_sound(on_players_team)
		#CombatPuppeteer.show_status("%s lost a life!" % _get_name())
		return
	death_room = cell
	if !on_players_team: 
		TurnManager.give_exp_to_player(int(exp_reward * pow(level, lvl_up_boost)))
	for se in status_effects_active.duplicate(): 
		se.end_effect()
	cell.combatant_killed(self)
	if TurnPlayer.party.has(self):
		TurnPlayer.party.erase(self)
	time_since_death = 0.0
	death_pos = position
	remove_from_group("turn_characters")
	# ANIM: Die
	CombatPuppeteer.ensure_blank_anim().add_effect_set(pup, 
	"death_anim_playing", true)
	CombatPuppeteer.get_last_added_anim().simultaneous = true
	

# Pays the favor cost of things. If a character dies, everyone pays
# their overkill favor. If we're using a favor-costing move, 
# this is called AFTER the move is used. So, during the action 
# performance, favor will be negative.
func pay_favor(favor) -> int:
	# Pay resource
	var overdraw = calc_favor_overdraw(favor)
	var resource_i = resource[2]
	set_resource(2, max(resource[2] - favor, 0))
	# Overdraw pains
	if overdraw and allow_res_overdraw[2] and favor_overdraw_hurts:
		print_in_room("%s lost %s Divine Favor..." % [name, 
		str(min(favor, resource_i))])
		#TODO: make the deity in question be the source instead....?
		# So if there's like a thorns buff on, the deity can take
		# damage and go "KNOCK IT OFF" or something. Do enough damage
		# and they come down and join the enemies? idk
		# Or this character loses their peity? Max divine favor = 0?
		take_damage(overdraw, null, Action.ATTACK_TYPE.SPIRITUAL)
	return overdraw

func calc_favor_overdraw(cost) -> int:
	return int(max(cost - resource[2], 0))



func update_resources():
	# check all actions for new resources to reveal or unreveal
	revealed_resource.clear()
	for action in get_all_equipped_actions():
		# Update revealed resources
		for i in range(len(action.costs)):
			if action.costs[i] > 0 and !revealed_resource.has(i):
				revealed_resource.append(i)
			# Reveal divine favor if we take damage from overdrawing it
			elif i == 2 and favor_overdraw_hurts and !revealed_resource.has(i):
				revealed_resource.append(i)

func get_all_usable_resources() -> Array:
	var results := []
	# check all actions for new resources to reveal or unreveal
	for action in all_equipable_actions():
		# Update revealed resources
		for i in range(len(action.costs)):
			if action.costs[i] > 0 and !results.has(i):
				results.append(i)
			# Reveal divine favor if we take damage from overdrawing it
			elif i == 2 and favor_overdraw_hurts:
				results.append(i)
	return results


func highlight_ui():
	#comcard.highlight()
	pass

func un_highlight_ui():
	#comcard.un_highlight()
	pass

func add_status_effect(status_effect):
	if status_effect.ability:
		abilities.append(status_effect)
		return
	if status_effects_active.has(status_effect):
		return
	status_effects_active.append(status_effect)
	# add the addition of this status effect to anim
	if TurnManager.battle_going:
		CombatPuppeteer.add_status_change_to_anim(status_effect, true,
		status_effect.stacks, status_effect._time_left, status_effect.extra_info)

func remove_status_effect(status_effect):
	if !status_effects_active.has(status_effect):
		return
	status_effects_active.erase(status_effect)
	# add the removal of this status effect to anim
	CombatPuppeteer.add_status_change_to_anim(status_effect, false)

func _get_name():
	return rname if !rname.is_empty() else name

func get_chara():
	return self

# Called when this character goes from NOT being in the player's
# current cell to being in the cell.
func on_player_enters_room() -> void:
	visible = true

func on_player_exits_room() -> void:
	visible = false

func is_part_of_a_room() -> bool:
	return is_instance_valid(cell)

var destination_room = null
# Get ready to go to a different cell when the time comes.
func queue_to_change_rooms(to) -> void:
	if is_instance_valid(to):
		to.queue_to_enter(self)
	elif is_instance_valid(cell):
		cell.queue_to_exit_only(self)

func print_in_room(text):
	if (!(!player_in_same_room and TurnManager.mute_non_player_room_actions)
	and is_instance_valid(cell)):
		print("[%s] %s" % [cell.name, text])
	elif dead and is_instance_valid(death_room) and (
		player_in_same_room or !TurnManager.mute_non_player_room_actions):
		print("[%s] %s" % [death_room.name, text])
	elif !TurnManager.mute_non_player_room_actions:
		print("[NO ROOM] " + text)

# If this is true for all enemies, then the player may move
# between rooms at will.
func allow_move() -> bool:
	for se in status_effects_active:
		if se.allow_move:
			return true
	return false

func end_all_status_effects(lvl = true):
	for se in status_effects_active.duplicate():
		if !lvl or !se.keep_through_lvl_up:
			se.end_effect()

func end_all_detrimental_status_effects():
	for se in status_effects_active.duplicate():
		if !se.is_buff:
			se.end_effect()

# Updates speed, maxhp, etc
func update_stats():
	var power = get_level() - 1 if gain_stats_on_lvl else 0
	base_eva = int(default_evasion * pow(lvl_up_boost, power))
	base_stamina_regen = int(stamina_regen * pow(lvl_up_boost, power))
	base_max_hp = int(default_max_hp * pow(lvl_up_boost, power))
	base_speed = int(default_speed * pow(lvl_up_boost, power))
	default_hp = int(default_hp * pow(lvl_up_boost, power))
	
	base_atk.clear()
	for i in range(len(default_atk)):
		base_atk.append(int(default_atk[i] * pow(lvl_up_boost, power)))
	for _i in range(len(Action.ATTACK_TYPE) - len(default_atk)):
		base_atk.append(100)
	base_def.clear()
	for i in range(len(default_def)):
		base_def.append(int(default_def[i] * pow(lvl_up_boost, power)))
	for _i in range(len(Action.ATTACK_TYPE) - len(default_def)):
		base_def.append(0)
	base_max_res.clear()
	for i in range(len(default_max_res)):
		base_max_res.append(int(default_max_res[i] * pow(lvl_up_boost, power)))
	for _i in range(RESOURCES_COUNT - len(default_max_res)):
		base_max_res.append(0)
	
	# end status effects so we don't have weird stat changes.
	end_all_status_effects()
	
	# now change actual stats
	evasion = base_eva
	speed = base_speed
	max_hp = base_max_hp
	stamina_regen = base_stamina_regen
	hp = default_hp
	atk = base_atk.duplicate()
	def = base_def.duplicate()
	max_resource = base_max_res.duplicate()

func full_heal(cost := false, individual = true):
	if cost:
		if free_heals == 0:
			return
		else:
			free_heals -= 1
	CombatPuppeteer.ensure_blank_anim()
	heal(999999)
	end_all_detrimental_status_effects()
	refill_resources()
	if individual:
		TurnManager.end_current_turn()

func set_level(lvl: int):
	var lvlup = lvl > level
	level = lvl
	update_stats()
	if lvlup:
		heal(99999)
		refill_resources()
		fill_action_slots()


func get_level() -> int:
	return TurnManager.player_lvl if on_players_team else level

func get_party() -> Array:
	return cell.gsf() if on_players_team else cell.gse()


func get_class_name(): return "TurnCharacter"
