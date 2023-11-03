extends Node3D


# Beats between floaty animaiton cycles
@export var period = 4.0
@export var t_offset = 0.0
@export var amplitude = 0.25
@export var height = 0.5
@export var size = 0.25
@export var icon_scale = 0.8
@export var stacks_font_size = 150
@export var extra_font_size = 80

var status_effect = null


var is_ready := false
func _ready() -> void:
	await get_tree().process_frame
	$Board.texture = $SubViewport.get_texture()
	is_ready = true

func _process(_delta: float) -> void:
	if !is_ready:
		return
	# set floating position
	$Board.position.y = get_float_height()
	$Board.pixel_size = size / max(max($Board.texture.get_size().x,
	$Board.texture.get_size().y), 1.0)
	$SubViewport/Texture2D.scale = Vector2(icon_scale, icon_scale)
#	$SubViewport/VBox/HBox/Stacks.add_theme_font_size_override("normal_font_size", stacks_font_size)
#	$SubViewport/VBox/HBox/Counter.add_theme_font_size_override("normal_font_size", stacks_font_size)
#	$SubViewport/VBox/ExtraInfo.add_theme_font_size_override("normal_font_size", extra_font_size)
	

func get_float_height() -> float:
	# get t
	var t = t_offset + (fmod(SoundOp.total_beat_count(), period)) / period
	return height + amplitude * sin(2.0 * PI * t)

func set_status_effect(se, _show = null, stacks = "", dur = "", 
info = ""):
	if NIU.iiv(get_parent()) and NIU.iiv(get_parent().get_parent()):
		get_parent().get_parent().circle_ses.erase(self)
	status_effect = se
	if !(_show is bool) or !_show:
		hide()
		queue_free()
		return
	# only smalls are visible
	if !se.big:
		stacks = "" if stacks is int and stacks <= 0 else stacks
		show()
		$SubViewport/Texture2D.texture = se.icon
		$SubViewport/VBox/HBox/Stacks.text = str(stacks)
		$SubViewport/VBox/HBox/Counter.text = "[right]%s[/right]" % dur
		$SubViewport/VBox/ExtraInfo.text = "[center]%s[/center]" % info
	else:
		hide()
	# update position
	if !NIU.iiv(get_parent()):
		se.affected.get_node("Puppet/Center/RCircle/SEs").add_child(self)
	get_parent().get_parent().circle_ses.append(self)
	

