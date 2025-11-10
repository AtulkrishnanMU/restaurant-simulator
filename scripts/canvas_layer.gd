extends CanvasLayer

var coins_label: Label
var popularity_label: Label
var coin_value_label: Label
var coin_slider: HSlider
var coin_value := 50

const PRICE_TEXT = "PRICE: %d¥"

func _ready():
	coins_label = $CoinsLabel  # Now guaranteed to exist at _ready
	popularity_label = $PopularityLabel
	update_coins(0)  # Show initial value
	update_popularity(0)  # Show initial popularity
	
	# Connect to popularity manager
	var game_node = get_tree().get_root().get_node("Game")
	var popularity_manager = game_node.get_node_or_null("PopularityManager")
	if popularity_manager:
		popularity_manager.popularity_changed.connect(update_popularity)

	# Create coin value UI (slider + label) programmatically
	# Slider controls how much money each NPC drop is worth
	coin_value_label = Label.new()
	coin_value_label.text = PRICE_TEXT % coin_value
	# Top-center anchor for label
	coin_value_label.anchor_left = 0.5
	coin_value_label.anchor_right = 0.5
	coin_value_label.anchor_top = 0.0
	coin_value_label.anchor_bottom = 0.0
	coin_value_label.offset_left = -60
	coin_value_label.offset_right = 60
	coin_value_label.offset_top = 8
	coin_value_label.offset_bottom = 24
	coin_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var price_font := load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if price_font:
		coin_value_label.add_theme_font_override("font", price_font)
		coin_value_label.add_theme_font_size_override("font_size", 15)
	else:
		coin_value_label.add_theme_font_size_override("font_size", 25)
	add_child(coin_value_label)

	coin_slider = HSlider.new()
	coin_slider.min_value = 20
	coin_slider.max_value = 50
	coin_slider.step = 5
	coin_slider.value = coin_value
	# Disable keyboard focus so arrow keys won't move it
	coin_slider.focus_mode = Control.FOCUS_NONE
	# Top-center anchor for slider
	coin_slider.anchor_left = 0.5
	coin_slider.anchor_right = 0.5
	coin_slider.anchor_top = 0.0
	coin_slider.anchor_bottom = 0.0
	coin_slider.offset_left = -100
	coin_slider.offset_right = 100
	coin_slider.offset_top = 28
	coin_slider.offset_bottom = 44
	coin_slider.value_changed.connect(_on_coin_slider_value_changed)
	add_child(coin_slider)

func update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "CASH: %d" % amount

func update_popularity(popularity: int) -> void:
	if popularity_label:
		popularity_label.text = "POPULARITY: %d" % popularity
	# Increase the slider's max with popularity (initially 50, grows by popularity)
	if coin_slider:
		coin_slider.max_value = 50 + popularity
		var snapped: int = int(round(coin_slider.max_value / 5.0) * 5)
		coin_slider.max_value = snapped
		# Ensure current value stays within bounds and snapped to nearest 5
		var clamped: float = clamp(float(coin_slider.value), float(coin_slider.min_value), float(coin_slider.max_value))
		var snapped_val: int = int(round(clamped / 5.0) * 5)
		if int(coin_slider.value) != snapped_val:
			coin_slider.value = snapped_val
		coin_value = snapped_val
		if coin_value_label:
			coin_value_label.text = PRICE_TEXT % coin_value

func get_coin_value() -> int:
	return coin_value

func _on_coin_slider_value_changed(value: float) -> void:
	var snapped: int = int(round(value / 5.0) * 5)
	if snapped != int(coin_slider.value):
		coin_slider.value = snapped
	coin_value = snapped
	if coin_value_label:
		coin_value_label.text = PRICE_TEXT % coin_value
