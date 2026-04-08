## ChatBubble.gd
## Speech bubble displayed above characters

extends PanelContainer

@onready var label: Label = $Label

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	label.add_theme_font_size_override("font_size", 10)

func show_message(message: String) -> void:
	label.text = message
	# Resize to fit
	await get_tree().process_frame
	var needed = label.get_minimum_size()
	custom_minimum_size = Vector2(max(60, needed.x + 16), needed.y + 8)
