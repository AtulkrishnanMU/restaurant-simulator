extends CanvasLayer

var cash_label: Label
var popularity_label: Label
var cash_value_label: Label
var cash_slider: HSlider
var cash_value := 50

const PRICE_TEXT = "PRICE: %d¥"

func _ready():
	cash_label = $CashLabel  # Now guaranteed to exist at _ready
	popularity_label = $PopularityLabel
	update_cash(0)  # Show initial value
	update_popularity(0)  # Show initial popularity
	
	# Connect to popularity manager
	var game_node = get_tree().get_root().get_node("Game")
	var popularity_manager = game_node.get_node_or_null("PopularityManager")
	if popularity_manager:
		popularity_manager.popularity_changed.connect(update_popularity)

	# Create cash value UI (slider + label) programmatically
	# Slider controls how much money each NPC drop is worth
	cash_value_label = Label.new()
	cash_value_label.text = PRICE_TEXT % cash_value
	# Top-center anchor for label
	cash_value_label.anchor_left = 0.5
	cash_value_label.anchor_right = 0.5
	cash_value_label.anchor_top = 0.0
	cash_value_label.anchor_bottom = 0.0
	cash_value_label.offset_left = -60
	cash_value_label.offset_right = 60
	cash_value_label.offset_top = 8
	cash_value_label.offset_bottom = 24
	cash_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var price_font := load("res://assets/fonts/PixelOperator8.ttf") as FontFile
	if price_font:
		cash_value_label.add_theme_font_override("font", price_font)
		cash_value_label.add_theme_font_size_override("font_size", 15)
	else:
		cash_value_label.add_theme_font_size_override("font_size", 25)
	add_child(cash_value_label)

	cash_slider = HSlider.new()
	cash_slider.min_value = 20
	cash_slider.max_value = 50
	cash_slider.step = 5
	cash_slider.value = cash_value
	# Disable keyboard focus so arrow keys won't move it
	cash_slider.focus_mode = Control.FOCUS_NONE
	# Top-center anchor for slider
	cash_slider.anchor_left = 0.5
	cash_slider.anchor_right = 0.5
	cash_slider.anchor_top = 0.0
	cash_slider.anchor_bottom = 0.0
	cash_slider.offset_left = -100
	cash_slider.offset_right = 100
	cash_slider.offset_top = 28
	cash_slider.offset_bottom = 44
	cash_slider.value_changed.connect(_on_cash_slider_value_changed)
	add_child(cash_slider)

func update_cash(amount: int) -> void:
	if cash_label:
		cash_label.text = "CASH: %d" % amount

func update_popularity(popularity: int) -> void:
	if popularity_label:
		popularity_label.text = "POPULARITY: %d" % popularity
	# Increase the slider's max with popularity (initially 50, grows by popularity)
	if cash_slider:
		cash_slider.max_value = 50 + popularity
		var snapped_max: int = int(round(cash_slider.max_value / 5.0) * 5)
		cash_slider.max_value = snapped_max
		# Ensure current value stays within bounds and snapped to nearest 5
		var clamped: float = clamp(float(cash_slider.value), float(cash_slider.min_value), float(cash_slider.max_value))
		var snapped_val: int = int(round(clamped / 5.0) * 5)
		if int(cash_slider.value) != snapped_val:
			cash_slider.value = snapped_val
		cash_value = snapped_val
		if cash_value_label:
			cash_value_label.text = PRICE_TEXT % cash_value

func get_cash_value() -> int:
	return cash_value

func _on_cash_slider_value_changed(value: float) -> void:
	var snapped_val: int = int(round(value / 5.0) * 5)
	if snapped_val != int(cash_slider.value):
		cash_slider.value = snapped_val
	cash_value = snapped_val
	if cash_value_label:
		cash_value_label.text = PRICE_TEXT % cash_value
