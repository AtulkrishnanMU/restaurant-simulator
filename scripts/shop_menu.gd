extends Control

signal buy_item(scene_path: String)

@onready var exit_button: Button = $Panel/VBox/ExitButton if has_node("Panel/VBox/ExitButton") else null
@onready var chair_buy: Button = $Panel/VBox/Items/ChairBox/ChairBuy if has_node("Panel/VBox/Items/ChairBox/ChairBuy") else null
@onready var maker_buy: Button = $Panel/VBox/Items/MakerBox/MakerBuy if has_node("Panel/VBox/Items/MakerBox/MakerBuy") else null
@onready var error_label: Label = $Panel/VBox/ErrorLabel if has_node("Panel/VBox/ErrorLabel") else null

func _ready() -> void:
	if exit_button:
		exit_button.pressed.connect(func(): hide_menu())
	if chair_buy:
		chair_buy.pressed.connect(func():
			_emit_buy("res://scenes/chair.tscn")
		)
	if maker_buy:
		maker_buy.pressed.connect(func():
			_emit_buy("res://scenes/ramen_maker.tscn")
		)

func _emit_buy(scene_path: String) -> void:
	emit_signal("buy_item", scene_path)

func show_menu():
	visible = true
	if error_label:
		error_label.text = ""
		error_label.modulate.a = 0.0

func hide_menu():
	visible = false

func show_error(msg: String) -> void:
	if error_label:
		# Set text and make fully visible
		error_label.text = msg
		var color := error_label.modulate
		color.a = 1.0
		error_label.modulate = color
		# Fade out after a short delay, then clear text
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(error_label, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func():
			if error_label:
				error_label.text = ""
		)
