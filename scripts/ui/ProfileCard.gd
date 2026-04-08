## ProfileCard.gd
## Floating profile popup shown when clicking a RemotePlayer or Employee avatar.
## Displays name, title, department, achievement badges, online status.
## Quick actions: Send DM, View Desk.

class_name ProfileCard
extends PanelContainer

var target_player_id: String = ""
var target_display_name: String = ""
var target_title: String = ""
var target_department: String = ""
var target_status: String = "online"
var target_status_msg: String = ""
var target_achievements: Array[String] = []
var target_is_npc: bool = false

var _name_label: Label = null
var _title_label: Label = null
var _dept_label: Label = null
var _status_dot: ColorRect = null
var _status_label: Label = null
var _status_msg_label: Label = null
var _badge_row: HBoxContainer = null
var _npc_badge: Label = null
var _dm_btn: Button = null
var _desk_btn: Button = null

signal dm_requested(player_id: String)
signal view_desk_requested(player_id: String)

func _ready() -> void:
	_build_ui()
	var timer := Timer.new()
	timer.wait_time = 8.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	style.set_corner_radius_all(10)
	style.border_color = Color(0.3, 0.45, 0.65)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(220, 160)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	_status_dot = ColorRect.new()
	_status_dot.custom_minimum_size = Vector2(10, 10)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot.color = Color(0.2, 0.9, 0.2)
	header_row.add_child(_status_dot)

	_name_label = Label.new()
	_name_label.text = "Unknown"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.modulate = Color(0.9, 0.95, 1.0)
	header_row.add_child(_name_label)

	_npc_badge = Label.new()
	_npc_badge.text = " [AI]"
	_npc_badge.add_theme_font_size_override("font_size", 10)
	_npc_badge.modulate = Color(1.0, 0.75, 0.1)
	_npc_badge.visible = false
	header_row.add_child(_npc_badge)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.modulate = Color(0.7, 0.8, 0.9)
	vbox.add_child(_title_label)

	_dept_label = Label.new()
	_dept_label.add_theme_font_size_override("font_size", 10)
	_dept_label.modulate = Color(0.6, 0.7, 0.8)
	vbox.add_child(_dept_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_status_label)

	_status_msg_label = Label.new()
	_status_msg_label.add_theme_font_size_override("font_size", 10)
	_status_msg_label.modulate = Color(0.75, 0.75, 0.75)
	_status_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_msg_label)

	var badge_section := Label.new()
	badge_section.text = "Achievements:"
	badge_section.add_theme_font_size_override("font_size", 9)
	badge_section.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(badge_section)

	_badge_row = HBoxContainer.new()
	vbox.add_child(_badge_row)

	vbox.add_child(HSeparator.new())

	var actions_row := HBoxContainer.new()
	vbox.add_child(actions_row)

	_dm_btn = Button.new()
	_dm_btn.text = "DM"
	_dm_btn.custom_minimum_size = Vector2(70, 28)
	_dm_btn.pressed.connect(func(): dm_requested.emit(target_player_id))
	actions_row.add_child(_dm_btn)

	_desk_btn = Button.new()
	_desk_btn.text = "View Desk"
	_desk_btn.custom_minimum_size = Vector2(90, 28)
	_desk_btn.pressed.connect(func(): view_desk_requested.emit(target_player_id))
	actions_row.add_child(_desk_btn)

func populate(data: Dictionary) -> void:
	target_player_id  = data.get("player_id", "")
	target_display_name = data.get("display_name", "Unknown")
	target_title      = data.get("title", "")
	target_department = data.get("department", "")
	target_status     = data.get("status", "online")
	target_status_msg = data.get("status_msg", "")
	target_achievements = data.get("achievements", [])
	target_is_npc     = data.get("is_npc", false)

	_name_label.text = target_display_name
	_title_label.text = target_title
	_dept_label.text  = target_department

	match target_status:
		"online":
			_status_dot.color = Color(0.2, 0.9, 0.2)
			_status_label.text = "Online"
			_status_label.modulate = Color(0.3, 0.9, 0.3)
		"away":
			_status_dot.color = Color(1.0, 0.75, 0.0)
			_status_label.text = "Away"
			_status_label.modulate = Color(1.0, 0.75, 0.0)
		"busy":
			_status_dot.color = Color(0.9, 0.25, 0.25)
			_status_label.text = "Busy"
			_status_label.modulate = Color(0.9, 0.3, 0.3)
		_:
			_status_dot.color = Color(0.5, 0.5, 0.5)
			_status_label.text = "Offline"
			_status_label.modulate = Color(0.6, 0.6, 0.6)

	_status_msg_label.text = target_status_msg if target_status_msg != "" else ""
	_status_msg_label.visible = target_status_msg != ""
	_npc_badge.visible = target_is_npc

	for child in _badge_row.get_children():
		child.queue_free()
	var shown := 0
	for ach_id in target_achievements:
		if shown >= 3:
			break
		var badge := Label.new()
		badge.text = _achievement_icon(ach_id) + " " + ach_id.replace("_", " ").capitalize()
		badge.add_theme_font_size_override("font_size", 9)
		badge.modulate = Color(1.0, 0.85, 0.3)
		_badge_row.add_child(badge)
		shown += 1
	if shown == 0:
		var none_lbl := Label.new()
		none_lbl.text = "No achievements yet"
		none_lbl.add_theme_font_size_override("font_size", 9)
		none_lbl.modulate = Color(0.5, 0.5, 0.5)
		_badge_row.add_child(none_lbl)

func _achievement_icon(ach_id: String) -> String:
	match ach_id:
		"onboarding_complete": return "[*]"
		"first_year":          return "[1yr]"
		"top_performer":       return "[TOP]"
		_:                     return "[+]"

func position_near(world_node: Node2D, camera: Camera2D) -> void:
	if camera == null:
		global_position = Vector2(100, 100)
		return
	var screen_pos := camera.unproject_position(world_node.global_position)
	var desired := screen_pos + Vector2(-custom_minimum_size.x * 0.5, -custom_minimum_size.y - 24.0)
	var vp_size := get_viewport_rect().size
	desired.x = clamp(desired.x, 4.0, vp_size.x - custom_minimum_size.x - 4.0)
	desired.y = clamp(desired.y, 4.0, vp_size.y - custom_minimum_size.y - 4.0)
	position = desired
