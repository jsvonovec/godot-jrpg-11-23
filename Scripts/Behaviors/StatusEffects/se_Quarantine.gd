extends StatusEffect

class_name se_Quarantine

const TICK = TICK_EVENT.TURN_START
const ICON_PATH = "res://Sprites/Emoji/twe_biohazard.png"

func get_class_name() -> String:	return super.get_class_name()

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _duration):
	duration = _duration
	stacks = 0
	is_buff = false
	removable = true
	name = "Quarantine"
	var _icon = preload(ICON_PATH)
	_finish_constructor(_caster, _affected, _icon, TICK, null)

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, duration)


var connected = false
func _tick_effect(_arg = null):
	if ending: return
	if connected:
		disconnect_things()
	if !connected:
		connect_things()


func connect_things():
	affected.connect("custom_initial_target_rule_check",
	check_for_allowed_target_from_affected)
	var all_others = affected.cell.get_inhabitants().duplicate()
	all_others.erase(affected)
	for chara in all_others:
		chara.connect("custom_initial_target_rule_check",
		check_for_allowed_target_from_others)
		print("connected %s!" % chara.name)
	connected = true

func disconnect_things():
	affected.disconnect("custom_initial_target_rule_check",
	check_for_allowed_target_from_affected)
	var all_others = affected.cell.get_inhabitants().duplicate()
	all_others.erase(affected)
	for chara in all_others:
		chara.disconnect("custom_initial_target_rule_check",
		check_for_allowed_target_from_others)
		print("disconnected %s!" % chara.name)
	connected = false

func _apply_status_effect(_arg = null):
	connect_things()

func _remove_status_effect(_arg = null):
	disconnect_things()


# Do NOT allow them to target teammates.
func check_for_allowed_target_from_affected(_from, _query):
	var chara = _query.get_chara()
	_from.get_chara().custom_initial_target_rule_passed = !NIU.iiv(chara
	) or chara == affected.get_chara() or (
	chara.on_players_team != affected.on_players_team)

# Do NOT allow others to target affected.
func check_for_allowed_target_from_others(_from, _query):
	var chara = _query.get_chara()
	_from.get_chara().custom_initial_target_rule_passed = !NIU.iiv(chara
	) or chara != affected.get_chara() or (
	_from.on_players_team != affected.on_players_team)




# The The message for when it's applied. Override it!
func _application_message() -> String:
	return "%s is Quarantined!" % [affected.name]

# To be overridden. Updates the name of the SE
#func _get_name():
#	return name
