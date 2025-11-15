extends Area2D

@export var cook_time_seconds: float = 5.0
@export var spawn_offset: Vector2 = Vector2(24, 0)
@export var ramen_scene: PackedScene = preload("res://scenes/ramen.tscn")

var _is_cooking: bool = false
var _cook_tween: Tween
@onready var cook_bar: Node2D = $CookBar
var _player_inside: bool = false
var _progress: float = 0.0
var _player: Player = null
var _spawn_unlocked_once: bool = false
var _cook_audio: AudioStreamPlayer = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if cook_bar:
		cook_bar.visible = false
		# Ensure bar starts empty
		if "value" in cook_bar:
			cook_bar.value = 0.0

func _on_body_entered(body: Node) -> void:
	if _is_cooking:
		# If already cooking, just mark overlap for resume
		if body is Player:
			_player_inside = true
			_player = body
		return
	if body is Player:
		_player_inside = true
		_player = body
		# Do not start cooking if player already has ramen
		if _player and _player.has_ramen:
			if cook_bar:
				cook_bar.visible = false
			return
		_start_cooking()

func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_inside = false
		if _player == body:
			_player = null

func _start_cooking():
	_is_cooking = true
	_progress = 0.0
	# Show progress bar
	if cook_bar:
		cook_bar.visible = true
		if "value" in cook_bar:
			cook_bar.value = 0.0
	_start_cooking_audio()

func _process(delta: float) -> void:
	if not _is_cooking:
		return
	if not _player_inside:
		# Pause audio when player leaves the maker
		if _cook_audio:
			_cook_audio.stream_paused = true
		return
	# Do not progress if player has ramen in hand
	if _player and _player.has_ramen:
		if _cook_audio:
			_cook_audio.stream_paused = true
		return
	# Accumulate only while player is touching
	# Ensure audio is playing while cooking progresses
	if _cook_audio:
		_cook_audio.stream_paused = false
	_progress += delta
	var pct: float = clamp(_progress / max(0.001, cook_time_seconds), 0.0, 1.0)
	if cook_bar and "value" in cook_bar:
		cook_bar.value = pct
	if _progress >= cook_time_seconds:
		_finish_cooking()

func _finish_cooking():
	_spawn_ramen()
	_is_cooking = false
	_progress = 0.0
	if cook_bar:
		cook_bar.visible = false
		if "value" in cook_bar:
			cook_bar.value = 0.0
	_stop_cooking_audio()
	# After the very first ramen is made, unlock NPC spawning and show message
	if not _spawn_unlocked_once:
		_spawn_unlocked_once = true
		_show_first_customer_popup()
		_enable_npc_spawning()

func _spawn_ramen():
	if not ramen_scene:
		return
	var ramen := ramen_scene.instantiate()
	if not ramen:
		return
	# Place ramen near the maker
	ramenglobal(ramen)

func ramenglobal(ramen: Node):
	# Helper to add ramen to the same parent and set position in global space
	var parent := get_parent()
	if not parent:
		parent = get_tree().current_scene
	if parent:
		parent.add_child(ramen)
		if ramen is Node2D:
			ramengpos(ramen)

func ramengpos(ramen: Node2D):
	ramen.global_position = global_position + spawn_offset

func _enable_npc_spawning() -> void:
	var game := get_tree().get_root().get_node("Game")
	if not game:
		return
	var spawner := game.get_node_or_null("NPCSpawner")
	if spawner and spawner.has_method("enable_spawning"):
		spawner.enable_spawning(2.0)

func _show_first_customer_popup():
	# Create a HUD popup similar to other popups
	var hud = get_tree().get_root().get_node("Game/HUD")
	if not hud:
		return
	var panel = Panel.new()
	panel.size = Vector2(400, 36)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "Wait for your first customer..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = panel.size
	var font = load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 15)
	else:
		label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

	# Position near player or center screen; use center-bottom
	var screen_size: Vector2 = get_viewport_rect().size
	panel.position = Vector2((screen_size.x - panel.size.x) * 0.5, screen_size.y - 80)
	hud.add_child(panel)

	var tween = create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): panel.queue_free())

func _start_cooking_audio():
	# Play a random segment of cooking.mp3 for the cook duration
	var path := "res://assets/sounds/cooking.mp3"
	if not ResourceLoader.exists(path):
		return
	_cook_audio = AudioStreamPlayer.new()
	var stream := load(path)
	if stream:
		_cook_audio.stream = stream
		_cook_audio.volume_db = -2.0
		# Compute random start so we have at least cook_time_seconds of audio remaining
		var total_len := 0.0
		if stream is AudioStream:
			total_len = (stream as AudioStream).get_length()
		var start_pos := 0.0
		if total_len > cook_time_seconds + 0.1:
			start_pos = randf_range(0.0, max(0.0, total_len - cook_time_seconds))
		add_child(_cook_audio)
		_cook_audio.play(start_pos)

func _stop_cooking_audio():
	if _cook_audio:
		_cook_audio.stop()
		_cook_audio.queue_free()
		_cook_audio = null
