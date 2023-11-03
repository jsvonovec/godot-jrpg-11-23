extends Control

class_name ResourceBar

@export var hp_bar = false
@export var resource: int
@export var res_name: String
@export var text_color: Color
@export var bar_color: Color

var character
# the index of numbers/names/etc that this resource bar represents
var resource_number


func _ready():
	# hp
	if hp_bar:
		$Name.text = "HP"
		
	# resource
	else:
		$Name.text = str(res_name)
	
	$Bar.bar_color = bar_color
	$Bar.text_color = text_color
	$Name.set("theme_override_colors/font_color",text_color)
