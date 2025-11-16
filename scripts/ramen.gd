extends Area2D

@export var magnet_radius: float = 140.0
@export var magnet_max_speed: float = 420.0
@export var magnet_min_speed: float = 80.0

@onready var sprite = $Sprite2D
var player: Player = null

var float_offset := 0.0
var float_speed := randf_range(2.0, 3.0)
var base_y := 0.0

func _on_body_entered(body):
	if body is Player:
		# Only pick up if player is not already carrying ramen
		if not body.has_ramen:
			# Play pickup sound if available
			var s = AudioStreamPlayer.new()
			var sound_path = "res://assets/sounds/pop.mp3"
			if ResourceLoader.exists(sound_path):
				s.stream = load(sound_path)
				# Slightly quieter pop (about 25% down)
				s.volume_db = -10.0
				get_tree().current_scene.add_child(s)
				s.play()
				s.finished.connect(s.queue_free)
			
			body.pickup_ramen()
			queue_free()
		else:
			# Player already carrying ramen, don't pick up
			print("Player already carrying ramen!")

func _ready():
	base_y = position.y
	# Randomize float speed
	float_speed = randf_range(2.0, 3.0)
	# Randomize starting offset
	float_offset = randf() * PI * 2
	_resolve_player()

# Connected from ramen.tscn: "ready" signal -> _on_ready
func _on_ready():
	pass

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_resolve_player()
	if not player:
		return
	var to_p: Vector2 = player.global_position - global_position
	var d: float = to_p.length()
	if d > magnet_radius:
		return
	var dir: Vector2 = to_p / max(d, 0.001)
	var t: float = clamp((magnet_radius - d) / magnet_radius, 0.0, 1.0)
	var speed: float = lerp(magnet_min_speed, magnet_max_speed, t)
	global_position += dir * speed * delta

func _resolve_player():
	var root := get_tree().get_root()
	var game := root.get_node_or_null("Game")
	if game:
		var p := game.get_node_or_null("Player")
		if p and p is Player:
			player = p

func _process(delta):
	# Simple floating animation
	if sprite:
		float_offset += float_speed * delta
		sprite.position.y = sin(float_offset) * 3.0  # Float up and down by 3 pixels
