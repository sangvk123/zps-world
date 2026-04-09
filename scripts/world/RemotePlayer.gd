## RemotePlayer.gd
## Represents another player controlled by network input.
## Sprint 4: adds emote floating display + profile card click handling.

class_name RemotePlayer
extends CharacterBody2D

# ── Config — set before add_child ──
var player_id: String = ""
var display_name: String = "Unknown"
var avatar_config: Dictionary = {}
var is_npc_mode: bool = false

# ── Player metadata (filled by Campus from GameManager.employees) ──
var hr_title: String = ""
var department: String = ""
var status: String = "online"
var status_msg: String = ""

# ── Visual nodes ──
var _nameplate: Label = null
var _status_dot: ColorRect = null
var _body_rect: ColorRect = null
var _npc_badge: Label = null

# ── Emote display ──
var _emote_label: Label = null
var _emote_timer: float = 0.0
const EMOTE_DISPLAY_DURATION: float = 2.0

# ── Input area for click detection ──
var _click_area: Area2D = null

# ── Network position lerp ──
var _target_pos: Vector2 = Vector2.ZERO
const LERP_SPEED: float = 12.0

func _ready() -> void:
	add_to_group("remote_players")
	collision_layer = 4
	collision_mask = 0
	_build_visuals()
	_build_click_area()
	_target_pos = global_position
	NetworkManager.emote_received.connect(_on_emote_received)
	NetworkManager.chat_received.connect(_on_chat_received)

func _exit_tree() -> void:
	if NetworkManager.emote_received.is_connected(_on_emote_received):
		NetworkManager.emote_received.disconnect(_on_emote_received)
	if NetworkManager.chat_received.is_connected(_on_chat_received):
		NetworkManager.chat_received.disconnect(_on_chat_received)

func _build_visuals() -> void:
	_body_rect = ColorRect.new()
	_body_rect.size = Vector2(12, 16)
	_body_rect.position = Vector2(-6, -16)
	_body_rect.color = Color(0.4, 0.8, 0.4)
	add_child(_body_rect)

	_nameplate = Label.new()
	_nameplate.text = display_name
	_nameplate.position = Vector2(-40, -30)
	_nameplate.custom_minimum_size = Vector2(80, 0)
	_nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nameplate.add_theme_font_size_override("font_size", 9)
	add_child(_nameplate)

	_status_dot = ColorRect.new()
	_status_dot.size = Vector2(6, 6)
	_status_dot.position = Vector2(6, -20)
	_status_dot.color = Color(0.2, 0.9, 0.2)
	add_child(_status_dot)

	_npc_badge = Label.new()
	_npc_badge.text = "[AI]"
	_npc_badge.position = Vector2(-12, -38)
	_npc_badge.add_theme_font_size_override("font_size", 8)
	_npc_badge.modulate = Color(1.0, 0.8, 0.0)
	_npc_badge.visible = false
	add_child(_npc_badge)

	_emote_label = Label.new()
	_emote_label.text = ""
	_emote_label.position = Vector2(-20, -50)
	_emote_label.add_theme_font_size_override("font_size", 14)
	_emote_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_emote_label)

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.collision_layer = 0
	_click_area.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 28)
	col.shape = shape
	col.position = Vector2(0, -14)
	_click_area.add_child(col)
	add_child(_click_area)
	_click_area.input_event.connect(_on_area_input_event)
	_click_area.input_pickable = true

func set_name_and_avatar(p_name: String, p_avatar: Dictionary) -> void:
	display_name = p_name
	avatar_config = p_avatar
	if _nameplate:
		_nameplate.text = p_name

func set_metadata(p_title: String, p_dept: String, p_status: String, p_msg: String) -> void:
	hr_title    = p_title
	department  = p_dept
	status      = p_status
	status_msg  = p_msg

func set_target_position(x: float, y: float) -> void:
	_target_pos = Vector2(x, y)

func _physics_process(delta: float) -> void:
	if not is_npc_mode:
		# move_toward caps speed properly without overshooting
		global_position = global_position.move_toward(_target_pos, LERP_SPEED * 10.0 * delta)

	if _emote_timer > 0.0:
		_emote_timer -= delta
		var alpha: float = clamp(_emote_timer / EMOTE_DISPLAY_DURATION, 0.0, 1.0)
		_emote_label.modulate.a = alpha
		if _emote_timer <= 0.0:
			_emote_label.text = ""
			_emote_label.modulate.a = 0.0

func enter_npc_mode() -> void:
	is_npc_mode = true
	status = "offline"
	if _status_dot:
		_status_dot.color = Color(0.5, 0.5, 0.5)
	if _npc_badge:
		_npc_badge.visible = true

func exit_npc_mode() -> void:
	is_npc_mode = false
	status = "online"
	if _status_dot:
		_status_dot.color = Color(0.2, 0.9, 0.2)
	if _npc_badge:
		_npc_badge.visible = false

func _on_chat_received(from_id: String, text: String, _ts: int) -> void:
	if from_id != player_id:
		return
	say(text)

func say(text: String, duration: float = 4.0) -> void:
	var old := get_node_or_null("ChatBubble")
	if old:
		old.queue_free()
	var bubble := Label.new()
	bubble.name = "ChatBubble"
	bubble.text = text
	bubble.add_theme_font_size_override("font_size", 7)
	bubble.position = Vector2(-30.0, -52.0)
	bubble.modulate = Color(1.0, 1.0, 0.8)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.custom_minimum_size = Vector2(80.0, 0.0)
	add_child(bubble)
	get_tree().create_timer(duration).timeout.connect(
		func(): if is_instance_valid(bubble): bubble.queue_free()
	)

func _on_emote_received(from_id: String, emote: String) -> void:
	if from_id != player_id:
		return
	_show_emote(emote)

func _show_emote(emote_key: String) -> void:
	var display_text := _emote_key_to_text(emote_key)
	_emote_label.text = display_text
	_emote_label.modulate.a = 1.0
	_emote_timer = EMOTE_DISPLAY_DURATION

func _emote_key_to_text(key: String) -> String:
	match key:
		"wave":     return "[Wave]"
		"thumbsup": return "[+1]"
		"clap":     return "[Clap!]"
		"question": return "[?]"
		"think":    return "[...]"
		"party":    return "[Party!]"
		_:          return "[" + key + "]"

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_open_profile_card()

func _open_profile_card() -> void:
	var existing := get_tree().get_first_node_in_group("profile_card")
	if existing:
		existing.queue_free()

	var card := load("res://scripts/ui/ProfileCard.gd").new() as ProfileCard
	card.add_to_group("profile_card")
	get_tree().root.add_child(card)

	var data := {
		"player_id":    player_id,
		"display_name": display_name,
		"title":        hr_title,
		"department":   department,
		"status":       status,
		"status_msg":   status_msg,
		"achievements": [],
		"is_npc":       is_npc_mode,
	}
	var emp_data: Dictionary = GameManager.employees.get(player_id, {})
	data["achievements"] = emp_data.get("achievements", [])
	card.populate(data)

	var cam: Camera2D = get_viewport().get_camera_2d()
	card.position_near(self, cam)

	card.dm_requested.connect(func(pid: String):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_dm"):
			hud.open_dm(pid)
	)
	card.view_desk_requested.connect(func(pid: String):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_remote_desk"):
			hud.open_remote_desk(pid)
	)
