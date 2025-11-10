extends CharacterBody2D
class_name Player

const SPEED = 130.0
const MAX_ENERGY = 1000

@onready var anim = $AnimatedSprite2D
@onready var hud = get_tree().get_root().get_node("Game/HUD")
@onready var energy_label = hud.get_node("EnergyLabel")

var has_ramen := false  # whether the player is carrying ramen (max 1)

var last_direction := "front"
var coins := 0
var energy := MAX_ENERGY
var steps := 0
var idle_timer := 0.0

# === COOLDOWN SYSTEM ===
var energy_popup_cooldown := 0.0
const ENERGY_POPUP_COOLDOWN_TIME := 1.0

func _process(delta):
	YSorter.apply(self)

func _ready():
	hud.update_coins(coins)
	update_energy_label()

# --- Coin collection ---
func collect_coin():
	var incr := 50
	if hud and hud.has_method("get_coin_value"):
		incr = hud.get_coin_value()
	coins += incr
	hud.update_coins(coins)
	show_coin_popup(incr)

# --- Update HUD energy ---
func update_energy_label():
	energy_label.text = "ENERGY: %d" % energy

# --- PICKUP ramen ---
func pickup_ramen():
	if not has_ramen:
		has_ramen = true
		print("Picked up ramen! Carrying ramen.")
	else:
		print("Already carrying ramen!")

# --- Drop ramen when given to NPC ---
func give_ramen():
	if has_ramen:
		has_ramen = false
		print("Delivered ramen to NPC!")

# --- NO ENERGY popup ---
func show_energy_exhausted_popup():
	if energy_popup_cooldown > 0:
		return
	energy_popup_cooldown = ENERGY_POPUP_COOLDOWN_TIME

	var panel = Panel.new()
	panel.size = Vector2(140, 36)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "NO ENERGY!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = panel.size
	var font = load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 15)
	else:
		label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

	var screen_pos = get_viewport_transform() * global_position
	panel.position = screen_pos + Vector2(-70, 25)
	hud.add_child(panel)

	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		panel.queue_free()
	)

# --- Coin popup ---
func show_coin_popup(amount: int):
	var popup = Label.new()
	popup.text = "+%d" % amount
	popup.modulate = Color.YELLOW
	popup.z_index = 100
	var font = load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if font:
		popup.add_theme_font_override("font", font)
		popup.add_theme_font_size_override("font_size", 28)
	else:
		popup.add_theme_font_size_override("font_size", 32)
	var screen_pos = get_viewport_transform() * global_position
	popup.position = screen_pos + Vector2(-25, -50)
	hud.add_child(popup)
	var tween = create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 45, 1.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): popup.queue_free())

# --- Main physics ---
func _physics_process(delta: float) -> void:
	var input_vector = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

	# === UPDATE COOLDOWN ===
	if energy_popup_cooldown > 0:
		energy_popup_cooldown = max(energy_popup_cooldown - delta, 0)

	# === Energy system ===
	if input_vector != Vector2.ZERO and energy > 0:
		idle_timer = 0
		steps += 1
		if steps >= 5:
			energy = max(energy - 2, 0)
			update_energy_label()
			steps = 0
	else:
		idle_timer += delta
		if idle_timer >= 2.0:
			energy = min(energy + 5, MAX_ENERGY)
			update_energy_label()
			idle_timer = 0

	# === Movement ===
	if energy > 0:
		velocity = input_vector * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# === Animation selection ===
	var ramen_suffix = ""
	if has_ramen:
		ramen_suffix = "_RAMEN"  # add ramen variant if carrying one

	if energy <= 0 and input_vector != Vector2.ZERO:
		if energy_popup_cooldown <= 0:
			show_energy_exhausted_popup()

		if abs(input_vector.x) > abs(input_vector.y):
			last_direction = "side"
			anim.flip_h = input_vector.x < 0
		elif input_vector.y < 0:
			last_direction = "back"
		else:
			last_direction = "front"

		anim.play("IDLE_%s%s" % [last_direction.to_upper(), ramen_suffix])

	elif input_vector == Vector2.ZERO:
		anim.play("IDLE_%s%s" % [last_direction.to_upper(), ramen_suffix])
	else:
		if abs(input_vector.x) > abs(input_vector.y):
			last_direction = "side"
			anim.play("WALK_%s%s" % [last_direction.to_upper(), ramen_suffix])
			anim.flip_h = input_vector.x < 0
		elif input_vector.y < 0:
			last_direction = "back"
			anim.play("WALK_%s%s" % [last_direction.to_upper(), ramen_suffix])
			anim.flip_h = false
		else:
			last_direction = "front"
			anim.play("WALK_%s%s" % [last_direction.to_upper(), ramen_suffix])
			anim.flip_h = false
