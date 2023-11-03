extends MarginContainer



func shrink_rect():
	size = custom_minimum_size
	position = -size

func _ready():
	shrink_rect()

func _on_MarginContainer_sort_children():
	shrink_rect()
