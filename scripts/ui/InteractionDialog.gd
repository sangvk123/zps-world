## InteractionDialog.gd
## Employee interaction dialog — shown when player interacts with an NPC
## Options: Chat, Ask AI Agent, View Profile, Send Message

extends Control

# ── Nodes ──
@onready var emp_name: Label = $Panel/Header/EmpName
@onready var emp_title: Label = $Panel/Header/EmpTitle
@onready var emp_dept: Label = $Panel/Header/EmpDept
@onready var emp_status: Label = $Panel/Header/Status
@onready var current_task_label: Label = $Panel/CurrentTask
@onready var chat_input: LineEdit = $Panel/ChatSection/ChatInput
@onready var chat_history: VBoxContainer = $Panel/ChatSection/ChatHistory
@onready var send_btn: Button = $Panel/ChatSection/SendBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var avatar_preview: Control = $Panel/AvatarPreview

var current_employee: Dictionary = {}
var _conv_id: String = ""

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	send_btn.pressed.connect(_on_send_message)
	chat_input.text_submitted.connect(func(_t): _on_send_message())
	AIAgent.response_ready.connect(_on_ai_response)
	AIAgent.response_error.connect(_on_ai_error)

func open_for_employee(emp_data: Dictionary) -> void:
	current_employee = emp_data
	_conv_id = emp_data.get("id", "unknown")

	# Clear UI chat display
	for child in chat_history.get_children():
		child.queue_free()

	# Fill header
	var name := emp_data.get("name", "?")
	var title := emp_data.get("title", "?")
	var dept := emp_data.get("department", "?")
	var online := emp_data.get("is_online", false)

	emp_name.text = name
	emp_title.text = title
	emp_dept.text = dept
	emp_status.text = " Online" if online else " Offline — AI đang thay mặt"
	emp_status.modulate = Color.GREEN if online else Color(0.7, 0.7, 0.7)
	current_task_label.text = " " + emp_data.get("current_task", "?")

	# Restore previous conversation history in the UI
	if ConversationMemory.has_history(_conv_id):
		for msg: Dictionary in ConversationMemory.get_messages(_conv_id):
			var role: String = msg.get("role", "user")
			var sender: String = PlayerData.display_name if role == "user" else name
			_add_message(sender, msg.get("content", ""), role == "user")
	else:
		# First open — show auto-greeting
		var greeting := "%s xin chào! " % name
		if online:
			greeting += "Mình đang làm '%s'. Bạn cần gì không?" % emp_data.get("current_task", "việc")
		else:
			greeting += "Mình đang offline, AI sẽ trả lời thay mình nhé!"
		_add_message(name, greeting, false)

	chat_input.grab_focus()

func _on_send_message() -> void:
	var msg := chat_input.text.strip_edges()
	if msg.is_empty():
		return

	_add_message(PlayerData.display_name, msg, true)
	chat_input.clear()

	# AIAgent.ask_employee_agent internally calls ConversationMemory.add_user
	var emp_id := current_employee.get("id", "")
	if emp_id != "":
		_show_typing_indicator()
		AIAgent.ask_employee_agent(emp_id, msg)

func _on_ai_response(response: String, context_id: String) -> void:
	var emp_id := current_employee.get("id", "")
	if not context_id.contains(emp_id):
		return
	_remove_typing_indicator()
	# ConversationMemory.add_assistant already called inside AIAgent
	_add_message(current_employee.get("name", "AI"), response, false)

func _on_ai_error(error: String, _context_id: String) -> void:
	_remove_typing_indicator()
	_add_message("System", "[!] Không thể kết nối AI: %s" % error, false)

func _add_message(sender: String, message: String, is_player: bool) -> void:
	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_END if is_player else BoxContainer.ALIGNMENT_BEGIN

	var bubble = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.35, 0.55) if is_player else Color(0.25, 0.25, 0.35)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", style)
	bubble.custom_minimum_size.x = 40
	# bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN

	var vbox = VBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = sender
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.modulate = Color(0.8, 0.8, 0.8)
	var msg_lbl = Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_font_size_override("font_size", 11)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.custom_minimum_size.x = 180
	vbox.add_child(name_lbl)
	vbox.add_child(msg_lbl)
	bubble.add_child(vbox)

	if is_player:
		container.add_child(Control.new()) # spacer
		container.add_child(bubble)
	else:
		container.add_child(bubble)
		container.add_child(Control.new()) # spacer

	chat_history.add_child(container)
	# Scroll to bottom
	await get_tree().process_frame
	var scroll = chat_history.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _show_typing_indicator() -> void:
	var lbl = Label.new()
	lbl.name = "TypingIndicator"
	lbl.text = " đang gõ..."
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.6, 0.6, 0.6)
	chat_history.add_child(lbl)

func _remove_typing_indicator() -> void:
	var ti = chat_history.get_node_or_null("TypingIndicator")
	if ti:
		ti.queue_free()

func _on_close() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("close_interaction_dialog"):
		hud.close_interaction_dialog()
