extends CanvasLayer

var coins_label: Label

func _ready():
	coins_label = $CoinsLabel  # Now guaranteed to exist at _ready
	update_coins(0)  # Show initial value

func update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "CASH: %d" % amount
		
func update_ramen(amount: int) -> void:
	$FoodLabel.text = "RAMEN: %d" % amount
