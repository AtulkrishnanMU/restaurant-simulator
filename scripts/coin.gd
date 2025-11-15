extends Area2D

@export var magnet_radius: float = 140.0
@export var magnet_max_speed: float = 420.0
@export var magnet_min_speed: float = 80.0

@onready var anim = $AnimatedSprite2D
var player: Player = null

func _on_body_entered(body):
	CurrencyUtility.collect_currency(10, self, body)
		
func _on_ready():
	CurrencyUtility.play_float_animation(self)

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
