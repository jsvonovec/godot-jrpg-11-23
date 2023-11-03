extends StatusEffect

class_name se_StatIncrease

var TICK = TICK_EVENT.TURN_START
enum stats {atk, def, hp, dr, spd, eva}

@export var stat: stats
@export var amount: int
@export var recurring = false
var total := 0

# Should be called by the action that causes this.
# Format: 
# status_effect = se_Status_Effect_Name.new(caster, affected,
# icon, duration)
func _init(_caster, _affected, _duration, type: int, _recurring: bool, 
_boost: int, _tick = -1):
	
	if _boost == 0:
		queue_free()
		return
	
	recurring = _recurring
	
	duration = _duration
	amount = _boost
	stacks = _boost
	is_buff = amount > 0
	TICK = TICK if _tick < 0 else _tick
	
	var _icon : Texture2D
	match type:
		stats.atk:
			_icon = load("res://Sprites/Emoji/twe_bicep.png")
		stats.def:
			_icon = load("res://Sprites/Emoji/twe_shield.png")
		stats.hp:
			_icon = load("res://Sprites/Emoji/twe_juicebox.png")
		stats.dr:
			_icon = load("res://Sprites/Emoji/twe_ghost.png")
		stats.spd:
			_icon = load("res://Sprites/Emoji/twe_comet.png")
		stats.eva:
			_icon = load("res://Sprites/Emoji/twe_wind.png")
	# one-time boost
	name = "Stat Changer"
	_finish_constructor(_caster, _affected, _icon, TICK, null)
	if !recurring:
		boost()

# To be overridden
func _duplicate(new_affected = null):
	if new_affected == null: new_affected = affected
	return get_script().new(caster, affected, duration, stat, recurring, 
		amount)

# override this in extending scripts
#func _apply_status_effect(_arg = null):
#	pass

# override this in extending scripts
func _tick_effect(_arg = null):
	if recurring:
		boost()

func boost():
	affected.se_stat_changes[stats.keys()[stat]] += amount
	if stat == stats.hp:
			affected.heal(amount, false)
	total += amount
	stacks = total

# override this in extending scripts
func _remove_status_effect(_arg = null):
	deboost()

func deboost():
	affected.se_stat_changes[stats.keys()[stat]] -= total
	if stat == stats.hp:
		affected.take_damage(total, null, 0, 1.0, 0.0)
	total = 0
	stacks = total
