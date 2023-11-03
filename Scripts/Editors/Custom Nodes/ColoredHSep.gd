@tool
extends HSeparator

class_name ColoredHSep



func _draw() -> void:
	theme = NIU.find_theme(self)
	if (theme and theme.get_stylebox("separator", "HSeparator").get("color")
	!= theme.get_color("font_color", "Label")):
		theme.get_stylebox("separator", "HSeparator").set(
		"color", theme.get_color("font_color", "Label"))

