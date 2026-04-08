## WorkspacePanel.gd
## Workspace functions panel — like Teams but game-flavored
## Tabs: Book Room, Leave Request, Courses, My Sprint, Ask AI

extends Control

@onready var tab_container: TabContainer = $Panel/Tabs
@onready var close_btn: Button = $Panel/Header/CloseBtn
@onready var title_label: Label = $Panel/Header/Title

# ── Book Room tab ──
@onready var room_list: VBoxContainer = $Panel/Tabs/BookRoom/RoomList
@onready var time_slot_options: OptionButton = $Panel/Tabs/BookRoom/TimeSlot
@onready var book_btn: Button = $Panel/Tabs/BookRoom/BookBtn
@onready var book_result: Label = $Panel/Tabs/BookRoom/Result

var selected_room_id: String = ""

# ── Leave Request tab ──
@onready var leave_type: OptionButton = $Panel/Tabs/Leave/LeaveType
@onready var leave_from: LineEdit = $Panel/Tabs/Leave/FromDate
@onready var leave_to: LineEdit = $Panel/Tabs/Leave/ToDate
@onready var leave_reason: TextEdit = $Panel/Tabs/Leave/Reason
@onready var submit_leave_btn: Button = $Panel/Tabs/Leave/SubmitBtn
@onready var leave_result: Label = $Panel/Tabs/Leave/Result

# ── Sprint tab ──
@onready var sprint_list: VBoxContainer = $Panel/Tabs/MySprint/SprintList

# ── AI Assistant tab ──
@onready var ai_input: LineEdit = $Panel/Tabs/AIAssistant/Input
@onready var ai_send_btn: Button = $Panel/Tabs/AIAssistant/SendBtn
@onready var ai_response_label: Label = $Panel/Tabs/AIAssistant/Response

const TIME_SLOTS = [
	"09:00 - 10:00", "10:00 - 11:00", "11:00 - 12:00",
	"13:30 - 14:30", "14:30 - 15:30", "15:30 - 16:30",
	"16:30 - 17:30"
]

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	if is_instance_valid(book_btn):
		book_btn.pressed.connect(_on_book_room)
	if is_instance_valid(submit_leave_btn):
		submit_leave_btn.pressed.connect(_on_submit_leave)
	if is_instance_valid(ai_send_btn):
		ai_send_btn.pressed.connect(_on_ask_ai)
	if is_instance_valid(ai_input):
		ai_input.text_submitted.connect(func(_t): _on_ask_ai())
	AIAgent.response_ready.connect(_on_ai_response)
	_populate_time_slots()

func refresh() -> void:
	_populate_room_list()
	_populate_sprint_list()
	_update_leave_defaults()

# ── Book Room ──
func _populate_room_list() -> void:
	if not is_instance_valid(room_list):
		return
	for child in room_list.get_children():
		child.queue_free()
	for room_id in GameManager.meeting_rooms:
		var room = GameManager.meeting_rooms[room_id]
		var btn = _create_room_button(room_id, room)
		room_list.add_child(btn)

func _create_room_button(room_id: String, room: Dictionary) -> Button:
	var btn = Button.new()
	var schedule = room.get("schedule", [])
	var booked_slots = schedule.map(func(s): return s["time"])
	btn.text = "%s\n Capacity: %d | Equipment: %s\n Booked: %s" % [
		room["name"],
		room.get("capacity", 0),
		", ".join(room.get("equipment", [])),
		"None" if booked_slots.is_empty() else ", ".join(booked_slots)
	]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 60
	btn.pressed.connect(func(): _select_room(room_id, btn))
	return btn

func _select_room(room_id: String, btn: Button) -> void:
	selected_room_id = room_id
	# Visual feedback
	for child in room_list.get_children():
		child.modulate = Color.WHITE
	btn.modulate = Color(0.6, 1.0, 0.6)
	if is_instance_valid(book_result):
		book_result.text = "Đã chọn: %s" % GameManager.meeting_rooms[room_id]["name"]

func _populate_time_slots() -> void:
	if not is_instance_valid(time_slot_options):
		return
	time_slot_options.clear()
	for slot in TIME_SLOTS:
		time_slot_options.add_item(slot)

func _on_book_room() -> void:
	if selected_room_id.is_empty():
		if is_instance_valid(book_result):
			book_result.text = "[!] Hãy chọn phòng trước!"
		return
	var slot = TIME_SLOTS[time_slot_options.selected]
	var success = GameManager.book_room(selected_room_id, slot, PlayerData.player_id)
	if is_instance_valid(book_result):
		book_result.text = "[v] Đã đặt thành công!" if success else "[x] Slot này đã được đặt!"
		book_result.modulate = Color.GREEN if success else Color.RED
	_populate_room_list()

# ── Leave Request ──
func _update_leave_defaults() -> void:
	if not is_instance_valid(leave_from):
		return
	var today = Time.get_date_string_from_system()
	leave_from.text = today
	leave_to.text = today
	if leave_type:
		leave_type.clear()
		for t in ["Nghỉ phép năm", "Nghỉ ốm", "Nghỉ không lương", "Nghỉ đặc biệt"]:
			leave_type.add_item(t)

func _on_submit_leave() -> void:
	var leave_data = {
		"type": leave_type.get_item_text(leave_type.selected) if is_instance_valid(leave_type) else "?",
		"dates": "%s → %s" % [
			leave_from.text if is_instance_valid(leave_from) else "?",
			leave_to.text if is_instance_valid(leave_to) else "?"
		],
		"reason": leave_reason.text if is_instance_valid(leave_reason) else "",
		"submitted_at": Time.get_datetime_string_from_system(),
	}
	GameManager.request_leave(leave_data)
	if is_instance_valid(leave_result):
		leave_result.text = "[v] Đơn xin nghỉ đã gửi! HR sẽ xét duyệt trong vòng 24h."
		leave_result.modulate = Color.GREEN

# ── Sprint View ──
func _populate_sprint_list() -> void:
	if not is_instance_valid(sprint_list):
		return
	for child in sprint_list.get_children():
		child.queue_free()
	for sprint in GameManager.active_sprints:
		var card = _create_sprint_card(sprint)
		sprint_list.add_child(card)

func _create_sprint_card(sprint: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = 80

	var vbox = VBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = sprint.get("name", "Sprint")
	name_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_lbl)

	var meta_lbl = Label.new()
	meta_lbl.text = "%s · Deadline: %s" % [sprint.get("team", "?"), sprint.get("deadline", "?")]
	meta_lbl.add_theme_font_size_override("font_size", 10)
	meta_lbl.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(meta_lbl)

	var progress_bar = ProgressBar.new()
	progress_bar.value = sprint.get("progress", 0.0) * 100
	progress_bar.custom_minimum_size.y = 14
	vbox.add_child(progress_bar)

	var tasks_lbl = Label.new()
	tasks_lbl.text = "%d / %d tasks done" % [sprint.get("tasks_done", 0), sprint.get("tasks_total", 0)]
	tasks_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(tasks_lbl)

	panel.add_child(vbox)
	return panel

# ── AI Assistant ──
func _on_ask_ai() -> void:
	if not is_instance_valid(ai_input):
		return
	var question = ai_input.text.strip_edges()
	if question.is_empty():
		return
	if is_instance_valid(ai_response_label):
		ai_response_label.text = " Đang hỏi AI..."
	AIAgent.ask_workspace_assistant(question)
	ai_input.clear()

func _on_ai_response(response: String, context_id: String) -> void:
	if not context_id.begins_with("workspace_"):
		return
	if is_instance_valid(ai_response_label):
		ai_response_label.text = response
		ai_response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ── Close ──
func _on_close() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_toggle_workspace_panel"):
		hud._toggle_workspace_panel()
	else:
		hide()
