extends Node
class_name CurrencyUtility

static func collect_currency(amount: int, area: Node, body: Node) -> void:
	if body is Player:
		var s := AudioStreamPlayer.new()
		s.stream = load("res://assets/sounds/cash.ogg")
		s.volume_db = 0
		if area and area.get_tree():
			area.get_tree().current_scene.add_child(s)
		s.play()
		s.finished.connect(s.queue_free)
		
		body.collect_cash(amount)
		if area and is_instance_valid(area):
			area.queue_free()

static func play_float_animation(area: Node) -> void:
	if not area:
		return
	var anim := area.get_node_or_null("AnimatedSprite2D")
	if anim and anim is AnimatedSprite2D:
		anim.play("FLOAT")
		var frame_count: int = anim.sprite_frames.get_frame_count("FLOAT")
		if frame_count > 0:
			anim.frame = randi() % frame_count
		anim.speed_scale = randf_range(0.8, 1.2)
