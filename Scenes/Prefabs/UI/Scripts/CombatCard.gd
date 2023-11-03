extends Control

# The character this card is for.
var _character


func attach_character(chara):
	# unsub from previous character
	if _character != null:
		_character.disconnect("update_ui_now", Callable(self, "update_card_ui"))
	
	_character = chara
	_character.connect("update_ui_now", Callable(self, "update_card_ui"))
	update_card_ui()

# update our ui
func update_card_ui():
	if _character == null:
		visible = false
		return
	
	visible = true
	$NamePanel/Name.text = _character.name
	$NamePanel/Level.text = "Lv " + str(_character.level)
	$HealthBar.max_value = _character.max_hp
	$HealthBar.value = _character.hp
	if _character.selected_action != null:
		$ActionPanel.visible = true
		$ActionPanel/Action.text = _character.selected_action.name
	else:
		$ActionPanel.visible = false
	

# boolean get function for _character.
func character_is(other):
	return _character == other

