## LoginDialog.gd
## Full-screen login overlay — shown at startup when not logged in.
## POST /auth/login với {domain, password} → PlayerData.apply_login_data() → tự xóa.

extends Control
class_name LoginDialog

var _domain_field: LineEdit = null
var _password_field: LineEdit = null
var _error_label: Label = null
var _login_btn: Button = null
var _loading: bool = false

func _ready() -> void:
	# Force fill the whole viewport — CanvasLayer children don't auto-size
	var vp := get_viewport()
	if vp:
		var vr := vp.get_visible_rect()
		position = vr.position
		size = vr.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	# Pre-fill domain từ session trước
	if PlayerData.zps_callsign != "":
		_domain_field.text = PlayerData.zps_callsign
		_password_field.grab_focus()
	else:
		_domain_field.grab_focus()

func _build_ui() -> void:
	# ── Nền tối ──
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.10, 0.97)
	add_child(bg)

	# ── Card trung tâm — dùng custom_minimum_size để responsive ──
	var card := PanelContainer.new()
	card.anchor_left  = 0.5; card.anchor_right  = 0.5
	card.anchor_top   = 0.5; card.anchor_bottom = 0.5
	card.offset_left  = -200; card.offset_right  = 200
	card.offset_top   = -180; card.offset_bottom = 180
	card.custom_minimum_size = Vector2(380, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.16, 0.98)
	ps.set_corner_radius_all(12)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.90, 0.79, 0.47, 0.6)
	ps.content_margin_left = 32; ps.content_margin_right = 32
	ps.content_margin_top  = 28; ps.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", ps)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Tiêu đề
	var title := Label.new()
	title.text = "ZPS World"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.90, 0.79, 0.47))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Đăng nhập bằng domain nội bộ"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.55, 0.55, 0.70))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var sep := HSeparator.new()
	sep.modulate = Color(0.3, 0.3, 0.5, 0.5)
	vbox.add_child(sep)

	# Domain
	var domain_lbl := Label.new()
	domain_lbl.text = "Domain / Callsign"
	domain_lbl.add_theme_font_size_override("font_size", 10)
	domain_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	vbox.add_child(domain_lbl)

	_domain_field = LineEdit.new()
	_domain_field.placeholder_text = "vd: sangvk, hieupt"
	_domain_field.add_theme_font_size_override("font_size", 13)
	_domain_field.custom_minimum_size = Vector2(0, 36)
	_domain_field.text_submitted.connect(func(_t): _on_domain_submitted())
	vbox.add_child(_domain_field)

	# Password
	var pw_lbl := Label.new()
	pw_lbl.text = "Mật khẩu"
	pw_lbl.add_theme_font_size_override("font_size", 10)
	pw_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	vbox.add_child(pw_lbl)

	_password_field = LineEdit.new()
	_password_field.placeholder_text = "••••••••"
	_password_field.secret = true
	_password_field.add_theme_font_size_override("font_size", 13)
	_password_field.custom_minimum_size = Vector2(0, 36)
	_password_field.text_submitted.connect(func(_t): _submit())
	vbox.add_child(_password_field)

	# Error label
	_error_label = Label.new()
	_error_label.text = ""
	_error_label.add_theme_font_size_override("font_size", 10)
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	vbox.add_child(_error_label)

	# Nút đăng nhập
	_login_btn = Button.new()
	_login_btn.text = "Vào ZPS World"
	_login_btn.add_theme_font_size_override("font_size", 13)
	_login_btn.custom_minimum_size = Vector2(0, 42)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.14, 0.34, 0.62)
	bs.set_corner_radius_all(8)
	_login_btn.add_theme_stylebox_override("normal", bs)
	var bs_hov := StyleBoxFlat.new()
	bs_hov.bg_color = Color(0.20, 0.45, 0.80)
	bs_hov.set_corner_radius_all(8)
	_login_btn.add_theme_stylebox_override("hover", bs_hov)
	_login_btn.add_theme_color_override("font_color", Color.WHITE)
	_login_btn.pressed.connect(_submit)
	vbox.add_child(_login_btn)

func _on_domain_submitted() -> void:
	_password_field.grab_focus()

func _submit() -> void:
	if _loading:
		return
	var domain   := _domain_field.text.strip_edges()
	var password := _password_field.text
	if domain.is_empty() or password.is_empty():
		_show_error("Vui lòng nhập đầy đủ domain và mật khẩu.")
		return

	_loading = true
	_login_btn.text = "Đang đăng nhập..."
	_login_btn.disabled = true
	_error_label.visible = false

	HttpManager.response_received.connect(_on_login_response, CONNECT_ONE_SHOT)
	HttpManager.error.connect(_on_login_error, CONNECT_ONE_SHOT)
	HttpManager.post("auth/login", { "domain": domain, "password": password })

func _on_login_response(endpoint: String, data: Variant) -> void:
	if not endpoint.begins_with("auth/login"):
		return
	_loading = false
	_login_btn.text = "Vào ZPS World"
	_login_btn.disabled = false

	if data is Dictionary and (data as Dictionary).has("access_token"):
		var token: String = (data as Dictionary).get("access_token", "")
		var emp: Dictionary = (data as Dictionary).get("employee", {})
		PlayerData.apply_login_data(token, emp)
		queue_free()   # login_complete đã emit trong apply_login_data
	else:
		var err_msg := ""
		if data is Dictionary:
			err_msg = (data as Dictionary).get("error", "")
		_show_error(err_msg if err_msg != "" else "Domain hoặc mật khẩu không đúng.")

func _on_login_error(endpoint: String, message: String) -> void:
	if not endpoint.begins_with("auth/login"):
		return
	_loading = false
	_login_btn.text = "Vào ZPS World"
	_login_btn.disabled = false
	_show_error("Không kết nối được server API.\n(%s)" % message)

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true
