extends Area2D
class_name Chair

var is_occupied := false
var occupied_by: NPC = null
var is_being_dragged := false
var drag_offset := Vector2.ZERO

func _ready():
	# Connect body entered/exited to detect NPCs
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	# Enable input processing for mouse
	input_pickable = true

func _input(event):
	# Only allow dragging if not occupied
	if is_occupied:
		if is_being_dragged:
			is_being_dragged = false
		return
	
	# Check for mouse button press
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if mouse is clicking on this chair
				var mouse_pos = get_global_mouse_position()
				var collision_shape = $CollisionShape2D
				if collision_shape:
					var shape = collision_shape.shape as RectangleShape2D
					if shape:
						var half_size = shape.size / 2.0
						var local_mouse = to_local(mouse_pos)
						# Check if mouse is within chair bounds
						if abs(local_mouse.x) <= half_size.x and abs(local_mouse.y) <= half_size.y:
							# Start dragging
							is_being_dragged = true
							drag_offset = global_position - mouse_pos
							get_viewport().set_input_as_handled()
			else:
				# Stop dragging when mouse button released
				if is_being_dragged:
					is_being_dragged = false
	
	# Handle dragging motion
	if is_being_dragged and event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset
		get_viewport().set_input_as_handled()

func _process(delta):
	# Update position while dragging (backup method)
	if is_being_dragged and not is_occupied:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset
		
		# Stop dragging if mouse button released
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_being_dragged = false

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

