extends Node
class_name SoundOpScript

signal new_beat

# MAKE SURE THE ARRAY OF LOADED SOUNDS IS THE SAME
# AS THE DIRECTORY PATH VARIABLE NAME, JUST LOWERCASE!!!!!
@export_dir var UI_Normal
var ui_normal := []
@export_dir var UI_End
var ui_end := []
@export_dir var BGM_Battle1
var bgm_battle1 := []
@export_dir var BGM_Calm1
var bgm_calm1 := []
@export_dir var HIT_Physical1
var hit_physical1 := []
@export_dir var HIT_Magical1
var hit_magical1 := []

const non_bgm_prefixes = ["UI", "HIT"]
enum SOUND_TYPE {UI_Normal, UI_End, BGM_Battle1,
BGM_Calm1, HIT_Physical1, HIT_Magical1, SE_Fire1}

var all_bgm := []
var combat_bgm_playing := false
var tempo := 110.0
var log_beats = false

func _ready() -> void:
	# Load all sound files. Goes through property list and loads
	# the files in that directory if it is a directory variable.
	var gpl = get_property_list()
	for p in gpl:
		var p_name = p.get("name")
		var is_bgm : bool = p_name.begins_with("BGM")
		var is_dir_var := is_bgm
		if !is_bgm:
			for nbgmp in non_bgm_prefixes:
				if p_name.begins_with(nbgmp):
					is_dir_var = true
					break
		if is_dir_var:
			load_sounds(p_name, is_bgm)
	
	play_BGM_Calm1()
	CombatPuppeteer.connect("done_with_anims", Callable(self, "_on_turn_start"))

func load_sounds(dir_path_var_name : String, music : bool) -> void:
	var path = get(dir_path_var_name)
	var array = get(dir_path_var_name.to_lower())
	for file in all_sound_files_in_directory(path):
		var r = load(file)
		array.append(r)
		if music:
			all_bgm.append(r)

# Returns a list of file paths in all children folders of this folder.
func all_sound_files_in_directory(path) -> Array:
	var results := []
	var dir := DirAccess.open(path)
	if !DirAccess.get_open_error():
		dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var filename = dir.get_next()
		while filename != "":
			if dir.current_is_dir() and filename != "." and filename != "..":
				results.append_array(all_sound_files_in_directory(path 
				+ "/" + filename))
			elif filename.ends_with(".mp3") or filename.ends_with(".wav"):
				results.append(path + "/" + filename)
			filename = dir.get_next()
	return results

func play_UI_Normal():
	play_sound(SOUND_TYPE.UI_Normal)
func play_UI_End():
	play_sound(SOUND_TYPE.UI_End)
func play_BGM_Battle1():
	play_sound(SOUND_TYPE.BGM_Battle1, "", true, true, true)
func play_BGM_Calm1():
	play_sound(SOUND_TYPE.BGM_Calm1, "", true, true, false)

func play_hit_sound(atk_type):
	match (atk_type):
		0:
			play_sound(SOUND_TYPE.HIT_Physical1)
			return
		1:
			play_sound(SOUND_TYPE.HIT_Magical1)
			return
	# TODO: Remove this when other sound effects are in
	play_sound(SOUND_TYPE.HIT_Physical1)
	return

func play_death_sound(players_team: bool):
	if players_team:
		# TODO: Replace this when other sound effects are in
		play_sound(SOUND_TYPE.HIT_Physical1)
	else:
		play_sound(SOUND_TYPE.HIT_Physical1)

const bgm_start_delay = 0.33
# THE FUNCTION TO USE BY OTHER SCRIPTS!
func play_sound(sound_type, bus_override := "", loop := false, bgm := false, 
battle_bgm := false) -> void:
	await get_tree().physics_frame
	var bgm_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency() + bgm_start_delay
	#print(bgm_delay)
	var sounds = get_sounds(sound_type)
	var bus = bus_override if bus_override != "" else get_bus(sound_type)
	if bgm:
		await get_tree().process_frame
		start_dance_timer()
		await get_tree().create_timer(bgm_delay).timeout
		$BGM.stop()
		$BGM.stream = sounds[randi() % len(sounds)]
		$BGM.play()
		combat_bgm_playing = battle_bgm
	elif loop:
		breakpoint
		# TODO: allow for looping sound that's not bgm :)
		pass
	else:
		play_sound_oneshot(sounds[randi() % len(sounds)], bus)

func get_sounds(sound_type) -> Array:
	return get(SOUND_TYPE.keys()[sound_type].to_lower())

func get_bus(sound_type) -> String:
	match(SOUND_TYPE.keys()[sound_type].split("_")[0]):
		"BGM":
			return "Music"
		"UI":
			return "UI"
		"HIT":
			return "Game"
	# error
	printerr("ERROR: One of the sound types doesn't have an associated bus?")
	return "Master"

# Plays music.
func _on_turn_start() -> void:
	# Battle music
	if !TurnManager.player_out_of_combat() and !combat_bgm_playing:
		# play a random battle tune
		play_BGM_Battle1()
	# Calm music
	elif TurnManager.player_out_of_combat() and combat_bgm_playing:
		play_BGM_Calm1()


# Plays the sound once, then destroys the node.
func play_sound_oneshot(sound: Resource, bus : String) -> void:
	var astream := AudioStreamPlayer.new()
	add_child(astream)
	astream.stream = sound
	astream.bus = bus
	astream.play()
	await astream.finished
	astream.queue_free()

var dance_timer_count := 0
var beat_count := 0
var dance_start := 0.0

func start_dance_timer():
	# increment dance timer count, so a previous one will end
	dance_timer_count += 1
	beat_count = 0
	dance_start = float(Time.get_ticks_msec()) / 1000.0
	# set tempo
	# TODO: get the tempo from the song somehow. A JSON or something? idk
	#tempo = 110.0
	# wait for song to actually start
	await get_tree().create_timer(AudioServer.get_time_to_next_mix() 
	+ AudioServer.get_output_latency()).timeout
	# now dance, baby!!!
	dance_timer()

var beat_start_time := 0.0

func dance_timer():
	var index = dance_timer_count
	var curr_time = 0.0
	# do NOT drop the beat if we're not the current timer
	while index == dance_timer_count:
		# new beat just dropped
		var prev_time = curr_time
		curr_time = NIU.ftime()
		if log_beats:
			print("beat %s! // length = %s" % [beat_count, curr_time - prev_time])
			if beat_count == tempo:
				print("TEMPO BEATS PASSED! // tot. length = %s" % [curr_time 
				- dance_start])
		beat_start_time = curr_time
		beat_count += 1
		emit_signal("new_beat", beat_count)
		# now wait until the next one
		await get_tree().create_timer(dance_start + 
		(beat_count * 60.0 / tempo) - curr_time).timeout

# returns a float from 0 to 1. 0 is beat just started, 1 is beat is ending.
func beat_progress() -> float:
	return (NIU.ftime() - beat_start_time) / (60.0 / tempo)

func total_beat_count() -> float:
	return float(beat_count) + beat_progress()

func wait_for_beats(amt: float) -> SceneTreeTimer:
	return get_tree().create_timer((amt * 60.0 / tempo))

func beat_dur(amt := 1.0):
	return amt * 60.0 / tempo
