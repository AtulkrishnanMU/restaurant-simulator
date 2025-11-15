extends Node2D

@export var width: float = 28.0
@export var height: float = 4.0
@export var offset: Vector2 = Vector2(0, -20)
@export var bg_color: Color = Color(0, 0, 0, 0.6)
@export var fg_color: Color = Color(1, 1, 1, 0.9)

var _value: float = 0.0
var value: float:
	set(v):
		_value = clamp(v, 0.0, 1.0)
		queue_redraw()
	get:
		return _value

func _ready():
	visible = false
	position = offset

func _process(_delta):
	# Keep positioned at offset relative to parent
	position = offset

func _draw():
	# Background bar (centered)
	var half_w := width * 0.5
	var rect_bg := Rect2(Vector2(-half_w, -height), Vector2(width, height))
	draw_rect(rect_bg, bg_color, true)
	# Foreground progress
	var fill_w := width * value
	var rect_fg := Rect2(Vector2(-half_w, -height), Vector2(fill_w, height))
	draw_rect(rect_fg, fg_color, true)
