extends Area2D

@onready var anim = $AnimatedSprite2D

func _on_body_entered(body):
	if body is Player:
		var s = AudioStreamPlayer.new()
		s.stream = load("res://assets/sounds/cash.ogg")
		s.volume_db = 0
		get_tree().current_scene.add_child(s)
		s.play()
		s.finished.connect(s.queue_free)
		
		body.collect_coin()
		queue_free()
		
func _on_ready():
	anim.play("FLOAT")
	
	# Randomize starting frame
	var frame_count = anim.sprite_frames.get_frame_count("FLOAT")
	anim.frame = randi() % frame_count
	
	# Randomize speed slightly
	anim.speed_scale = randf_range(0.8, 1.2)
	
