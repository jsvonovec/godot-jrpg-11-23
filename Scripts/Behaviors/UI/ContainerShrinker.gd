extends Container


func _on_List_sort_children() -> void:
	shrink_rect()

func shrink_rect():
	size = custom_minimum_size

func _ready():
	shrink_rect()
