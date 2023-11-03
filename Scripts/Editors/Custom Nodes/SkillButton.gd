extends MarginContainer


class_name SkillButton

var action : Action
var is_secret := false
var is_active := false

func _draw() -> void:
	var center = position + (size / 2)
	size = Vector2(min(size.x, size.y),
	min(size.x, size.y))
	position = center - (size / 2)

func set_icon(texture: Texture2D):
	$TextureRect.texture = texture

func highlight():
	CharacterSheet.highlighted_button = self
	CharacterSheet.queue_redraw()

func unhighlight():
	if CharacterSheet.highlighted_button == self:
		CharacterSheet.highlighted_button = null
		CharacterSheet.queue_redraw()


func secret() -> void:
	$SkillButton.disabled = true
	$TextureRect.visible = false
	is_secret = true

func unsecret() -> void:
	$SkillButton.disabled = false
	$TextureRect.visible = true
	is_secret = false

func toggled(button_pressed: bool) -> void:
	if button_pressed: on()
	else: off()

func on():
	# This skill is locked and cannot be added:
	# in combat or too many slots
	if TurnManager.player_out_of_combat():
		is_active = true
		if CharacterSheet.chara.can_equip_action(action):
			if action.primary:
				CharacterSheet.chara.assign_primary_actions(
					CharacterSheet.chara.primary_actions + [action])
			else:
				CharacterSheet.chara.assign_secondary_actions(
					CharacterSheet.chara.secondary_actions + [action])
	CharacterSheet.queue_redraw()



func off():
	if TurnManager.player_out_of_combat():
		is_active = false
		if action.primary:
			var acts = CharacterSheet.chara.primary_actions.duplicate()
			acts.erase(action)
			CharacterSheet.chara.assign_primary_actions(acts)
		else:
			var acts = CharacterSheet.chara.secondary_actions.duplicate()
			acts.erase(action)
			CharacterSheet.chara.assign_secondary_actions(acts)
	CharacterSheet.queue_redraw()

func lock():
	$Locked.visible = true
	$SkillButton.disabled = true
	if is_active:
		$SelectedLocked.visible = true

func unlock():
	$Locked.visible = false
	$SelectedLocked.visible = false
