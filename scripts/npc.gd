extends CharacterBody2D
class_name NPC
signal finished_eating

@export var cash_scene: PackedScene
@export var coin_scene: PackedScene
@export var drop_delay := 1.5
@export var ramen_needed := 3
@export var move_speed := 100

# New exports for entry/exit behavior
@export var entry_offset := -100.0  # Starting y-offset above screen (adjust based on sprite size)
@export var exit_offset := 50.0     # Buffer below screen before queue_free()
@export var chair_keep_distance := 26.0  # Minimum radius kept from chair while above it

@onready var interaction_area = $InteractionArea
@onready var anim = $AnimatedSprite2D
@onready var speech_bubble: Control = null
@onready var body_collider: CollisionShape2D = $CollisionShape2D
var eating_player: AudioStreamPlayer2D = null

var leaving := false
var eating := false
var entering := false  # Flag for entering the screen
var moving_to_chair := false  # Flag for moving to a chair
var waiting_for_chair := false  # Flag for waiting when no chairs available
var seated := false  # Flag for when NPC is at a chair
var target_chair: Chair = null  # The chair this NPC is assigned to
var target_position: Vector2  # Where the NPC stops (chair position)
var wait_check_timer := 0.0  # Timer for checking chairs while waiting
const WAIT_CHECK_INTERVAL := 0.5  # Check for chairs every 0.5 seconds when waiting

# Detour state for obstacle avoidance during exit
var detouring := false
var detour_dir := Vector2.ZERO
var detour_time := 0.0
const DETOUR_DURATION := 0.6

# Randomized pathing
var path_points: Array[Vector2] = []
var path_index: int = 0

# Store how many ramens this NPC originally needed so payout can be calculated
var initial_ramen_needed: int = 0

# Random thank-you messages
const THANK_MESSAGES = [
	"Yum!", "Delicious!", "Arigatou!", "So tasty!", "Perfect!",
	"Thanks!", "Nice!", "Good stuff!", "Fresh!", "Lovely!",
	"Warm!", "Awesome!", "Fantastic!", "Great!", "Sugoi!",
	"Oishii!", "Ahh~", "Slurp!", "Best ever!", "Wow!",
	"Mmm!", "Cheers!", "Grateful!", "Nice meal!"
]

func _ready():
	if interaction_area:
		print("NPC has InteractionArea!")
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
	else:
		print("⚠️ NPC missing InteractionArea!")
	
	# Capture initial ramen requirement set by spawner
	if initial_ramen_needed == 0:
		initial_ramen_needed = ramen_needed
	
	# Find a free chair
	find_chair()

func _process(delta):
	_update_bubble_position()
	_update_draw_order()

	# Handle waiting for chair - check periodically for free chairs (not every frame)
	if waiting_for_chair:
		wait_check_timer += delta
		if wait_check_timer >= WAIT_CHECK_INTERVAL:
			wait_check_timer = 0.0
			find_chair()

func _physics_process(delta: float) -> void:
	# Handle entering movement (spawning from top)
	if entering:
		_move_towards(target_position, delta)
		if position.distance_to(target_position) < 5.0:
			entering = false
			# After entering, find a chair
			find_chair()

	# Handle moving to chair
	if moving_to_chair and target_chair and not seated:
		var chair_pos = target_chair.global_position
		# Steering rule:
		# - If NPC collider Y is above (less than) chair Y, keep a circular offset from the chair
		#   and target a point below the chair at 'chair_keep_distance'. Do not enter the radius.
		# - Once NPC collider Y is below (>=) chair Y, move straight to the chair and sit.
		var npc_col_global_y := global_position.y
		if body_collider:
			npc_col_global_y = (global_position + body_collider.position).y
		var chair_y: float = chair_pos.y
		if npc_col_global_y < chair_y:
			# Above the chair: keep distance and aim to the point directly below the chair on the circle
			var to_chair: Vector2 = chair_pos - global_position
			var dist: float = to_chair.length()
			# If too close to the chair while above it, first push out to the rim
			if dist < chair_keep_distance - 0.5:
				var away: Vector2 = -(to_chair / max(dist, 0.001))
				var rim_point: Vector2 = chair_pos + away * chair_keep_distance
				_move_towards(rim_point, delta)
			else:
				# Target a point directly below the chair at the keep distance
				var below_point: Vector2 = chair_pos + Vector2(0, chair_keep_distance)
				_move_towards(below_point, delta)
			# Clear any old randomized path so we fully follow this rule
			path_points.clear()
			path_index = 0
		else:
			# Now below the chair: go straight to the chair
			_move_towards(chair_pos, delta)
			if position.distance_to(chair_pos) < 6.0:
				position = chair_pos
				moving_to_chair = false
				seated = true
				if anim and anim.sprite_frames and anim.sprite_frames.has_animation("IDLE"):
					anim.play("IDLE")
				else:
					anim.stop()
				update_speech_bubble()
				print("NPC arrived at chair and is now seated")

	# Existing leaving movement
	if leaving:
		# Free the chair before leaving
		if target_chair:
			target_chair.free_chair()
			target_chair = null
		# Move downward using collisions; if blocked, detour sideways along obstacle
		if detouring:
			var motion_detour := detour_dir * move_speed * delta
			var detour_hit = move_and_collide(motion_detour)
			detour_time -= delta
			if detour_time <= 0.0 or detour_hit == null:
				detouring = false
		else:
			var desired_motion := Vector2(0, move_speed * delta)
			var hit = move_and_collide(desired_motion)
			if hit:
				var n: Vector2 = hit.get_normal()
				# Compute tangent to desired down direction along the obstacle
				var down := Vector2(0, 1)
				var tangent := (down - n * down.dot(n))
				if tangent.length() < 0.1:
					# Fallback: try moving sideways to the right
					tangent = Vector2(1, 0)
				else:
					tangent = tangent.normalized()
				detouring = true
				detour_dir = tangent
				detour_time = DETOUR_DURATION
		# Disappear when fully off-screen
		var screen_bottom = get_viewport_rect().size.y + exit_offset
		if position.y > screen_bottom:
			print("NPC fully left screen and is being removed.")
			if speech_bubble and is_instance_valid(speech_bubble):
				speech_bubble.queue_free()
			queue_free()

func _move_towards(target: Vector2, delta: float) -> void:
	var to := target - position
	var dist := to.length()
	if dist <= 0.0:
		return
	var dir := to / dist
	var motion := dir * move_speed * delta
	move_and_collide(motion)

func _update_draw_order() -> void:
	if not target_chair:
		return
	var npc_col_global_y := global_position.y
	if body_collider:
		npc_col_global_y = (global_position + body_collider.position).y
	var chair_y := target_chair.global_position.y
	if npc_col_global_y < chair_y:
		z_index = target_chair.z_index - 1
	else:
		z_index = target_chair.z_index + 1

func find_chair():
	# Get chair manager
	var game_node = get_tree().get_root().get_node("Game")
	if not game_node:
		print("ERROR: Game node not found!")
		return
	
	var chair_manager = game_node.get_node_or_null("ChairManager")
	if not chair_manager:
		print("WARNING: ChairManager not found! NPC will wait.")
		waiting_for_chair = true
		return
	
	var free_chair = chair_manager.get_free_chair()
	if free_chair and not free_chair.is_occupied:
		target_chair = free_chair
		target_position = free_chair.global_position
		moving_to_chair = true
		waiting_for_chair = false
		wait_check_timer = 0.0  # Reset wait timer
		path_points.clear()
		path_index = 0
		
		# Reserve the chair immediately
		free_chair.occupy(self)
		
		# Start walking animation
		if anim and anim.sprite_frames and anim.sprite_frames.has_animation("WALK_FRONT"):
			anim.play("WALK_FRONT")
		
		print("NPC found free chair at ", free_chair.global_position)
	else:
		# No free chairs, wait
		if not waiting_for_chair:
			# First time entering wait state
			waiting_for_chair = true
			moving_to_chair = false
			wait_check_timer = 0.0
			if anim and anim.sprite_frames and anim.sprite_frames.has_animation("IDLE"):
				anim.play("IDLE")
			print("No free chairs available, NPC waiting...")

func _on_body_entered(body):
	if leaving or eating or entering or not seated:  # Only interact when seated
		return
	if body is Player and body.has_ramen and ramen_needed > 0:
		print("Feeding NPC with ramen...")
		var ramen_given = 1  # Player can only give 1 ramen at a time
		body.give_ramen()
		ramen_needed -= ramen_given
		print("Player gave", ramen_given, "ramen. NPC still needs:", ramen_needed)
		
		# Update bubble
		update_speech_bubble()
		start_eating()
		if ramen_needed <= 0:
			await finished_eating
			await get_tree().create_timer(drop_delay).timeout
			show_thank_popup()
			drop_cash()
			drop_tip_coins()
			# Notify popularity manager that NPC was served
			var game_node = get_tree().get_root().get_node("Game")
			var popularity_manager = game_node.get_node_or_null("PopularityManager")
			if popularity_manager:
				popularity_manager.npc_served()
			start_leaving()

func start_entering():
	entering = true
	print("ENTER DEBUG | Starting enter | New Pos:", global_position, " | Target:", target_position)
	print("Distance:", global_position.distance_to(target_position))
	
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("WALK_FRONT"):
		anim.play("WALK_FRONT")
		anim.frame = 0  # Reset animation to first frame
		print("WALK_FRONT animation started!")
	else:
		print("ERROR: WALK_FRONT animation MISSING!")

func start_eating():
	eating = true
	if speech_bubble and is_instance_valid(speech_bubble):
		speech_bubble.visible = false
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("EAT"):
		anim.play("EAT")
	else:
		print("NPC: 'EAT' animation not found.")
	var eat_duration: float = _get_eat_duration()
	_play_eating_segment(eat_duration)
	await get_tree().create_timer(eat_duration).timeout
	eating = false
	print("NPC done eating.")
	if ramen_needed > 0:
		update_speech_bubble()
	else:
		if speech_bubble and is_instance_valid(speech_bubble):
			speech_bubble.queue_free()
		speech_bubble = null
	emit_signal("finished_eating")

func _get_eat_duration() -> float:
	# Fixed eating duration as requested
	return 5.0

func _ensure_eating_player() -> AudioStreamPlayer2D:
	if eating_player and is_instance_valid(eating_player):
		return eating_player
	eating_player = AudioStreamPlayer2D.new()
	eating_player.name = "EatingPlayer"
	eating_player.bus = "Master"
	add_child(eating_player)
	var stream: AudioStream = load("res://assets/sounds/eating.mp3")
	eating_player.stream = stream
	return eating_player

func _play_eating_segment(duration: float) -> void:
	var player := _ensure_eating_player()
	if not player.stream:
		return
	var length := 0.0
	if "get_length" in player.stream:
		length = player.stream.get_length()
	if length <= 0.0:
		length = max(2.0, duration + 0.1) # fallback if length is unknown
	var start_offset := randf_range(0.0, max(0.0, length - duration))
	player.play(start_offset)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.stop()
	)

func drop_cash():
	if cash_scene:
		# Drop one cash per ramen served; each cash's value is defined by HUD price
		var drops: int = max(1, initial_ramen_needed)
		for i in range(drops):
			var cash = cash_scene.instantiate()
			cash.position = _random_drop_position_away_from_chair()
			get_parent().add_child(cash)
			print("Cash dropped at:", cash.position)

func drop_tip_coins():
	if coin_scene:
		var tip_count: int = randi_range(0, 3)
		if tip_count > 0:
			for i in range(tip_count):
				var coin = coin_scene.instantiate()
				coin.position = _random_drop_position_away_from_chair()
				get_parent().add_child(coin)
			show_tip_popup()

# === Randomized waypoint path builder ===
func _build_random_path_to(dest: Vector2) -> void:
	path_points.clear()
	var start: Vector2 = position
	var to_dest: Vector2 = dest - start
	var dist_total: float = to_dest.length()
	if dist_total < 1.0:
		path_points.append(dest)
		return
	var dir: Vector2 = to_dest / dist_total
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var hops: int = randi_range(1, 3)
	var last_t: float = 0.0
	for i in range(hops):
		var t: float = clamp(randf_range(last_t + 0.2, min(0.85, last_t + 0.5)), 0.2, 0.9)
		last_t = t
		var along: Vector2 = start + dir * (dist_total * t)
		var side: float = (-1.0) if randf() < 0.5 else 1.0
		var side_offset: Vector2 = perp * side * randf_range(20.0, 50.0)
		var jitter: Vector2 = Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 12.0))
		path_points.append(along + side_offset + jitter)
	# Always end at destination
	path_points.append(dest)

func _random_drop_position_away_from_chair() -> Vector2:
	var base := global_position
	if target_chair:
		var center := target_chair.global_position
		var min_dist := 24.0  # keep drops outside chair area
		var angle := deg_to_rad(randf_range(200.0, 340.0))  # prefer below/front of chair
		var dist := randf_range(min_dist, min_dist + 30.0)
		base = center + Vector2(cos(angle), sin(angle)) * dist
	# small jitter so items don't perfectly overlap
	return base + Vector2(randi_range(-6, 6), randi_range(-3, 3))

func show_thank_popup():
	var message = THANK_MESSAGES.pick_random()
	var panel = _create_speech_panel(message, Vector2(150, 32))
	var screen_pos = get_viewport_transform() * global_position
	panel.position = screen_pos + Vector2(-50, -60)
	get_tree().get_root().get_node("Game/HUD").add_child(panel)
	var tween = create_tween()
	tween.tween_property(panel, "position:y", panel.position.y - 35, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): panel.queue_free())

func show_tip_popup():
	var panel = _create_speech_panel("Customer just tipped you!", Vector2(320, 32))
	var hud = get_tree().get_root().get_node("Game/HUD")
	hud.add_child(panel)
	var screen_size: Vector2 = get_viewport_rect().size
	var margin: Vector2 = Vector2(16, 16)
	panel.position = Vector2(screen_size.x - margin.x - panel.size.x, screen_size.y - margin.y - panel.size.y)
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(panel, "position:y", panel.position.y - 35, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): panel.queue_free())

func start_leaving():
	leaving = true
	seated = false
	moving_to_chair = false
	waiting_for_chair = false
	
	if speech_bubble and is_instance_valid(speech_bubble):
		speech_bubble.queue_free()
	speech_bubble = null
	
	# Free the chair
	if target_chair:
		target_chair.free_chair()
		target_chair = null
	
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("WALK_FRONT"):
		anim.play("WALK_FRONT")
	print("NPC leaving the scene...")

# === REUSABLE: Create speech panel (used for both need & thank) ===
func _create_speech_panel(text: String, size: Vector2) -> Panel:
	var panel = Panel.new()
	panel.size = size
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	var font = load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	return panel

# === PERSISTENT NEED BUBBLE: X{ramen_needed} (same style, no fade) ===
func update_speech_bubble():
	if speech_bubble and is_instance_valid(speech_bubble):
		speech_bubble.queue_free()
	speech_bubble = null
	# Only show bubble when seated and needs ramen
	if ramen_needed <= 0 or not seated:
		return
	speech_bubble = _create_speech_panel("X" + str(ramen_needed), Vector2(60, 32))
	get_tree().get_root().get_node("Game/HUD").add_child(speech_bubble)
	_update_bubble_position()

func _update_bubble_position():
	if not speech_bubble or not is_instance_valid(speech_bubble):
		return
	var screen_pos = get_viewport_transform() * global_position
	speech_bubble.position = screen_pos + Vector2(-30, -70)  # Centered above head
