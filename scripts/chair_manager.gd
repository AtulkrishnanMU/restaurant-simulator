extends Node2D
class_name ChairManager

var chairs: Array = []
var waiting_npcs: Array = []

func _ready():
	# Find all chairs in the scene
	find_all_chairs()
	var game_node = get_parent()
	if game_node:
		game_node.child_entered_tree.connect(_on_game_child_entered)
		game_node.child_exiting_tree.connect(_on_game_child_exiting)

func find_all_chairs():
	chairs.clear()
	var game_node = get_parent()  # ChairManager is a child of Game
	if game_node:
		for child in game_node.get_children():
			if child is Chair:
				chairs.append(child)
	print("Found ", chairs.size(), " chairs in the scene")

func register_chair(chair) -> void:
	if chair == null:
		return
	if chairs.has(chair):
		return
	chairs.append(chair)
	# Auto-unregister when removed from tree
	chair.tree_exited.connect(func(): unregister_chair(chair))
	print("Chair registered. Total:", chairs.size())

func unregister_chair(chair) -> void:
	if chair == null:
		return
	var idx := chairs.find(chair)
	if idx != -1:
		chairs.remove_at(idx)
		print("Chair unregistered. Total:", chairs.size())

func register_waiting_npc(npc: Node) -> void:
	if npc == null:
		return
	if waiting_npcs.has(npc):
		return
	waiting_npcs.append(npc)

func unregister_waiting_npc(npc: Node) -> void:
	if npc == null:
		return
	var idx := waiting_npcs.find(npc)
	if idx != -1:
		waiting_npcs.remove_at(idx)

func request_chair_for(npc: Node) -> Chair:
	# Ensure the NPC is tracked in the waiting queue
	if npc == null:
		return null
	if not waiting_npcs.has(npc):
		waiting_npcs.append(npc)
	# Only the NPC at the front of the queue may claim the next free chair
	if waiting_npcs.size() == 0 or waiting_npcs[0] != npc:
		return null
	var chair: Chair = get_free_chair()
	if chair:
		# Remove from queue when a chair is successfully assigned
		waiting_npcs.pop_front()
		return chair
	return null

func _on_game_child_entered(node: Node) -> void:
	if node is Chair:
		register_chair(node)

func _on_game_child_exiting(node: Node) -> void:
	if node is Chair:
		unregister_chair(node)

func get_free_chair():
	for chair in chairs:
		if not chair.is_occupied:
			return chair
	return null

func has_free_chair() -> bool:
	return get_free_chair() != null
