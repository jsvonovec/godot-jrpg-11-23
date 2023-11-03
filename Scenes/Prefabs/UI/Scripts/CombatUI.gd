extends Control

#class_name CombatUI
# CONSTANTS FOR UIS AND SUCH
# 0: Mana			(spells cost this, and it regens slowly or with pots)
# 1: Leeches		(spells cost 1, regain all on that target when killed)
# 2: Divine Favor	(Deaths reduce this, spells gain this. Eventually cuts
#					into HP instead when it drops to 0!)
# 3: Stamina

var showing_status = false
signal status_done_showing

const RESOURCE_NAMES = ["Fuel", "Leeches", "Divine Favor",
"Stamina"]
const RESOURCE_SINGLE_NAMES = ["Fuel","Leech","Divine Favor",
"Stamina"]
const RESOURCE_COLORS = [Color.CORAL, Color.DARK_RED, Color.KHAKI, 
Color.AQUAMARINE]
# Physical, Magical, Chemical, Spiritual
const ATTACK_TYPE_COLORS = [Color.CRIMSON, Color.FUCHSIA, 
Color.GREEN_YELLOW, Color.LIGHT_GOLDENROD]
const ATTACK_TYPE_BUTTON_LIGHTNESS_MULT := 0.5
#const BAD_TARGET_DARKNESS_MULT := 0.35
const ENEMY_P_COLOR = Color.WEB_GRAY
const ENEMY_S_COLOR = Color.LIGHT_GRAY

@onready var turn_player := get_node("/root/TurnPlayer")
var _character

@export var action_button_prefab: PackedScene
@export var room_button_prefab: PackedScene
var combat_button
var room_button
var action_buttons : Array
var target_buttons : Array
var room_buttons : Array
var finish_targeting_button
@export var finish_targeting_text = "Finish Targeting"

enum DECISION_STEP {ACT_DEF_FLEE, SHIFT, ACTIONS, TARGET, DONE}
var decision_step
var action
var action_button_pushed
var targets_so_far = []

const drain_hsv_change = [0.0, -0.32, -0.8]
func get_drained_color(res_idx: int) -> Color:
	return Color.from_hsv(RESOURCE_COLORS[res_idx].h + drain_hsv_change[0],
					RESOURCE_COLORS[res_idx].s + drain_hsv_change[1],
					RESOURCE_COLORS[res_idx].v + drain_hsv_change[2])

func get_drained_color_any(color: Color) -> Color:
	return Color.from_hsv(color.h + drain_hsv_change[0],
					color.s + drain_hsv_change[1],
					color.v + drain_hsv_change[2])

func _ready() -> void:
	combat_button = load(action_button_prefab.resource_path)
	room_button = load(room_button_prefab.resource_path)
	hide()
	$Top/Status.hide()
	$Top/Description/Label.text = ""
	$Top/Description.hide()
	
	# initialize action buttons array
	action_buttons = Array()
	for i in $Top/S/H/Actions/List.get_child_count():
		if $Top/S/H/Actions/List.get_child(i) is Button:
			var starting_button = $Top/S/H/Actions/List.get_child(i)
			action_buttons.append(starting_button)
			attach_button_signal(starting_button, true)
	
	# initialize target buttons array
	target_buttons = Array()
	for i in $Top/S/H/Targets/List.get_child_count():
		if $Top/S/H/Targets/List.get_child(i) is Button:
			var starting_button = $Top/S/H/Targets/List.get_child(i)
			target_buttons.append(starting_button)
			attach_button_signal(starting_button, false)

# is_action, bool: true, signals have action in them. false:
# signals have target in them
func attach_button_signal(button, is_action, is_room = false):
	#action
	if is_action:
		button.connect("pressed", 
			_on_ActionButton_pressed.bind(button))
		button.connect("focus_entered", 
			_on_ActionButton_focus_entered.bind(button))
		button.connect("focus_exited",
			_on_ActionButton_focus_exited.bind(button))
		button.connect("mouse_entered", 
			_on_ActionButton_focus_entered.bind(button))
		button.connect("mouse_exited", 
			_on_ActionButton_focus_exited.bind(button))
		return
	#target
	elif !is_room:
		button.connect("pressed", 
			_on_TargetButton_pressed.bind(button))
		button.connect("focus_entered", 
			_on_TargetButton_focus_entered.bind(button))
		button.connect("focus_exited", 
			_on_TargetButton_focus_exited.bind(button))
		button.connect("mouse_entered", 
			_on_TargetButton_focus_entered.bind(button))
		button.connect("mouse_exited", 
			_on_TargetButton_focus_exited.bind(button))
	elif is_room:
		button.connect("pressed",
			_on_RoomButton_pressed.bind(button))


# start-of-battle stuff
func start_battle():
	visible = true
# warning-ignore:return_value_discarded
	#TurnManager.connect("turn_started", self, "on_turn_started")
# warning-ignore:return_value_discarded
	TurnManager.connect("begin_action_processing", 
					on_begin_action_processing)
# warning-ignore:return_value_discarded
	TurnPlayer.connect("selecting_character", select_character)

func select_character(character):
	return_focus_to_previous_step(true)
	_character = character
	update_action_buttons_array()
	if _character.selected_action == null:
		decision_step = DECISION_STEP.ACT_DEF_FLEE
	else:
		decision_step = DECISION_STEP.DONE
	set_description(null)
	queue_redraw()
	update_flee_eligibility()
	update_act_eligibility()
	$Top/S/H/General/List/Act.call_deferred("grab_focus")

# adds new buttons, invisibles unused buttons
func update_action_buttons_array():
	# FOR NOW, we have PRIMARY FIRST then SECONDARIES LAST
	var actions = _character.primary_actions + _character.secondary_actions
	for button in action_buttons:
		button.visible = false
	# ACTIONS
	for i in range(len(actions)):
		# we have no button in this slot - create one
		if i >= len(action_buttons):
			var new_button = combat_button.instantiate()
			action_buttons.append(new_button)
			$Top/S/H/Actions/List.add_child(new_button)
			attach_button_signal(new_button, true)
		# now update it
		var button: Button = action_buttons[i]
		button.visible = true
		button.action = actions[i]
		#button.name = button.action.name
		button.text = "*" if actions[i].primary else ""
		button.text += button.action._get_name()
		button.text += "*" if actions[i].primary else ""
		button.icon = button.action.icon
		button.material.set_shader_parameter("tempo", SoundOp.tempo)
		button.modulate = (
		ATTACK_TYPE_COLORS[button.action.attack_type].lightened(
			ATTACK_TYPE_BUTTON_LIGHTNESS_MULT)
			)
		# Focus neighbors
		if i > 0:
			button.focus_neighbor_top = action_buttons[i - 1].get_path()
		if i + 1 < len(action_buttons):
			button.focus_neighbor_bottom = action_buttons[i + 1].get_path()
		if decision_step == DECISION_STEP.TARGET and i < len(target_buttons):
			button.focus_neighbor_right = target_buttons[i].get_path()
		# disable it if we can't afford it
		button.disabled = (_character.dead or
			!button.action._update_usability())

func update_targets_buttons_array():
	if action == null or _character.dead: return
	for button in target_buttons:
		button.visible = false
	# TARGETS
	var possible_targets: Array
	if len(targets_so_far) > 0:
		possible_targets = action.possible_following_targets(targets_so_far)
	else:
		possible_targets = action.possible_initial_targets()
	possible_targets.sort_custom(action.sort_targets_by_benefitting_party)
	for i in range(len(possible_targets)):
		# we have no button in this slot - create one
		if i >= len(target_buttons):
			var new_button = combat_button.instantiate()
			# TODO TODO TODO TODO TODO FIX INSTANCE UP HERE ^^^^^^
			# Uhhh... what's wrong with it....???
			target_buttons.append(new_button)
			$Top/S/H/Targets/List.add_child(new_button)
			attach_button_signal(new_button, false)
		# now update it
		target_buttons[i].visible = true
		target_buttons[i].target = possible_targets[i]
		#target_buttons[i].name = possible_targets[i]._get_name()
		target_buttons[i].text = possible_targets[i]._get_name()
		# make grey if suboptimal target
		if (is_instance_valid(target_buttons[i].target.get_chara())
		and ((target_buttons[i].target.get_chara().on_players_team 
		and !action.beneficial) or (
		!target_buttons[i].target.get_chara().on_players_team and 
		action.beneficial))):
			target_buttons[i].modulate = (Color.KHAKI)
			target_buttons[i].text += "?"
		else:
			target_buttons[i].modulate = Color.WHITE
	
	# Add "Finish Targeting" button
	if len(targets_so_far) > 0 and !action.require_max_targets:
		if len(possible_targets) == len(target_buttons):
			var new_button = combat_button.instantiate()
			target_buttons.append(new_button)
			$Top/S/H/Targets/List.add_child(new_button)
			attach_button_signal(new_button, false)
		target_buttons[-1].name = "Finish Targeting"
		target_buttons[-1].text = finish_targeting_text
		target_buttons[-1].visible = true
		finish_targeting_button = target_buttons[-1]
	
	# Focus neighbors
	for i in range(len(target_buttons)):
		if i > 0:
			target_buttons[i].focus_neighbor_top = target_buttons[i - 1].get_path()
		if i + 1 < len(target_buttons):
			target_buttons[i].focus_neighbor_bottom = target_buttons[i + 1].get_path()
		if i < len(action_buttons):
			target_buttons[i].focus_neighbor_left = action_buttons[i].get_path()

# adds new buttons, invisibles unused buttons
func update_rooms_buttons_array():
	for button in room_buttons:
		button.visible = false
	var rooms = Overworld.player_room.get_connected_rooms()
	for i in range(len(rooms)):
		# we have no button in this slot - create one
		if i >= len(room_buttons):
			var new_button = room_button.instantiate()
			room_buttons.append(new_button)
			new_button.cell = rooms[i]
			$R/C/H/G.add_child(new_button)
			attach_button_signal(new_button, false, true)
		# now update it
		var button = room_buttons[i]
		button.visible = true
		button.cell = rooms[i]
		#button.name = rooms[i].name
		button.text = rooms[i].name

	
	queue_redraw()


func _draw() -> void:
	# Make buttons disappear if actions are going
	$Top/S.visible = !CombatPuppeteer.still_animating
	$Top/ExtraButtons.visible = !CombatPuppeteer.still_animating
	$Top/ExtraButtons2.visible = !CombatPuppeteer.still_animating
	
	# Move On to Next Round
	$R/C/H/MOVE.visible = (TurnManager.player_out_of_combat()
		and !CombatPuppeteer.still_animating)
	
	# ALL BUT TARGET
	if (decision_step != DECISION_STEP.TARGET
	and decision_step != DECISION_STEP.SHIFT):
		targets_so_far.clear()
	# ACTIONS OR TARGET
	if (decision_step == DECISION_STEP.ACTIONS
	or decision_step == DECISION_STEP.TARGET):
		$Top/S/H/General.visible = true
		#$Top/Description.visible = true
		$Top/S/H/Actions.visible = true
		$Top/S/H/Targets.visible = decision_step == DECISION_STEP.TARGET
		$Top/ExtraButtons/CancelAction.visible = false
		$Top/S/H/Back.visible = true
		if decision_step == DECISION_STEP.ACTIONS:
			give_number_shortcuts_to_actions()
		else:
			give_number_shortcuts_to_targets()
	# SHIFT (only act def flee, and targets and desc)
	elif decision_step == DECISION_STEP.SHIFT:
		$Top/S/H/General.visible = true
		$Top/S/H/Actions.visible = false
		$Top/S/H/Targets.visible = true
		#$Top/Description.visible = true
		$Top/ExtraButtons/CancelAction.visible = false
		$Top/S/H/Back.visible = true
		give_number_shortcuts_to_targets()
	# ACT DEF FLEE
	elif decision_step != DECISION_STEP.DONE:
		action_button_pushed = null
		#set_description(null)
		$Top/S/H/General.visible = true
		$Top/S/H/Actions.visible = false
		$Top/S/H/Targets.visible = false
		#$Top/Description.visible = $Top/Description/Label.text != ""
		$Top/ExtraButtons/CancelAction.visible = false
		$Top/S/H/Back.visible = false
		give_number_shortcuts_to_act_def_flee()
	# DONE
	else:
		action_button_pushed = null
		set_description(null)
		$Top/S/H/General.visible = false
		$Top/S/H/Actions.visible = false
		$Top/S/H/Targets.visible = false
		$Top/S/H/Back.visible = false
		$Top/Description.visible = false
		$Top/ExtraButtons/CancelAction.visible = true
	
	for b in action_buttons:
		b.focus_mode = FOCUS_ALL if (decision_step == DECISION_STEP.ACTIONS 
		or decision_step == DECISION_STEP.TARGET) else FOCUS_NONE
	for b in target_buttons:
		b.focus_mode = FOCUS_ALL if decision_step == (DECISION_STEP.TARGET
	) else FOCUS_NONE
	$Left/CharaStatuses/CharaStatusDefault.hide()
	update_charastatuses()

func update_charastatuses() -> void:
	var unused_cs = $Left/CharaStatuses.get_children()
	for chara in CombatPuppeteer.player_party:
		var cs = null
		for _cs in $Left/CharaStatuses.get_children():
			if _cs.chara == chara:
				_cs.queue_redraw()
				unused_cs.erase(_cs)
				_cs.show()
				cs = _cs
				break
		# duplicate if chara doesnt have charastatus
		if !NIU.iiv(cs):
			cs = $Left/CharaStatuses/CharaStatusDefault.duplicate()
			$Left/CharaStatuses.add_child(cs)
			cs.show()
			cs.chara = chara
			cs.name = "CS %s" % chara.rname
		# set color
		cs.change_to_font_color(cs.chara == _character)
	
	# hide unused
	for cs in unused_cs:
		cs.hide()
	
	$Left/CharaStatuses.queue_redraw()

# updates flee button. And remember: if FLEE ELEGIBLE, you are
func update_flee_eligibility():
	if can_flee_due_to_acting() and TurnPlayer.flee_possible():
		$Top/S/H/General/List/Flee.disabled = false
		$Top/S/H/General/List/Flee.text = "FLEE"
	else:
		$Top/S/H/General/List/Flee.disabled = true
		$Top/S/H/General/List/Flee.text = "Can't Flee!"

func update_act_eligibility():
	if can_act_due_to_fleeing():
		$Top/S/H/General/List/Act.disabled = false
		$Top/S/H/General/List/Act.text = "ACT"
	else:
		$Top/S/H/General/List/Act.disabled = true
		$Top/S/H/General/List/Act.text = "Can't Act!"

# true if, gameplay-wise, we can flee, false if not
func can_flee_due_to_acting():
	return TurnManager.player_can_flee_due_to_acting()

# true if, gameplay-wise, we can act (bc nobody's fleeing), false if not
func can_act_due_to_fleeing():
	return TurnManager.player_can_act_due_to_fleeing()

func on_turn_started():
	#breakpoint
	if _character == null and len(TurnPlayer.party):
		_character = TurnPlayer.party[0]
	# Skip if we have no characters
	# (may not be relevant later on - game over screen?)
	if !is_instance_valid(_character):
		visible = false
		return
	decision_step = DECISION_STEP.ACT_DEF_FLEE
	update_flee_eligibility()
	queue_redraw()
	await get_tree().process_frame
	select_character(_character)

func on_begin_action_processing():
	decision_step = DECISION_STEP.DONE
	queue_redraw()

func set_status(text: String, duration: float):
	showing_status = true
	$Top/Status.visible = true
	$Top/Status/P/Text.text = text
	print('STATUS: "%s" (%fs)' % [text, duration])
	$Top/Status/Timer.start(duration / TurnManager.battle_speed)
	if duration > 0.0:
		await $Top/Status/Timer.timeout
		hide_status()

func hide_status():
	$Top/Status.visible = false
	showing_status = false
	emit_signal("status_done_showing")

func give_number_shortcuts_to_act_def_flee():
	$Top/S/H/General/List/Act.shortcut.events[1].action = "ui_1"
	$Top/S/H/General/List/Defend.shortcut.events[1].action = "ui_2"
	$Top/S/H/General/List/Shift.shortcut.events[1].action = "ui_3"
	$Top/S/H/General/List/Flee.shortcut.events[1].action = "ui_4"
	for i in range(len(action_buttons)):
		action_buttons[i].shortcut.events = []
	for i in range(len(target_buttons)):
		target_buttons[i].shortcut.events = []
	

func give_number_shortcuts_to_actions():
	for i in range(4):
		$Top/S/H/General/List.get_child(i).shortcut.events[1].action = "none"
	for i in range(len(action_buttons)):
		action_buttons[i].shortcut.events = InputMap.action_get_events("ui_" + str(i + 1))
	for i in range(len(target_buttons)):
		target_buttons[i].shortcut.events = []
	

func give_number_shortcuts_to_targets():
	for i in range(4):
		$Top/S/H/General/List.get_child(i).shortcut.events[1].action = "none"
	for i in range(len(action_buttons)):
		action_buttons[i].shortcut.events = []
	for i in range(len(target_buttons)):
		target_buttons[i].shortcut.events = InputMap.action_get_events("ui_" + str(i + 1))

# call BEFORE the decision step is changed
func return_focus_to_previous_step(straight_to_act = false):
	# move focus to ACT if a target or action was focused
	var focus = get_viewport().gui_get_focus_owner()
	if !NIU.iiv(focus):
		$Top/S/H/General/List/Act.grab_focus()
	elif !straight_to_act and decision_step == DECISION_STEP.TARGET and (
	focus.get_parent() == $Top/S/H/Targets/List):
		action_button_pushed.grab_focus()
	elif (straight_to_act or focus.get_parent() == $Top/S/H/Actions/List):
		$Top/S/H/General/List/Act.grab_focus()

func _process(_delta: float) -> void:
	$Top/S.scroll_horizontal = 100000.0



## BUTTON PRESSES!!!!!!!!!!!!!

# when the player presses a ACT/DEFEND/FLEE button
func _on_Act_pressed() -> void:
	if TurnManager.actions_processing: return
	# toggle action view
#	if decision_step == DECISION_STEP.ACTIONS:
#		decision_step = DECISION_STEP.ACT_DEF_FLEE
#		set_description(null)
#		queue_redraw()
#	else:
	decision_step = DECISION_STEP.ACTIONS
	SoundOp.play_UI_Normal()
	give_number_shortcuts_to_actions()
	$Top/S/H/Actions/List.get_child(0).focus_mode = FOCUS_ALL
	$Top/S/H/Actions/List.get_child(0).grab_focus()

func _on_Defend_pressed() -> void:
	if TurnManager.actions_processing: return
	$Top/S/H/General/List/Defend.action = _character.get_node("Defend")
	_character.select_action(
		_character.get_node("Defend"), [_character], true)
	SoundOp.play_UI_End()
	decision_step = DECISION_STEP.DONE
	queue_redraw()

func _on_Defend_focus_entered() -> void:
	$Top/S/H/General/List/Defend.action = _character.get_node("Defend")
	set_description($Top/S/H/General/List/Defend)

func _on_Defend_focus_exited() -> void:
	set_description(null)

func _on_Shift_pressed() -> void:
	$Top/S/H/General/List/Shift.action = _character.get_node("Shift")
	_on_ActionButton_pressed($Top/S/H/General/List/Shift)

func _on_Shift_focus_entered() -> void:
	$Top/S/H/General/List/Shift.action = _character.get_node("Shift")
	set_description($Top/S/H/General/List/Shift)

func _on_Shift_focus_exited() -> void:
	set_description(null)

func _on_Flee_pressed() -> void:
	if TurnManager.actions_processing: return
	_character.select_action(
		_character.get_node("Flee"), [_character], true)
	SoundOp.play_UI_End()

func _on_Flee_focus_entered() -> void:
	$Top/S/H/General/List/Flee.action = _character.get_node("Flee")
	set_description($Top/S/H/General/List/Flee)

func _on_Flee_focus_exited() -> void:
	set_description(null)

func _on_CancelAction_pressed() -> void:
	if TurnManager.actions_processing: return
	_character.select_action(null, [])
	turn_player.select_character(TurnPlayer.party.find(_character))

func _on_ActionButton_pressed(button) -> void:
	if TurnManager.actions_processing: return
	$Top/S/H/Targets.scroll_vertical = 0.0
	action = button.action
	action_button_pushed = button
	set_description(button)
	# skip targeting if it's selftarget
	if action.skip_targeting or ((len(action.possible_initial_targets()) == 1 or
	(action.multi_autotarget and 
	len(action.possible_initial_targets()) == action.max_targets))):
		targets_so_far = [action.possible_initial_targets()[0]]
	if (action.target_self and !action.target_friendlies
	and !action.target_enemies):
		targets_so_far = [_character]
		if action.multi_autotarget:
			targets_so_far += action._auto_targets(targets_so_far)
	if len(targets_so_far) > 0:
		_character.select_action(action,targets_so_far)
		decision_step = DECISION_STEP.DONE
		queue_redraw()
		SoundOp.play_UI_End()
		return
	targets_so_far.clear()
	update_targets_buttons_array()
	if !action.name == "Shift":
		decision_step = DECISION_STEP.TARGET
	else:
		decision_step = DECISION_STEP.SHIFT
	$Top/S/H/Targets/List.get_child(0).focus_mode = FOCUS_ALL
	$Top/S/H/Targets/List.get_child(0).grab_focus()
	queue_redraw()
	SoundOp.play_UI_Normal()

func _on_ActionButton_focus_exited(_button) -> void:
	set_description(null)

func _on_ActionButton_focus_entered(button) -> void:
	set_description(button)

# returns the resource index's name given the pluralness of it.
func res_name(index, count):
	return RESOURCE_NAMES[index] if (count != 1 
	and count != -1) else RESOURCE_SINGLE_NAMES[index]

var current_action_button = null
func set_description(button):
	# if we're targeting, change it back to our action
	if decision_step == DECISION_STEP.TARGET and !button and NIU.iiv(action_button_pushed):
		set_description(action_button_pushed)
		return
	# empty description if needed
	if button == null:
		current_action_button = null
		$Top/Description/Label.text = ""
		$Top/Description.hide()
		return
	$Top/Description.show()
	if current_action_button != button:
		$Top/Description.notification(NOTIFICATION_VISIBILITY_CHANGED)
	current_action_button = button
	var act = button.action
	
	$Top/Description/Label.text = "[right]" + action_description(act) + "[/right]"
	queue_redraw()

func action_description(act) -> String:
	if act.name in ["Defend","Flee","Shift"]:
		return "[b]Basic Skill[/b]\n" + act.get_desc(null)
	# COSTS
	# Cost: 60 Mana, 500 Brain Cells, 1 Watershed Moment
	var desc := "[b]Cost:[/b] "
	var cant_affords = _character.resources_action_exceeds(act)
	var end_color = false
	for i in range(len(act.costs)):
		if act.costs[i] > 0:
			if end_color: desc += ", [/color]"
			desc += "[color=#%s]" % [str(
				RESOURCE_COLORS[i].to_html(false))]
			if cant_affords.has(i): desc += "[b]"
			desc += "%d %s" % [act.costs[i], res_name(i,act.costs[i])]
			if cant_affords.has(i): desc += "![/b]"
			end_color = true
	desc += "[/color]" if end_color else "Nothing"
	desc += "\n"
	
	# NEGATIVE COSTS --- GRANTS
	# Grants: 35 Divine Favor, 111 Sweet Treats
	end_color = false
	for i in range(len(act.costs)):
		if act.costs[i] < 0:
			if !end_color: desc += "[b]Grants:[/b] "
			if end_color: desc += ", [/color]"
			desc += "[color=#%s]+" % [str(
				RESOURCE_COLORS[i].to_html(false))]
			if cant_affords.has(i): desc += "[b]"
			desc += "%d %s" % [-act.costs[i], res_name(i,act.costs[i])]
			if cant_affords.has(i): desc += "![/b]"
			end_color = true
	desc += "[/color]\n" if end_color else ""
	
	# POWER
	desc += "[color=#%s]%s Skill" % [
		ATTACK_TYPE_COLORS[act.attack_type].to_html(false),
		str(act.ATTACK_TYPE.keys()[act.attack_type]).capitalize()]
	# Physical Power: 50 >>>> 42 Damage    [OR]    Physical Skill
	var dmg_calc = int(act.preview_dmg())
	if dmg_calc > 0:
		desc += "\n[b][i]/// %s DMG ///[/i][/b]" % [dmg_calc]
	elif dmg_calc < 0:
		desc += "\n[b][i]/// %s HEALING ///[/i][/b]" % [(-dmg_calc)]
	desc += "[/color]"
	# Close Range // 95% Accuracy // Follow 2		[OR]	Targets Self
	if act.target_self and act.skip_targeting: desc += "\nTargets Self"
	else: desc += "\nClose Range" if act.close_range else "\nFar Range"
	if act.accuracy < 100: 
		desc += " // Accuracy: %d%%" % act.accuracy
	desc += "\n"
	
	# COOLDOWN
	# 3 turn cooldown
	if act.cooldown > 0:
		desc += "%d turn cooldown" % act.cooldown
		if act.cd_left > 0:
			desc += " (%d remaining)" % act.cd_left
		desc += "\n"
	
	# MULTIATTACK
	# Up to 3 targets
	if act.max_targets > 1:
		if !act.require_max_targets:
			desc += "Up to "
		desc += "%d targets" % act.max_targets
		# (>2 range after each)
		if (act.multi_target_consec_min_range > 0 and
		act.multi_target_consec_max_range < 0):
			desc += " (>" + str(act.multi_target_consec_min_range)
			desc += " range after each)\n"
		# (<4 range after each)
		elif (act.multi_target_consec_min_range <= 0 and
		act.multi_target_consec_max_range > 0):
			desc += " (<" + str(act.multi_target_consec_max_range)
			desc += " range after each)\n"
		# (2-4 range after each)
		elif (act.multi_target_consec_min_range > 0 and
		act.multi_target_consec_max_range > 0):
			desc += " (" + str(act.multi_target_consec_min_range)
			desc += "-" + str(act.multi_target_consec_max_range)
			desc += " range after each)\n"
		else:
			desc += "\n"
	
	# DESC
	# Shoots a cool projectile that kills instantly. We have 18 HP. Wow!
	# Need to format this.
	desc += act.get_desc(targ_highlighted)
	
	return desc

func _on_TargetButton_pressed(button) -> void:
	if TurnManager.actions_processing: return
	# quit targeting if it's the finish button
	if button == finish_targeting_button:
		_character.select_action(action,targets_so_far)
		decision_step = DECISION_STEP.DONE
		queue_redraw()
		return
	
	targets_so_far.append(button.target)
	# if we're not multitargeting or we're out of target slots, finish
	if (action.max_targets <= 1
	or action.multi_autotarget
	or len(targets_so_far) >= action.max_targets):
		if action.multi_autotarget:
			targets_so_far += action._auto_targets(targets_so_far)
		_character.select_action(action,targets_so_far,action.name == "Shift")
		decision_step = DECISION_STEP.DONE
	else:
		update_targets_buttons_array()
	queue_redraw()
	SoundOp.play_UI_End()

var targ_highlighted : TurnCharacter = null
func _on_TargetButton_focus_exited(_button) -> void:
	targ_highlighted = null
	set_description(current_action_button)

func _on_TargetButton_focus_entered(button) -> void:
	targ_highlighted = null if button.target == null else (
	button.target.get_chara())
	set_description(current_action_button)

func _on_NextCharacter_pressed() -> void:
	if TurnManager.actions_processing: return
	turn_player.select_next_character()
	SoundOp.play_UI_Normal()
	$Top/S/H/Actions.notification(NOTIFICATION_VISIBILITY_CHANGED)

func _on_PrevCharacter_pressed() -> void:
	if TurnManager.actions_processing: return
	turn_player.select_previous_character()
	SoundOp.play_UI_Normal()
	$Top/S/H/Actions.notification(NOTIFICATION_VISIBILITY_CHANGED)

func _on_EndTurn_pressed() -> void:
	if TurnManager.actions_processing: return
	# select these targets if we were in the middle of targeting
	if decision_step == DECISION_STEP.TARGET and len(targets_so_far):
		_character.select_action(action,targets_so_far)
	TurnManager.end_current_turn()
	SoundOp.play_UI_End()
	set_description(null)

func _on_Move_pressed() -> void:
	update_rooms_buttons_array()
	$R/C/H/G.visible = !$R/C/H/G.visible
	SoundOp.play_UI_Normal()

func _on_Heal_pressed() -> void:
	if Overworld.player_room.full_heal:
		Overworld.heal_player_party()
	else:
		_character.full_heal(true)
		queue_redraw()
	SoundOp.play_UI_End()

func _on_RoomButton_pressed(button) -> void:
	if TurnManager.actions_processing: return
	
	# Move to that cell
	TurnPlayer.set_destination_room(button.cell)
	TurnManager.end_current_turn()
	
	queue_redraw()
	SoundOp.play_UI_End()
	$R/C/H/G.visible = false

func _on_back_pressed():
	return_focus_to_previous_step()
	if decision_step == DECISION_STEP.TARGET:
		decision_step = DECISION_STEP.ACTIONS
		give_number_shortcuts_to_actions()
		targ_highlighted = null
		queue_redraw()
	elif decision_step == DECISION_STEP.ACTIONS or decision_step == DECISION_STEP.SHIFT:
		decision_step = DECISION_STEP.ACT_DEF_FLEE
		give_number_shortcuts_to_act_def_flee()
		set_description(null)
		queue_redraw()



func get_class_name(): return "CombatUI"
