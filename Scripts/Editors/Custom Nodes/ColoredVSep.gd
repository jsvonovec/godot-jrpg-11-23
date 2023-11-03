@tool
extends VSeparator

class_name ColoredVSep



func _draw() -> void:
	theme = NIU.find_theme(self)
	if (theme and theme.get_stylebox("separator", "VSeparator").get("color")
	!= theme.get_color("font_color", "Label")):
		theme.get_stylebox("separator", "VSeparator").set(
		"color", theme.get_color("font_color", "Label"))

