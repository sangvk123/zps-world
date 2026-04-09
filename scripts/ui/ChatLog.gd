## ChatLog.gd
## Persistent scrollable chat log — stores all messages regardless of proximity radius.
## Toggled by pressing C (handled by HUD). Visible as overlay in bottom-left area.

extends Control

const MAX_MESSAGES: int = 200

var _bg: PanelContainer = null       # saved reference — avoids get_child(0) fragility
var _scroll: ScrollContainer = null
var _log_container: VBoxContainer = null
var _input_field: LineEdit = null
var _is_open: bool = false
var _messages: Array[Dictionary] = []   # {from, text, ts}

func _ready() -> void:
	add_to_group("chat_log")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	NetworkManager.chat_received.connect(_on_chat_received)

func _build_ui() -> void:
	# Panel — bottom-left, responsive via anchors
	_bg = PanelContainer.new()
	_bg.anchor_left   = 0.0; _bg.anchor_right  = 0.0
	_bg.anchor_top    = 1.0; _bg.anchor_bottom = 1.0
	_bg.offset_left   = 10;  _bg.offset_right  = 360
	_bg.offset_top    = -260; _bg.offset_bottom = -10
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.05, 0.10, 0.88)
	ps.set_corner_radius_all(8)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.25, 0.25, 0.4, 0.8)
	ps.content_margin_left = 8; ps.content_margin_right = 8
	ps.content_margin_top = 6;  ps.content_margin_bottom = 6
	_bg.add_theme_stylebox_override("panel", ps)
	_bg.visible = false
	add_child(_bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_bg.add_child(vbox)

	# Header row
	var hdr := HBoxContainer.new()
	var hdr_lbl := Label.new()
	hdr_lbl.text = "Chat"
	hdr_lbl.add_theme_font_size_override("font_size", 10)
	hdr_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_lbl)
	vbox.add_child(hdr)

	var sep := HSeparator.new()
	sep.modulate = Color(0.3, 0.3, 0.5, 0.5)
	vbox.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	vbox.add_child(_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 2)
	_scroll.add_child(_log_container)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	vbox.add_child(input_row)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Nhập tin nhắn, Enter để gửi..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.add_theme_font_size_override("font_size", 11)
	_input_field.text_submitted.connect(_on_send)
	input_row.add_child(_input_field)

func toggle() -> void:
	_is_open = !_is_open
	_bg.visible = _is_open
	if _is_open:
		_input_field.grab_focus()
		# Scroll to bottom when opening
		await get_tree().process_frame
		_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _on_chat_received(from_id: String, text: String, _ts: int) -> void:
	_messages.append({ "from": from_id, "text": text, "ts": _ts })
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Color-code own messages
	var is_self := from_id == PlayerData.player_id
	var name_lbl := Label.new()
	name_lbl.text = from_id + ":"
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color",
		Color(0.9, 0.8, 0.3) if is_self else Color(0.55, 0.85, 1.0))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(name_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = text
	msg_lbl.add_theme_font_size_override("font_size", 10)
	msg_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg_lbl)

	_log_container.add_child(row)

	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _on_send(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text)
	# Own message displayed via server echo → chat_received signal (no local duplicate)
	_input_field.clear()
