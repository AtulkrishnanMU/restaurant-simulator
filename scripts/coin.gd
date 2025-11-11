extends Area2D

@onready var anim = $AnimatedSprite2D

func _on_body_entered(body):
	CurrencyUtility.collect_currency(10, self, body)
		
func _on_ready():
	CurrencyUtility.play_float_animation(self)
