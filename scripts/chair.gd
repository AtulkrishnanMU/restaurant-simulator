extends Area2D
class_name Chair

@export var placement_radius: float = 24.0

var is_occupied := false
var occupied_by: NPC = null
var is_being_dragged := false
var drag_offset := Vector2.ZERO

func _ready():
	# Connect body entered/exited to detect NPCs
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))
	# Enable input processing for mouse
	input_pickable = true
	# Self-register with ChairManager so NPCs can find this chair when placed at runtime
	var game = get_tree().get_root().get_node("Game")
	if game:
		var mgr = game.get_node_or_null("ChairManager")
		if mgr and "register_chair" in mgr:
			mgr.register_chair(self)
			# Also refresh scanning for safety
			if "find_all_chairs" in mgr:
				mgr.find_all_chairs()
	# Unregister when exiting tree (safe even if tree is already being freed)
	self.tree_exited.connect(func(node: Node):
		# 'node' is this Chair, but its tree may be null already; use cached manager pattern
		var g_tree := node.get_tree()
		if not g_tree:
			return
		var g_root := g_tree.get_root()
		if not g_root:
			return
		var game_node := g_root.get_node("Game")
		if not game_node:
			return
		var m = game_node.get_node_or_null("ChairManager")
		if m and "unregister_chair" in m:
			m.unregister_chair(node)
	)

func _input(event):
	# Legacy drag logic disabled in favor of UI-driven relocation.
	pass

func _process(_delta):
	pass

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# Use the same ghost-placement relocation as the ramen maker.
	# Do not allow moving while occupied by an NPC.
	if is_occupied:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var game := get_tree().get_root().get_node_or_null("Game")
		if not game:
			return
		var ui := game.get_node_or_null("UI")
		if ui and "start_relocate_existing" in ui:
			ui.start_relocate_existing(self)

func _on_body_entered(body):
	if body is NPC and not is_occupied:
		# Only occupy if the NPC is moving to this chair
		if body.target_chair == self:
			occupy(body)

func _on_body_exited(body):
	if body is NPC and occupied_by == body:
		free_chair()

func occupy(npc: NPC):
	if is_occupied:
		return
	is_occupied = true
	occupied_by = npc
	# Stop dragging if occupied
	is_being_dragged = false
	print("Chair at ", global_position, " is now occupied by NPC")

func free_chair():
	if not is_occupied:
		return
	print("Chair at ", global_position, " is now free")
	is_occupied = false
	occupied_by = null
