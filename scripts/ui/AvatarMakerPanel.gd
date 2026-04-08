## AvatarMakerPanel.gd
## Panel tạo AI Avatar Portrait — tích hợp avatar-maker-green.vercel.app
## Dùng JavaScriptBridge (Web/WASM) để:
##   1. Mở file picker -> đọc ảnh thành base64
##   2. Gọi fetch() POST /api/generate-avatar
##   3. Preview kết quả, lưu vào PlayerData
##
## NOTE: JavaScriptBridge.eval() là API chuẩn của Godot Web build.
## Data người dùng được truyền qua window vars với JSON.stringify, không inject vào JS string.

extends Control

const API_BASE     := "https://avatar-maker-green.vercel.app"
const API_AUTH     := API_BASE + "/api/auth"
const API_GENERATE := API_BASE + "/api/generate-avatar"
const API_PASSWORD := "zps2026"

# -- Trang thai noi bo --
var _selected_image_base64: String = ""
var _selected_mime: String = "image/png"
var _selected_style: String = "chibi"
var _result_base64: String = ""
var _is_generating: bool = false
var _poll_timer: SceneTreeTimer = null

# -- UI nodes (tao trong _build_ui) --
var _upload_btn: Button
var _upload_label: Label
var _style_group: HBoxContainer
var _generate_btn: Button
var _status_label: Label
var _preview_rect: TextureRect
var _save_btn: Button
var _current_portrait_rect: TextureRect

func _ready() -> void:
	_build_ui()
	_refresh_current_portrait()

# ─────────────────────────────────────────────
# Build UI
# ─────────────────────────────────────────────
func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# -- Portrait hien tai --
	var current_row := HBoxContainer.new()
	current_row.add_theme_constant_override("separation", 10)
	var current_lbl := Label.new()
	current_lbl.text = "Portrait hien tai:"
	current_lbl.add_theme_font_size_override("font_size", 10)
	current_row.add_child(current_lbl)
	_current_portrait_rect = TextureRect.new()
	_current_portrait_rect.custom_minimum_size = Vector2(48, 48)
	_current_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_current_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	current_row.add_child(_current_portrait_rect)
	vbox.add_child(current_row)

	vbox.add_child(HSeparator.new())

	# -- Upload section --
	var upload_row := HBoxContainer.new()
	upload_row.add_theme_constant_override("separation", 8)
	_upload_btn = Button.new()
	_upload_btn.text = "Chon anh"
	_upload_btn.pressed.connect(_on_upload_pressed)
	upload_row.add_child(_upload_btn)
	_upload_label = Label.new()
	_upload_label.text = "Chua chon anh (JPEG/PNG/WebP, toi da 5MB)"
	_upload_label.add_theme_font_size_override("font_size", 9)
	_upload_label.modulate = Color(0.6, 0.6, 0.6)
	_upload_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_upload_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_row.add_child(_upload_label)
	vbox.add_child(upload_row)

	# -- Style picker --
	var style_lbl := Label.new()
	style_lbl.text = "Chon phong cach:"
	style_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(style_lbl)

	_style_group = HBoxContainer.new()
	_style_group.add_theme_constant_override("separation", 6)
	var styles := [
		{"id": "chibi",    "label": "Chibi"},
		{"id": "anime",    "label": "Anime"},
		{"id": "3d-pixar", "label": "3D Pixar"},
	]
	for s in styles:
		var btn := Button.new()
		btn.text = s["label"]
		btn.toggle_mode = true
		btn.button_pressed = (s["id"] == _selected_style)
		btn.name = "StyleBtn_" + s["id"]
		var sid: String = s["id"]
		btn.pressed.connect(func(): _on_style_selected(sid, btn))
		_style_group.add_child(btn)
	vbox.add_child(_style_group)

	# -- Generate button --
	_generate_btn = Button.new()
	_generate_btn.text = "Generate Avatar"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_btn)

	# -- Status --
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 9)
	_status_label.modulate = Color(0.7, 0.9, 0.7)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

	# -- Preview --
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(160, 160)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_rect.visible = false
	vbox.add_child(_preview_rect)

	# -- Save button --
	_save_btn = Button.new()
	_save_btn.text = "Dung lam Avatar"
	_save_btn.visible = false
	_save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(_save_btn)

# ─────────────────────────────────────────────
# Portrait hien tai
# ─────────────────────────────────────────────
func _refresh_current_portrait() -> void:
	var tex := ProfilePicture.base64_to_texture(PlayerData.avatar_portrait_base64)
	_current_portrait_rect.texture = tex

# ─────────────────────────────────────────────
# File picker qua JS bridge
# ─────────────────────────────────────────────
func _on_upload_pressed() -> void:
	if not OS.has_feature("web"):
		_set_status("Chi hoat dong tren Web build", false)
		return

	# Inject hidden file input vao DOM. Data duoc doc ve window vars (khong inject vao string).
	JavaScriptBridge.eval("""
		(function() {
			var old = document.getElementById('_zps_file_input');
			if (old) old.remove();
			var inp = document.createElement('input');
			inp.type = 'file';
			inp.id = '_zps_file_input';
			inp.accept = 'image/jpeg,image/png,image/webp';
			inp.style.display = 'none';
			document.body.appendChild(inp);
			inp.addEventListener('change', function(e) {
				var file = e.target.files[0];
				if (!file) return;
				if (file.size > 5 * 1024 * 1024) {
					window._zps_file_error = 'File qua lon (toi da 5MB)';
					window._zps_file_ready = false;
					return;
				}
				var reader = new FileReader();
				reader.onload = function(ev) {
					var dataUrl = ev.target.result;
					window._zps_file_base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
					window._zps_file_mime = file.type;
					window._zps_file_name = file.name;
					window._zps_file_ready = true;
					window._zps_file_error = null;
				};
				reader.readAsDataURL(file);
			});
			inp.click();
		})();
	""")

	_upload_label.text = "Dang doi chon file..."
	_poll_timer = null
	_poll_file()

# ─────────────────────────────────────────────
# Poll file ready
# ─────────────────────────────────────────────
func _poll_file() -> void:
	var error_val = JavaScriptBridge.eval("window._zps_file_error || null")
	if error_val != null and str(error_val) != "null":
		_upload_label.text = "Loi: " + str(error_val)
		_upload_label.modulate = Color(1.0, 0.4, 0.4)
		JavaScriptBridge.eval("window._zps_file_error = null;")
		return

	var ready_val = JavaScriptBridge.eval("!!window._zps_file_ready")
	if not (ready_val is bool and ready_val == true):
		_poll_timer = get_tree().create_timer(0.3)
		_poll_timer.timeout.connect(_poll_file)
		return

	_selected_image_base64 = str(JavaScriptBridge.eval("window._zps_file_base64 || ''"))
	_selected_mime = str(JavaScriptBridge.eval("window._zps_file_mime || 'image/png'"))
	var fname := str(JavaScriptBridge.eval("window._zps_file_name || 'anh'"))
	JavaScriptBridge.eval("window._zps_file_ready = false;")

	_upload_label.text = fname
	_upload_label.modulate = Color(0.6, 1.0, 0.6)
	_generate_btn.disabled = false
	_set_status("Anh san sang. Chon style va nhan Generate!", true)

# ─────────────────────────────────────────────
# Style selection
# ─────────────────────────────────────────────
func _on_style_selected(style_id: String, pressed_btn: Button) -> void:
	_selected_style = style_id
	for child in _style_group.get_children():
		if child is Button and child != pressed_btn:
			child.button_pressed = false
	pressed_btn.button_pressed = true

# ─────────────────────────────────────────────
# Generate via JS fetch
# ─────────────────────────────────────────────
func _on_generate_pressed() -> void:
	if _selected_image_base64.is_empty() or _is_generating:
		return
	_is_generating = true
	_generate_btn.disabled = true
	_set_status("Dang tao avatar... (co the mat 10-30 giay)", true)
	_preview_rect.visible = false
	_save_btn.visible = false

	# Truyen data len window vars truoc (dung JSON.stringify de escape an toan)
	# Script fetch duoi day doc tu window vars, khong nhan input truc tiep
	JavaScriptBridge.eval("window._zps_upload_b64 = " + JSON.stringify(_selected_image_base64) + ";")
	JavaScriptBridge.eval("window._zps_upload_mime = " + JSON.stringify(_selected_mime) + ";")
	JavaScriptBridge.eval("window._zps_gen_style = " + JSON.stringify(_selected_style) + ";")
	JavaScriptBridge.eval("window._zps_api_auth = " + JSON.stringify(API_AUTH) + ";")
	JavaScriptBridge.eval("window._zps_api_gen = " + JSON.stringify(API_GENERATE) + ";")
	JavaScriptBridge.eval("window._zps_api_pwd = " + JSON.stringify(API_PASSWORD) + ";")
	JavaScriptBridge.eval("window._zps_gen_done = false; window._zps_gen_result = null; window._zps_gen_error = null;")

	# Script fetch: doc tat ca config tu window vars, khong co user input trong string
	JavaScriptBridge.eval("""
		(async function() {
			try {
				await fetch(window._zps_api_auth, {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ password: window._zps_api_pwd })
				});
				var byteStr = atob(window._zps_upload_b64);
				var ab = new ArrayBuffer(byteStr.length);
				var ia = new Uint8Array(ab);
				for (var i = 0; i < byteStr.length; i++) ia[i] = byteStr.charCodeAt(i);
				var blob = new Blob([ab], { type: window._zps_upload_mime });
				var fd = new FormData();
				fd.append('image', blob, 'photo.jpg');
				fd.append('style', window._zps_gen_style);
				var resp = await fetch(window._zps_api_gen, { method: 'POST', body: fd });
				if (!resp.ok) throw new Error('HTTP ' + resp.status);
				var data = await resp.json();
				window._zps_gen_result = data.imageBase64 || null;
				window._zps_gen_done = true;
			} catch(e) {
				window._zps_gen_error = String(e.message || e);
				window._zps_gen_done = true;
			}
		})();
	""")

	_poll_generate()

# ─────────────────────────────────────────────
# Poll generate result
# ─────────────────────────────────────────────
func _poll_generate() -> void:
	var done_val = JavaScriptBridge.eval("!!window._zps_gen_done")
	if not (done_val is bool and done_val == true):
		var t := get_tree().create_timer(1.0)
		t.timeout.connect(_poll_generate)
		return

	var err_val = JavaScriptBridge.eval("window._zps_gen_error || null")
	if err_val != null and str(err_val) != "null":
		_set_status("Loi: " + str(err_val), false)
		_finish_generate(false)
		return

	var b64_val = JavaScriptBridge.eval("window._zps_gen_result || null")
	JavaScriptBridge.eval("window._zps_gen_done = false;")
	if b64_val == null or str(b64_val) == "null":
		_set_status("Khong nhan duoc ket qua tu API", false)
		_finish_generate(false)
		return

	_result_base64 = str(b64_val)
	var tex := ProfilePicture.base64_to_texture(_result_base64)
	if tex == null:
		_set_status("Khong the doc anh tra ve", false)
		_finish_generate(false)
		return

	_preview_rect.texture = tex
	_preview_rect.visible = true
	_save_btn.visible = true
	_set_status("Avatar da tao xong! Nhan 'Dung lam Avatar' de luu.", true)
	_finish_generate(true)

func _finish_generate(ok: bool) -> void:
	_is_generating = false
	_generate_btn.disabled = false

# ─────────────────────────────────────────────
# Save
# ─────────────────────────────────────────────
func _on_save_pressed() -> void:
	if _result_base64.is_empty():
		return
	PlayerData.set_portrait(_result_base64, _selected_style)
	_refresh_current_portrait()
	GameManager.notify("AI Avatar da luu!", "success")
	_save_btn.visible = false
	_set_status("Da luu lam portrait chinh thuc!", true)

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
func _set_status(msg: String, ok: bool) -> void:
	_status_label.text = msg
	_status_label.modulate = Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.4)
