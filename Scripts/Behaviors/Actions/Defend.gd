extends Action

@export var se_icon: Texture2D

var status_effect

func _use(_targets):
	_targets = [character]
	status_effect = se_Defending.new(character, character)

