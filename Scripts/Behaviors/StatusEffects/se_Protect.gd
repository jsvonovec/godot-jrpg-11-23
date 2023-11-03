extends StatusEffect


class_name se_Protect

var bonus_phys_def
var bonus_mag_def
var ignore_range : bool

func _init(_caster, _affected, _icon, _duration, _phys_def, 
_mag_def, _ignore_range):
	duration = _duration
	bonus_phys_def = _phys_def
	bonus_mag_def = _mag_def
	ignore_range = _ignore_range
	is_buff = true
	only_on_screen = false
	name = "Protected"
	_finish_constructor(_caster, _affected, _icon, TICK_EVENT.TURN_END, null)

func connect_signals():
	# here, we find all enemies and subscribe to their before-acting
	# signals, and redirect them to targeting us
	for chara in affected.cell.gse():
		# connect their se_about_to_act if not already
		# (if they're dead, all signals are undone anyway)
		if !chara.is_connected("se_about_to_act", Callable(self, "_on_enemy_about_to_act")):
			chara.connect("se_about_to_act", Callable(self, "_on_enemy_about_to_act"))

func _tick_effect(_arg = null):
	connect_signals()

func _on_enemy_about_to_act(enemy):
	# Now, check if they're targeting our protection target,
	# and if we're in range (if applicable)
	var index = enemy.selected_targets.find(affected)
	if index != -1:
		# change target to us
		var newtargs = enemy.selected_targets.duplicate()
		newtargs[index] = caster
		enemy.change_targets(newtargs, false, false, false, ignore_range)
	
	# remove the signal
	enemy.disconnect("se_about_to_act", Callable(self, "_on_enemy_about_to_act"))

func _apply_status_effect(_arg = null):
	caster.def[0] += bonus_phys_def
	caster.def[1] += bonus_mag_def
	connect_signals()

func _remove_status_effect(_arg = null):
	caster.def[0] -= bonus_phys_def
	caster.def[1] -= bonus_mag_def

func _application_message() -> String:
	return "%s is Protected by %s!" % [affected.name, caster.name]



#_caster, _affected, _icon, _duration, _phys_def, 
#_mag_def, _ignore_range
# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, new_affected, icon, _time_left,
	bonus_phys_def, bonus_mag_def, ignore_range)
