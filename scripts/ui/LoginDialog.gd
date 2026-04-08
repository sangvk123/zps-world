## LoginDialog.gd
## Modal login screen shown at startup before the world loads.
## Posts to POST /auth/login and emits login_success(employee) on OK.
## The parent (Campus.gd) hides this node and spawns the player on success.

extends CanvasLayer

signal login_success(employee: Dictionary)
signal login_skipped()

var _employee_id_field: LineEdit = null
var _secret_field: LineEdit = null
var _submit_btn: Button = null
var _error_label: Label = null
var _loading_label: Label = null


func _ready() -> void:
	_build_ui()
	HttpManager.response_received.connect(_on_http_response)
	HttpManager.error.connect(_on_http_error)


func _build_ui() -> void:
	# Full-screen dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.05, 0.10, 0.97)
	add_child(overlay)

	# Centered card
	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -220.0
	card.offset_right = 220.0
	card.offset_top = -200.0
	card.offset_bottom = 200.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.18)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.35, 0.60)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# Title
	var title := Label.new()
	title.text = "ZPS World — Đăng nhập"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Employee ID field
	var id_label := Label.new()
	id_label.text = "Employee ID:"
	id_label.add_theme_font_size_override("font_size", 11)
	id_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vbox.add_child(id_label)

	_employee_id_field = LineEdit.new()
	_employee_id_field.placeholder_text = "vd: hieupt, sangvk, emp_001"
	_employee_id_field.custom_minimum_size.y = 34.0
	vbox.add_child(_employee_id_field)

	# Secret field
	var secret_label := Label.new()
	secret_label.text = "Dev Secret:"
	secret_label.add_theme_font_size_override("font_size", 11)
	secret_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vbox.add_child(secret_label)

	_secret_field = LineEdit.new()
	_secret_field.placeholder_text = "zps-dev-secret"
	_secret_field.secret = true
	_secret_field.custom_minimum_size.y = 34.0
	_secret_field.text_submitted.connect(func(_t): _on_submit_pressed())
	vbox.add_child(_secret_field)

	# Error label (hidden until error)
	_error_label = Label.new()
	_error_label.add_theme_font_size_override("font_size", 10)
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	vbox.add_child(_error_label)

	# Loading label (hidden until request in-flight)
	_loading_label = Label.new()
	_loading_label.text = "Đang đăng nhập..."
	_loading_label.add_theme_font_size_override("font_size", 10)
	_loading_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.visible = false
	vbox.add_child(_loading_label)

	# Submit button
	_submit_btn = Button.new()
	_submit_btn.text = "Vào ZPS World"
	_submit_btn.custom_minimum_size.y = 38.0
	_submit_btn.pressed.connect(_on_submit_pressed)
	vbox.add_child(_submit_btn)

	# Skip button (offline/mock mode)
	var skip_btn := Button.new()
	skip_btn.text = "Chơi offline (dùng dữ liệu mock)"
	skip_btn.flat = true
	skip_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	skip_btn.pressed.connect(func(): login_skipped.emit())
	vbox.add_child(skip_btn)

	card.add_child(vbox)
	add_child(card)


func _on_submit_pressed() -> void:
	var employee_id := _employee_id_field.text.strip_edges()
	var secret := _secret_field.text.strip_edges()

	if employee_id.is_empty():
		_show_error("Vui lòng nhập Employee ID.")
		return
	if secret.is_empty():
		_show_error("Vui lòng nhập dev secret.")
		return

	_set_loading(true)
	HttpManager.post("auth/login", {"employee_id": employee_id, "secret": secret})


func _on_http_response(endpoint: String, data: Variant) -> void:
	if endpoint != "auth/login":
		return
	_set_loading(false)

	if not data is Dictionary:
		_show_error("Phản hồi server không hợp lệ.")
		return

	var d := data as Dictionary
	if d.has("error"):
		_show_error("Sai Employee ID hoặc secret. Thử lại.")
		return

	var token: String = d.get("access_token", "")
	var employee: Dictionary = d.get("employee", {})

	if token.is_empty() or employee.is_empty():
		_show_error("Phản hồi server thiếu dữ liệu.")
		return

	# Store JWT for all future requests
	HttpManager.jwt_token = token

	login_success.emit(employee)


func _on_http_error(endpoint: String, message: String) -> void:
	if endpoint != "auth/login":
		return
	_set_loading(false)
	_show_error("Không kết nối được server.\nChạy: cd backend && npm run start:dev\n(%s)" % message)


func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true


func _set_loading(loading: bool) -> void:
	_submit_btn.disabled = loading
	_loading_label.visible = loading
	_error_label.visible = false
