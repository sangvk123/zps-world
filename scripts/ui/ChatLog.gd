## ChatLog.gd
## Persistent scrollable chat log — stores all messages regardless of proximity radius.
## Toggled by pressing C. Visible as overlay in bottom-left area.

extends Control

const MAX_MESSAGES: int = 200

var _scroll: ScrollContainer = null
var _log_container: VBoxContainer = null
var _input_row: HBoxContainer = null
var _input_field: LineEdit = null
var _is_open: bool = false
var _messages: Array[Dictionary] = []   # {from, text, ts}

func _ready() -> void:
	set_process_input(true)
	_build_ui()
	NetworkManager.chat_received.connect(_on_chat_received)

func _build_ui() -> void:
	# Panel background
	var bg = PanelContainer.new()
	bg.position = Vector2(10, 380)
	bg.size = Vector2(340, 240)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.size = Vector2(340, 240)
	bg.add_child(vbox)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size = Vector2(340, 200)
	vbox.add_child(_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_log_container)

	_input_row = HBoxContainer.new()
	vbox.add_child(_input_row)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Press Enter to send..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.text_submitted.connect(_on_send)
	_input_row.add_child(_input_field)

	bg.visible = false
	_is_open = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C and not _input_field.has_focus():
			_toggle()

func _toggle() -> void:
	_is_open = !_is_open
	get_child(0).visible = _is_open
	if _is_open:
		_input_field.grab_focus()

func _on_chat_received(from_id: String, text: String, ts: int) -> void:
	_messages.append({ "from": from_id, "text": text, "ts": ts })
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	var lbl = Label.new()
	lbl.text = "[%s] %s" % [from_id, text]
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_container.add_child(lbl)
	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _on_send(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text)
	# Also show own message locally
	_on_chat_received(PlayerData.player_id, text, Time.get_unix_time_from_system())
	_input_field.clear()
