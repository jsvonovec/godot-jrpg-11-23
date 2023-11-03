extends Node3D

class_name CharacterPlaceholder

@export var possible_character_paths := []
@export var on_players_team: bool
@export var allow_dupes = true
@export var min_charas = 1
@export var max_charas = 1
var already_loaded_chars := []
var cell : get = get_cell
func get_cell() -> Node:
	return get_parent()


func spawn_characters() -> Array:
	var newcharas := []
	# spawn an amount of characters
	for i in range(round(randf_range(min_charas, max_charas))):
		if len(possible_character_paths) == 0:
			break
		# Grab a random one
		var j = randi() % len(possible_character_paths)
		# Load the scene
		var loaded : PackedScene = load(possible_character_paths[j])
		# Instance the scene
		var chara : TurnCharacter = loaded.instantiate()
		# On same team and assign pos
		chara.default_on_players_team = on_players_team
		newcharas.append(chara)
		# Disallow dupes
		if !allow_dupes:
			possible_character_paths.remove_at(j)
		# make it not move into the room
		chara.switching_rooms = false
		
		self.cell.call_deferred("add_character", chara, i, false)
	
	self.cell.fix_positions()
	queue_free()
	
	return newcharas


