extends CanvasLayer

var placing: bool = false
var ghost: Node2D = null
var ghost_scene_path: String = ""
var _left_was_down: bool = false
var _relocate_original_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	var menu := $ShopMenu if has_node("ShopMenu") else null
	if menu:
		menu.connect("buy_item", Callable(self, "_on_buy_item"))
	# Also wire the Shop button here to open the menu (defensive)
	var btn := $ShopButton if has_node("ShopButton") else null
	if btn and menu:
		btn.pressed.connect(func(): menu.visible = true)

func _process(_delta: float) -> void:
	if placing and ghost:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var xform: Transform2D = get_viewport().get_canvas_transform()
		var world_pos: Vector2 = xform.affine_inverse() * mouse_pos
		ghost.global_position = world_pos
		# Validate placement (no overlap) and tint ghost accordingly
		var ok := _is_valid_placement(ghost)
		if ghost is CanvasItem:
			var ci := ghost as CanvasItem
			if ok:
				ci.modulate = Color(1, 1, 1, 0.5)
			else:
				ci.modulate = Color(1, 0.4, 0.4, 0.5)
		# Edge-detect left click to finalize placement even if events are consumed elsewhere
		var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if left_down and not _left_was_down:
			if ghost and _is_valid_placement(ghost):
				_finalize_placement(ghost)
			_left_was_down = false
			print("PLACEMENT FINALIZED via _process for:", ghost_scene_path)
			get_viewport().set_input_as_handled()
		_left_was_down = left_down

func _unhandled_input(event: InputEvent) -> void:
	if placing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ghost and _is_valid_placement(ghost):
			_finalize_placement(ghost)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if placing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ghost and _is_valid_placement(ghost):
			_finalize_placement(ghost)
		get_viewport().set_input_as_handled()
	elif placing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Cancel placement on right-click.
		# For new shop purchases (ghost_scene_path != ""), delete the ghost.
		# For relocations (ghost_scene_path == ""), keep the original node and
		# just restore its normal state.
		if ghost:
			if ghost_scene_path != "":
				ghost.queue_free()
			else:
				# Relocation cancel: snap back to original position before placement
				if _relocate_original_pos != Vector2.ZERO:
					ghost.global_position = _relocate_original_pos
				if ghost is CanvasItem:
					# Fully reset color so any red invalid-placement tint is cleared
					(ghost as CanvasItem).modulate = Color(1, 1, 1, 1)
				if "set_ghost_state" in ghost:
					ghost.set_ghost_state(false)
		placing = false
		ghost = null
		_relocate_original_pos = Vector2.ZERO
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()

func _post_place_register(node: Node2D) -> void:
	var game := get_tree().get_root().get_node("Game")
	if not game:
		return
	var mgr := game.get_node_or_null("ChairManager")
	if mgr and node is Chair:
		mgr.register_chair(node as Chair)
		if "find_all_chairs" in mgr:
			mgr.find_all_chairs()
		for child in game.get_children():
			if child is NPC:
				if "find_chair" in child:
					child.find_chair()
		get_viewport().set_input_as_handled()

func _finalize_placement(node: Node2D) -> void:
	var game := get_tree().get_root().get_node("Game")
	if not game:
		return
	# If this placement came from the shop, deduct cash now (only after confirming final position)
	if ghost_scene_path != "":
		var player := game.get_node_or_null("Player")
		if player and player is Player:
			var price := _get_price_for_scene(ghost_scene_path)
			if price > 0:
				if "spend_cash" in player:
					if not player.spend_cash(price):
						_show_no_cash_popup("NOT ENOUGH CASH!")
						# Remove the ghost, do not finalize placement
						node.queue_free()
						placing = false
						ghost = null
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
						return
					elif "show_cash_popup" in player:
						player.show_cash_popup(price, false)
				else:
					if "cash" in player and player.cash < price:
						_show_no_cash_popup("NOT ENOUGH CASH!")
						node.queue_free()
						placing = false
						ghost = null
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
						return
	# Make opaque
	if node is CanvasItem:
		(node as CanvasItem).modulate.a = 1.0
	# If this node supports a ghost/placement state (like ramen maker), disable it now
	if "set_ghost_state" in node:
		node.set_ghost_state(false)
	# Defer registration and notifications to ensure the node is fully in tree
	call_deferred("_post_place_register", node)
	# End placement
	placing = false
	ghost = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _get_placement_radius(node: Node2D) -> float:
	# Prefer a dedicated PlacementShape child (CircleShape2D) if present
	var placement_shape := node.get_node_or_null("PlacementShape")
	if placement_shape and placement_shape is CollisionShape2D:
		var shape = (placement_shape as CollisionShape2D).shape
		if shape is CircleShape2D:
			return (shape as CircleShape2D).radius
	# Fallback: use script-defined placement_radius if available
	if "placement_radius" in node:
		return float(node.placement_radius)
	# Last-resort defaults
	if node is Chair:
		return 24.0
	if node.get_script() and str(node.get_script()).find("ramen_maker") != -1:
		return 28.0
	return 24.0

func _get_placement_aabb(node: Node2D) -> Rect2:
	# Build a world-space axis-aligned bounding box from the PlacementShape.
	var placement_shape := node.get_node_or_null("PlacementShape")
	if placement_shape and placement_shape is CollisionShape2D:
		var cs := placement_shape as CollisionShape2D
		var shape := cs.shape
		var center: Vector2 = cs.global_position
		if shape is RectangleShape2D:
			var rect_shape := shape as RectangleShape2D
			var half := rect_shape.size * cs.global_scale.abs() * 0.5
			return Rect2(center - half, half * 2.0)
		elif shape is CircleShape2D:
			var r: float = (shape as CircleShape2D).radius * max(abs(cs.global_scale.x), abs(cs.global_scale.y))
			var half_r := Vector2(r, r)
			return Rect2(center - half_r, half_r * 2.0)
	# Fallback: approximate using a circle around the node
	var r_fallback := _get_placement_radius(node)
	var half_fb := Vector2(r_fallback, r_fallback)
	return Rect2(node.global_position - half_fb, half_fb * 2.0)

func _is_valid_placement(node: Node2D) -> bool:
	var game := get_tree().get_root().get_node("Game")
	if not game:
		return true
	var aabb_self := _get_placement_aabb(node)
	for child in game.get_children():
		if child == node:
			continue
		if not (child is Chair or (child is Area2D and "placement_radius" in child)):
			continue
		var other := child as Node2D
		if not other:
			continue
		var aabb_other := _get_placement_aabb(other)
		if aabb_self.intersects(aabb_other):
			return false
	return true

func start_relocate_existing(node: Node2D) -> void:
	if not node:
		return
	var game := get_tree().get_root().get_node("Game")
	if not game:
		return
	# Remember original position so we can restore it if relocation is cancelled
	_relocate_original_pos = node.global_position
	if node.get_parent() != game:
		node.get_parent().remove_child(node)
		game.add_child(node)
	if node is CanvasItem:
		(node as CanvasItem).modulate.a = 0.5
	# Mark as ghost so it ignores collisions while being positioned
	if "set_ghost_state" in node:
		node.set_ghost_state(true)
	ghost = node
	placing = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	ghost_scene_path = ""
	_left_was_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _get_price_for_scene(scene_path: String) -> int:
	match scene_path:
		"res://scenes/chair.tscn":
			return 1000
		"res://scenes/ramen_maker.tscn":
			return 2000
		_:
			return 0

func _on_buy_item(scene_path: String) -> void:
	var game := get_tree().get_root().get_node("Game")
	if not game:
		return
	var player := game.get_node_or_null("Player")
	if not player or not (player is Player):
		return
	# Determine price based on item
	var price := _get_price_for_scene(scene_path)
	if price > 0:
		# Check if player can afford it (but do NOT deduct yet)
		if "cash" in player and player.cash < price:
			_show_no_cash_popup("NOT ENOUGH CASH!")
			return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return
	var inst_node := scene.instantiate()
	if inst_node == null:
		return
	var inst: Node2D = inst_node as Node2D
	if inst == null:
		return
	# Semi-transparent preview while placing
	if inst is CanvasItem:
		(inst as CanvasItem).modulate.a = 0.5
	# If this is a ramen maker (or similar), mark as ghost during placement
	if "set_ghost_state" in inst:
		inst.set_ghost_state(true)
	game.add_child(inst)
	ghost = inst
	placing = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	ghost_scene_path = scene_path
	_left_was_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	print("PLACEMENT START:", ghost_scene_path)
	# Hide the menu after a successful purchase
	var menu := $ShopMenu if has_node("ShopMenu") else null
	if menu:
		menu.visible = false

func _show_no_cash_popup(text: String) -> void:
	var menu := $ShopMenu if has_node("ShopMenu") else null
	if menu and "show_error" in menu:
		menu.show_error(text)
