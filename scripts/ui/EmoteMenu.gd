## EmoteMenu.gd
## Radial emote selector — 6 emotes arranged in a circle.
## Press Q to open/close. Click or press 1-6 to fire.
## Sends NetworkManager.send_emote(emote_key).

class_name EmoteMenu
extends Control

const EMOTES: Array = [
	{"key": "wave",      "label": "Wave",     "emoji": "[Wave]"},
	{"key": "thumbsup",  "label": "Thumbs up","emoji": "[+1]"},
	{"key": "clap",      "label": "Clap",     "emoji": "[Clap]"},
	{"key": "question",  "label": "Question", "emoji": "[?]"},
	{"key": "think",     "label": "Think",    "emoji": "[...]"},
	{"key": "party",     "label": "Party",    "emoji": "[Party]"},
]

const RADIUS: float = 68.0
const BTN_SIZE: Vector2 = Vector2(52, 52)

var _emote_btns: Array[Button] = []

signal emote_selected(emote_key: String)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.size = Vector2(200, 200)
	bg.position = Vector2(-100, -100)
	add_child(bg)

	_emote_btns.clear()
	for i in EMOTES.size():
		var angle := (TAU / EMOTES.size()) * i - PI * 0.5
		var offset := Vector2(cos(angle), sin(angle)) * RADIUS
		var btn := _make_emote_button(i, offset)
		add_child(btn)
		_emote_btns.append(btn)

func _make_emote_button(index: int, offset: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.position = offset - BTN_SIZE * 0.5
	btn.text = EMOTES[index]["emoji"] + "\n" + EMOTES[index]["label"]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 0.92)
	style.set_corner_radius_all(26)
	style.border_color = Color(0.4, 0.55, 0.75)
	style.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.22, 0.28, 0.42, 0.95)
	style_hover.border_color = Color(0.6, 0.8, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	btn.add_theme_constant_override("separation", 2)

	var capture_i := index
	btn.pressed.connect(func(): _fire_emote(capture_i))
	return btn

func _fire_emote(index: int) -> void:
	var emote_key: String = EMOTES[index]["key"]
	NetworkManager.send_emote(emote_key)
	emote_selected.emit(emote_key)
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _fire_emote(0)
			KEY_2: _fire_emote(1)
			KEY_3: _fire_emote(2)
			KEY_4: _fire_emote(3)
			KEY_5: _fire_emote(4)
			KEY_6: _fire_emote(5)
			KEY_ESCAPE: queue_free()
