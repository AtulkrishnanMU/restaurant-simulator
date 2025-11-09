extends Node

class_name YSorter

# Ensures the node stays above a minimum z-index (default -1)
static func apply(node: Node2D, min_z: int = -1) -> void:
	if node == null:
		return
	if not node is Node2D:
		push_warning("YSorter.apply() called on non-Node2D: %s" % node.name)
		return
	
	var new_z = int(node.global_position.y)
	node.z_index = max(min_z, new_z)
