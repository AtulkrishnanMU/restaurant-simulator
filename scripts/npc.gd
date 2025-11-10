extends CharacterBody2D
class_name NPC

@export var coin_scene: PackedScene
@export var drop_delay := 1.5
@export var ramen_needed := 3
@export var move_speed := 60

# New exports for entry/exit behavior
@export var entry_offset := -100.0  # Starting y-offset above screen (adjust based on sprite size)
@export var exit_offset := 50.0     # Buffer below screen before queue_free()

@onready var interaction_area = $InteractionArea
@onready var anim = $AnimatedSprite2D
@onready var speech_bubble: Control = null

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
	YSorter.apply(self)
	
	# Find a free chair
	find_chair()

func _process(delta):
	YSorter.apply(self)
	_update_bubble_position()
	
	# Handle waiting for chair - check periodically for free chairs (not every frame)
	if waiting_for_chair:
		wait_check_timer += delta
		if wait_check_timer >= WAIT_CHECK_INTERVAL:
			wait_check_timer = 0.0
			find_chair()
	
	# Handle entering movement (spawning from top)
	if entering:
		position = position.move_toward(target_position, move_speed * delta)
		if position.distance_to(target_position) < 5.0:
			entering = false
			# After entering, find a chair
			find_chair()
	
	# Handle moving to chair
	if moving_to_chair and target_chair and not seated:
		var chair_pos = target_chair.global_position
		position = position.move_toward(chair_pos, move_speed * delta)
		
		# Check if reached chair
		if position.distance_to(chair_pos) < 10.0:
			# Arrived at chair
			position = chair_pos
			moving_to_chair = false
			seated = true
			if anim and anim.sprite_frames and anim.sprite_frames.has_animation("IDLE"):
				anim.play("IDLE")
			else:
				anim.stop()
			# Now show ramen need
			update_speech_bubble()
			print("NPC arrived at chair and is now seated")
	
	# Existing leaving movement
	if leaving:
		# Free the chair before leaving
		if target_chair:
			target_chair.free_chair()
			target_chair = null
		
		position.y += move_speed * delta
		
		# Disappear when fully off-screen
		var screen_bottom = get_viewport_rect().size.y + exit_offset
		if position.y > screen_bottom:
			print("NPC fully left screen and is being removed.")
			if speech_bubble and is_instance_valid(speech_bubble):
				speech_bubble.queue_free()
			queue_free()

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
			await get_tree().create_timer(drop_delay).timeout
			show_thank_popup()
			drop_coin()
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
	await get_tree().create_timer(1.2).timeout
	eating = false
	print("NPC done eating.")
	if ramen_needed > 0:
		update_speech_bubble()
	else:
		if speech_bubble and is_instance_valid(speech_bubble):
			speech_bubble.queue_free()
		speech_bubble = null

func drop_coin():
	if coin_scene:
		var coin = coin_scene.instantiate()
		coin.position = global_position + Vector2(randi_range(-40, 40), randi_range(10, 20))
		get_parent().add_child(coin)
		print("Coin dropped at:", coin.position)

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
