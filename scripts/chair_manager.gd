extends Node2D
class_name ChairManager

var chairs: Array[Chair] = []

func _ready():
	# Find all chairs in the scene
	find_all_chairs()

func find_all_chairs():
	chairs.clear()
	var game_node = get_parent()  # ChairManager is a child of Game
	if game_node:
		for child in game_node.get_children():
			if child is Chair:
				chairs.append(child)
	print("Found ", chairs.size(), " chairs in the scene")

func get_free_chair() -> Chair:
	for chair in chairs:
		if not chair.is_occupied:
			return chair
	return null

func has_free_chair() -> bool:
	return get_free_chair() != null

