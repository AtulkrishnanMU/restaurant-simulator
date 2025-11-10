extends Area2D

@onready var sprite = $Sprite2D

var float_offset := 0.0
var float_speed := randf_range(2.0, 3.0)
var base_y := 0.0

func _on_body_entered(body):
	if body is Player:
		# Only pick up if player is not already carrying ramen
		if not body.has_ramen:
			# Play pickup sound if available
			var s = AudioStreamPlayer.new()
			var sound_path = "res://assets/sounds/power_up.wav"
			if ResourceLoader.exists(sound_path):
				s.stream = load(sound_path)
				s.volume_db = 0
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

func _process(delta):
	# Simple floating animation
	if sprite:
		float_offset += float_speed * delta
		sprite.position.y = sin(float_offset) * 3.0  # Float up and down by 3 pixels
