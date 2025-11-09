extends CharacterBody2D
class_name NPC

@export var coin_scene: PackedScene
@export var drop_delay := 1.5
@export var ramen_needed := 3     # how many ramen bowls this NPC wants
@export var move_speed := 60      # speed when leaving the screen

@onready var interaction_area = $InteractionArea
@onready var anim = $AnimatedSprite2D

var leaving := false
var eating := false

# 🎉 Random thank-you messages
const THANK_MESSAGES = [
	"Yum!",
	"Delicious!",
	"Arigatou!",
	"So tasty!",
	"Perfect!",
	"Thanks!",
	"Nice!",
	"Good stuff!",
	"Fresh!",
	"Lovely!",
	"Warm!",
	"Awesome!",
	"Fantastic!",
	"Great!",
	"Sugoi!",
	"Oishii!",
	"Ahh~",
	"Slurp!",
	"Best ever!",
	"Wow!",
	"Mmm!",
	"Cheers!",
	"Grateful!",
	"Nice meal!"
]

func _ready():
	if interaction_area:
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
	YSorter.apply(self)

func _process(delta):
	YSorter.apply(self)
	if leaving:
		position.y += move_speed * delta  # Move down off-screen

func _on_body_entered(body):
	if leaving or eating:
		return
	if body is Player and body.ramen_count > 0 and ramen_needed > 0:
		print("Feeding NPC with ramen...")

		# 🍜 Calculate ramen exchange
		var ramen_given = min(body.ramen_count, ramen_needed)

		# 🧾 Update both NPC and Player
		body.give_ramen()  # player always gives all ramen (max 1)
		ramen_needed -= ramen_given

		print("Player gave", ramen_given, "ramen. NPC still needs:", ramen_needed)

		if body.hud:
			body.hud.update_ramen(body.total_ramen)

		# 🎬 Play eating phase
		start_eating()

		# ✅ Fully satisfied
		if ramen_needed <= 0:
			print("NPC satisfied! Dropping coin soon...")
			await get_tree().create_timer(drop_delay).timeout
			show_thank_popup()
			drop_coin()
			start_leaving()

func start_eating():
	eating = true
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("EAT"):
		anim.play("EAT")
	else:
		print("NPC: 'EAT' animation not found.")
	await get_tree().create_timer(1.2).timeout  # Duration of eating
	eating = false
	print("NPC done eating.")

func drop_coin():
	if coin_scene:
		var coin = coin_scene.instantiate()
		# Slight random offset so it doesn’t overlap with NPC
		coin.position = global_position + Vector2(randi_range(-40, 40), randi_range(10, 20))
		get_parent().add_child(coin)
		print("Coin dropped at:", coin.position)

func show_thank_popup():
	# 🎲 Random thank message
	var message = THANK_MESSAGES.pick_random()

	# === PANEL (Speech Box) ===
	var panel = Panel.new()
	panel.size = Vector2(150, 32)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	# === LABEL ===
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = panel.size

	var font = load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

	# === POSITION ABOVE NPC ===
	var screen_pos = get_viewport_transform() * global_position
	panel.position = screen_pos + Vector2(-50, -60)  # 👆 above NPC
	get_tree().get_root().get_node("Game/HUD").add_child(panel)

	# === FLOAT & FADE ===
	var tween = create_tween()
	tween.tween_property(panel, "position:y", panel.position.y - 35, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		panel.queue_free()
	)

func start_leaving():
	leaving = true
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("WALK_FRONT"):
		anim.play("WALK_FRONT")
	print("NPC leaving the scene...")
