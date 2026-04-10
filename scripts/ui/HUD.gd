## HUD.gd
## Main heads-up display — builds all UI nodes programmatically
## Prototype-safe: no missing node errors, everything created in _ready()

extends CanvasLayer

const _AR = preload("res://scripts/world/AvatarRenderer.gd")

# ── Runtime panel references (created in _ready) ──
var workspace_panel: Control = null
var avatar_customizer: Control = null
var interaction_dialog: Control = null
var notification_stack: VBoxContainer = null
var player_card: PanelContainer = null
var pc_name: Label = null
var pc_title: Label = null
var pc_class: Label = null
var pc_outfit: Label = null
# ── Minimap ──
var _minimap_container: Control = null
var _minimap_player_dot: Control = null
var _minimap_map_area: Control = null          # container for dots
var _minimap_npc_dots: Dictionary = {}         # emp_id → ColorRect
var _minimap_cam_rect: Panel = null            # RTS-style camera viewport rect

# ── Zone indicator ──
var _zone_label: Label = null
var _last_zone: String = ""

# ── Help button + popup ──
var _help_popup: Control = null
var _help_popup_open: bool = false
var _help_backdrop: Control = null

# ── Sprint/task indicator (top bar) ──
var _sprint_label: Label = null

# ── Interaction context ──
var current_employee_node: Node = null
var current_player_ref: Node = null

# ── Char-profile panel ──
var _char_profile_panel: Control = null
var _char_gen_panel: Control = null

# ── AI Avatar Maker — iframe overlay ──
var _avatar_maker_panel: Control = null   # desktop fallback only
var _avatar_iframe_created: bool = false
var _avatar_iframe_visible: bool = false

# ── Workspace tab reference (for programmatic tab switching) ──
var _workspace_tabs: TabContainer = null

# ── Web Chat Panel (C key — iframe embed) ──
var web_chat_panel: Control = null
var _web_is_platform: bool = false
var _web_chat_iframe_created: bool = false
var _chat_box: Control = null # desktop chat panel box (for slide animation)

# ── In-game ChatLog reference ──
var _chat_log_node: Control = null

# ── Online roster ──
var _roster_panel: Control = null
var _roster_list: VBoxContainer = null
var _roster_toggle_btn: Button = null
var _roster_open: bool = false
var _roster_backdrop: Control = null

# ── Sprint 4 additions ──
var _emote_menu: Control = null
var _emote_toast_stack: VBoxContainer = null

# ── Mobile / touch detection ──
var _is_mobile: bool = false
var _hud_built: bool = false

# ── Minimap layout constants (mirrors ZPS_Layout_Campus.png 1193×896 px) ──
const _MINIMAP_W: int = 1193 # world pixels (map width)
const _MINIMAP_H: int = 896 # world pixels (map height)
const _MAP_PX_W: int = 192 # minimap display width in UI pixels
const _MAP_PX_H: int = 144 # minimap display height (192 * 896/1193 ≈ 144)

# Zone overlay colors for minimap fallback (pixel-space)
const _ZONE_COLORS: Dictionary = {
	"engineering":       Color(0.10, 0.18, 0.36, 0.55),
	"design_studio":     Color(0.12, 0.28, 0.12, 0.40),
	"amenity":           Color(0.10, 0.28, 0.18, 0.55),
	"library":           Color(0.26, 0.12, 0.34, 0.55),
	"collab_hub":        Color(0.18, 0.22, 0.36, 0.55),
	"facilities":        Color(0.20, 0.20, 0.14, 0.55),
	"data_lab":          Color(0.14, 0.14, 0.26, 0.55),
	"reception":         Color(0.30, 0.18, 0.10, 0.55),
	"innovation_corner": Color(0.28, 0.22, 0.10, 0.55),
	"marketing_hub":     Color(0.14, 0.14, 0.18, 0.40),
}

# Zone pixel-space rects — must match _zones in Campus.gd (1193×896 px)
const _ZONE_RECTS: Dictionary = {
	"engineering":       Rect2(15,   340, 460, 535),
	"design_studio":     Rect2(15,   20,  435, 315),
	"amenity":           Rect2(460,  20,  300, 190),
	"library":           Rect2(460,  215, 295, 145),
	"collab_hub":        Rect2(460,  370, 300, 505),
	"facilities":        Rect2(760,  15,  420, 190),
	"data_lab":          Rect2(760,  210, 420, 205),
	"reception":         Rect2(760,  420, 280, 250),
	"innovation_corner": Rect2(1045, 420, 135, 250),
	"marketing_hub":     Rect2(760,  675, 420, 200),
}

const _ZONE_DISPLAY_NAMES: Dictionary = {
	"engineering":       "Engineering Floor",
	"design_studio":     "Design & Product Studio",
	"amenity":           "Amenity Center",
	"library":           "Library & Research",
	"collab_hub":        "Collaboration Hub",
	"facilities":        "Facilities & Logistics",
	"data_lab":          "Data Lab",
	"reception":         "Reception & Innovation",
	"innovation_corner": "Innovation Corner",
	"marketing_hub":     "Marketing Hub",
}

func _js_query(code: String) -> Variant:
	# Safe wrapper: returns null if not web or if JS bridge is unavailable
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.eval(code)

func _ready() -> void:
	add_to_group("hud")
	print("[HUD] _ready() start")
	call_deferred("_init_hud")

# Fallback: if call_deferred doesn't fire (rare edge case without gdextensions),
# _process guarantees init runs on first game loop tick.
func _process(_delta: float) -> void:
	if not _hud_built:
		_init_hud()
	set_process(false)

func _init_hud() -> void:
	if _hud_built:
		return
	_hud_built = true
	# Mobile detection — must happen before _build_ui() so layout can use _is_mobile
	var mw = _js_query("window.innerWidth||screen.width||0")
	var has_touch = _js_query("('ontouchstart' in window)||navigator.maxTouchPoints>0")
	_is_mobile = (mw is float and (mw as float) < 900.0) or has_touch == true
	print("[HUD] mobile=%s mw=%s" % [_is_mobile, mw])
	_build_ui()
	_update_player_card()

	GameManager.notification_received.connect(_on_notification)
	GameManager.avatar_updated.connect(func(_id, _cfg): _update_player_card())
	GameManager.room_booked.connect(func(room_id, slot, _b):
		_on_notification("Phong %s dat luc %s [v]" % [room_id, slot], "success")
	)
	AIAgent.response_ready.connect(_on_ai_response)
	AIAgent.response_error.connect(_on_ai_error)
	_build_roster_panel()
	# Chat log panel
	var chat_log_scene = load("res://scripts/ui/ChatLog.gd")
	_chat_log_node = chat_log_scene.new()
	add_child(_chat_log_node)
	NetworkManager.emote_received.connect(_on_emote_toast)

	# Always refresh UI on (re-)login — covers both first-login and logout→re-login
	PlayerData.login_complete.connect(_on_login_complete_refresh_ui)

	# ── Login dialog — shown on top of everything if not yet logged in ──
	if not PlayerData.is_logged_in:
		print("[HUD] Showing LoginDialog")
		var dialog := LoginDialog.new()
		add_child(dialog)
	else:
		print("[HUD] Already logged in — skip LoginDialog")

# ─────────────────────────────────────────────
# Build all UI programmatically
# ─────────────────────────────────────────────
func _build_ui() -> void:
	_build_player_card()
	_build_zone_indicator()
	_build_sprint_indicator()
	_build_help_button()
	_build_notification_stack()
	_build_minimap()
	_build_ai_chat_bar()
	_build_workspace_panel()
	_build_web_chat_panel()
	_build_avatar_customizer()
	_build_interaction_dialog()
	_build_char_profile_panel()
	_build_emote_toast_area()

# ── Player card (top-left) ──
var _pc_portrait: TextureRect = null # portrait slot trong player card

func _build_player_card() -> void:
	player_card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.88)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.5)
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 8; style.content_margin_bottom = 8
	player_card.add_theme_stylebox_override("panel", style)
	player_card.position = Vector2(12, 12)
	player_card.custom_minimum_size = Vector2(180, 0)
	if _is_mobile:
		player_card.custom_minimum_size = Vector2(260, 0)

	# Layout ngang: portrait ben trai + info ben phai
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	_pc_portrait = TextureRect.new()
	_pc_portrait.custom_minimum_size = Vector2(40, 40)
	_pc_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pc_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pc_portrait.size = Vector2(40, 40)
	_pc_portrait.visible = false
	hbox.add_child(_pc_portrait)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc_name = _make_label("", 13 if not _is_mobile else 20, Color.WHITE, true)
	pc_title = _make_label("", 9 if not _is_mobile else 15, Color(0.7, 0.7, 0.7))
	pc_class = _make_label("", 9 if not _is_mobile else 15, Color(0.7, 0.6, 1.0))
	pc_outfit = _make_label("", 9 if not _is_mobile else 15, Color(0.6, 0.9, 0.6))
	vbox.add_child(pc_name); vbox.add_child(pc_title)
	vbox.add_child(pc_class); vbox.add_child(pc_outfit)
	hbox.add_child(vbox)
	player_card.add_child(hbox)

	# Invisible click-to-open button overlay
	var click_btn = Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.pressed.connect(_toggle_char_profile)
	player_card.add_child(click_btn)

	add_child(player_card)

# ── Zone indicator (below player card) ──
func _build_zone_indicator() -> void:
	var container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.80)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.35, 0.55)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 5; style.content_margin_bottom = 5
	container.add_theme_stylebox_override("panel", style)
	container.position = Vector2(12, 0) # y set in _process after player card laid out

	_zone_label = _make_label("Office", 10, Color(0.75, 0.88, 1.0))
	container.add_child(_zone_label)
	container.name = "ZoneIndicator"
	add_child(container)

# ── Sprint/task top bar ──
func _build_sprint_indicator() -> void:
	var container = PanelContainer.new()
	container.anchor_left = 0.5; container.anchor_right = 0.5
	container.anchor_top = 0.0; container.anchor_bottom = 0.0
	# Mobile: narrower to avoid overlapping the button column on the right
	var hw := 100 if _is_mobile else 200
	container.offset_left = -hw; container.offset_right = hw
	container.offset_top = 8; container.offset_bottom = 34

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.18, 0.80)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.55)
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 4; style.content_margin_bottom = 4
	container.add_theme_stylebox_override("panel", style)

	_sprint_label = _make_label("", 10 if not _is_mobile else 15, Color(0.85, 0.80, 0.50))
	_sprint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sprint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_sprint_label)
	container.name = "SprintIndicator"
	add_child(container)
	_refresh_sprint_label()

# ── Help button (bottom-center "?" → expands popup) ──
func _build_help_button() -> void:
	# "?" toggle button — added first so popup/backdrop render above it
	var btn_anchor = Control.new()
	btn_anchor.anchor_left = 0.5; btn_anchor.anchor_right = 0.5
	btn_anchor.anchor_top = 1.0; btn_anchor.anchor_bottom = 1.0
	if _is_mobile:
		btn_anchor.offset_left = -32; btn_anchor.offset_right = 32
		btn_anchor.offset_top = -72; btn_anchor.offset_bottom = -8
	else:
		btn_anchor.offset_left = -18; btn_anchor.offset_right = 18
		btn_anchor.offset_top = -40; btn_anchor.offset_bottom = -8

	var btn = Button.new()
	btn.text = "?"
	if _is_mobile:
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_theme_font_size_override("font_size", 22)
	else:
		btn.size = Vector2(36, 32)
		btn.add_theme_font_size_override("font_size", 16)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.12, 0.12, 0.22, 0.90)
	bs.set_corner_radius_all(8); bs.set_border_width_all(1)
	bs.border_color = Color(0.4, 0.4, 0.6)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	btn.pressed.connect(func():
		_help_popup_open = not _help_popup_open
		_help_popup.visible = _help_popup_open
		_help_backdrop.visible = _help_popup_open
	)
	btn_anchor.add_child(btn)
	add_child(btn_anchor)

	# Backdrop for click-outside — added after button, before popup
	_help_backdrop = Control.new()
	_help_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_backdrop.visible = false
	_help_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_help_popup_open = false
			_help_popup.visible = false
			_help_backdrop.visible = false
	)
	add_child(_help_backdrop)

	# Popup panel — added last so it renders on top of backdrop and button
	_help_popup = PanelContainer.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.12, 0.93)
	ps.set_corner_radius_all(8); ps.set_border_width_all(1)
	ps.border_color = Color(0.3, 0.3, 0.5)
	ps.content_margin_left = 14; ps.content_margin_right = 14
	ps.content_margin_top = 10; ps.content_margin_bottom = 10
	_help_popup.add_theme_stylebox_override("panel", ps)
	_help_popup.anchor_left = 0.5; _help_popup.anchor_right = 0.5
	_help_popup.anchor_top = 1.0; _help_popup.anchor_bottom = 1.0
	_help_popup.offset_left = -150; _help_popup.offset_right = 150
	_help_popup.offset_top = -170; _help_popup.offset_bottom = -46
	_help_popup.visible = false

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	var controls: Array = [
		["Click", "Di chuyển / Talk"],
		["WASD / Arrow", "Di chuyển"],
		["E", "Tương tác"],
		["H", "Mở Workspace"],
		["C", "Mở Chat"],
		["Shift+A", "Avatar"],
		["RMB+Drag", "Pan Camera"],
		["Scroll", "Zoom"],
		["F", "Focus Player"],
	]
	for row: Array in controls:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var key_lbl = _make_label("[%s]" % row[0], 9, Color(0.9, 0.85, 0.4))
		key_lbl.custom_minimum_size = Vector2(90, 0)
		var act_lbl = _make_label(row[1], 9, Color(0.8, 0.8, 0.9))
		hbox.add_child(key_lbl)
		hbox.add_child(act_lbl)
		vbox.add_child(hbox)
	_help_popup.add_child(vbox)
	add_child(_help_popup)

# ── Minimap (bottom-right, 120×96 px) ──
func _build_minimap() -> void:
	_minimap_container = Control.new()
	_minimap_container.anchor_left = 1.0; _minimap_container.anchor_right = 1.0
	_minimap_container.anchor_top = 1.0; _minimap_container.anchor_bottom = 1.0
	_minimap_container.offset_left = -(_MAP_PX_W + 20)
	_minimap_container.offset_right = -12
	_minimap_container.offset_top = -(_MAP_PX_H + 20)
	_minimap_container.offset_bottom = -12

	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.10, 0.88)
	bg.size = Vector2(_MAP_PX_W + 8, _MAP_PX_H + 8)
	_minimap_container.add_child(bg)

	# Border panel
	var border = PanelContainer.new()
	border.position = Vector2(0, 0)
	border.custom_minimum_size = Vector2(_MAP_PX_W + 8, _MAP_PX_H + 8)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0, 0, 0, 0)
	bs.set_border_width_all(1)
	bs.border_color = Color(0.8, 0.8, 0.9, 0.4)
	bs.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", bs)
	_minimap_container.add_child(border)

	# Map area (clipping container)
	var map_area = Control.new()
	map_area.position = Vector2(4, 4)
	map_area.size = Vector2(_MAP_PX_W, _MAP_PX_H)
	map_area.clip_contents = true

	# Draw campus PNG scaled to minimap size — anchor FULL_RECT so Godot layout
	# enforces the Control size on the TextureRect (plain .size = won't work in Control parent)
	const _CAMPUS_IMG := "res://assets/maps/ZPS_Layout_Campus.png"
	var map_tex_rect := TextureRect.new()
	map_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)  # fill map_area exactly
	map_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE       # scale full image to fit
	map_tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE  # allow shrinking below natural size
	map_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Load with fallback (PNG may not be imported yet)
	var campus_tex: Texture2D = null
	if ResourceLoader.exists(_CAMPUS_IMG):
		campus_tex = load(_CAMPUS_IMG) as Texture2D
	if campus_tex == null:
		var abs_campus := ProjectSettings.globalize_path(_CAMPUS_IMG)
		if FileAccess.file_exists(abs_campus):
			var img := Image.load_from_file(abs_campus)
			if img:
				campus_tex = ImageTexture.create_from_image(img)
	map_tex_rect.texture = campus_tex
	map_area.add_child(map_tex_rect)

	_minimap_map_area = map_area

	# ── RTS camera viewport rect ──
	_minimap_cam_rect = Panel.new()
	_minimap_cam_rect.z_index = 8
	var cam_style := StyleBoxFlat.new()
	cam_style.bg_color        = Color(1.0, 1.0, 1.0, 0.08)   # very subtle fill
	cam_style.set_border_width_all(1)
	cam_style.border_color    = Color(1.0, 1.0, 0.6, 0.90)   # bright yellow border
	_minimap_cam_rect.add_theme_stylebox_override("panel", cam_style)
	map_area.add_child(_minimap_cam_rect)

	# Player dot — bright cyan, 6×6 px, on top of camera rect
	_minimap_player_dot = ColorRect.new()
	_minimap_player_dot.color = Color(0.2, 1.0, 0.8)
	_minimap_player_dot.size = Vector2(6, 6)
	_minimap_player_dot.position = Vector2(0, 0)
	_minimap_player_dot.z_index = 10
	map_area.add_child(_minimap_player_dot)

	_minimap_container.add_child(map_area)
	add_child(_minimap_container)

# ── Notification stack (top-right) ──
func _build_notification_stack() -> void:
	var anchor = Control.new()
	anchor.anchor_left = 1.0; anchor.anchor_right = 1.0
	anchor.anchor_top = 0.0; anchor.anchor_bottom = 0.0
	anchor.offset_left = -306; anchor.offset_right = -8
	anchor.offset_top = 12

	notification_stack = VBoxContainer.new()
	notification_stack.size = Vector2(300, 400)
	notification_stack.add_theme_constant_override("separation", 6)
	anchor.add_child(notification_stack)
	add_child(anchor)

# ── AI Chat Bar (right side, collapsible) ──
var _ai_bar_open: bool = false
var _ai_bar_panel: Control = null
var _ai_bar_log: VBoxContainer = null
var _ai_bar_backdrop: Control = null

# ── Nút ✕ thống nhất cho mọi panel ──
func _make_x_btn(on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = "✕"
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.28, 0.06, 0.06, 0.85)
	st.set_corner_radius_all(5); st.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", st)
	var st_hov := StyleBoxFlat.new()
	st_hov.bg_color = Color(0.65, 0.08, 0.08); st_hov.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.pressed.connect(on_press)
	return btn

# ── Đóng AI / Workspace / Online — chỉ 1 cửa sổ mở 1 lúc ──
func _close_side_panels() -> void:
	if _ai_bar_open:
		_ai_bar_open = false
		if _ai_bar_panel:    _ai_bar_panel.visible    = false
		if _ai_bar_backdrop: _ai_bar_backdrop.visible = false
	if workspace_panel and workspace_panel.visible:
		workspace_panel.visible = false
		if current_player_ref: current_player_ref.set_busy(false)
	if _roster_open:
		_roster_open = false
		if _roster_panel:    _roster_panel.visible    = false
		if _roster_backdrop: _roster_backdrop.visible = false

func _build_ai_chat_bar() -> void:
	# Toggle button (top-right)
	# Mobile: vertical stack — AI is slot 3 (below Online=slot1, Chat=slot2)
	# Desktop: horizontal row at y=8..40
	var toggle_anchor = Control.new()
	toggle_anchor.anchor_left = 1.0; toggle_anchor.anchor_right = 1.0
	toggle_anchor.anchor_top = 0.0; toggle_anchor.anchor_bottom = 0.0
	if _is_mobile:
		toggle_anchor.offset_left = -68; toggle_anchor.offset_right = -4
		toggle_anchor.offset_top = 8 + 60 * 2; toggle_anchor.offset_bottom = 8 + 60 * 3
	else:
		toggle_anchor.offset_left = -52; toggle_anchor.offset_right = -8
		toggle_anchor.offset_top = 8; toggle_anchor.offset_bottom = 40
	var toggle_btn = Button.new()
	toggle_btn.text = "[AI]"
	if _is_mobile:
		toggle_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		toggle_btn.add_theme_font_size_override("font_size", 16)
	else:
		toggle_btn.size = Vector2(44, 32)
		toggle_btn.add_theme_font_size_override("font_size", 14)
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.10, 0.10, 0.22, 0.92)
	ts.set_corner_radius_all(8); ts.set_border_width_all(1)
	ts.border_color = Color(0.4, 0.4, 0.7)
	toggle_btn.add_theme_stylebox_override("normal", ts)
	toggle_btn.pressed.connect(_toggle_ai_bar)
	toggle_anchor.add_child(toggle_btn)
	add_child(toggle_anchor)

	# Backdrop — click-outside closes AI panel
	_ai_bar_backdrop = Control.new()
	_ai_bar_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ai_bar_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_ai_bar_backdrop.visible = false
	_ai_bar_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_toggle_ai_bar()
	)
	add_child(_ai_bar_backdrop)

	# Panel
	_ai_bar_panel = Control.new()
	_ai_bar_panel.anchor_left = 1.0; _ai_bar_panel.anchor_right = 1.0
	_ai_bar_panel.anchor_top = 0.0; _ai_bar_panel.anchor_bottom = 1.0
	_ai_bar_panel.offset_left = -300; _ai_bar_panel.offset_right = 0
	_ai_bar_panel.offset_top = 46; _ai_bar_panel.offset_bottom = -200
	_ai_bar_panel.visible = false
	_ai_bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	bg_style.set_corner_radius_all(10); bg_style.set_border_width_all(1)
	bg_style.border_color = Color(0.3, 0.3, 0.6)
	bg_style.content_margin_left = 10; bg_style.content_margin_right = 10
	bg_style.content_margin_top = 8; bg_style.content_margin_bottom = 8
	bg.add_theme_stylebox_override("panel", bg_style)

	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)

	# Header row với nút ✕
	var ai_hdr = HBoxContainer.new()
	var ai_ttl = _make_label("[AI] ZPS AI Assistant", 11, Color(0.7, 0.8, 1.0), true)
	ai_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_hdr.add_child(ai_ttl)
	ai_hdr.add_child(_make_x_btn(_toggle_ai_bar))
	col.add_child(ai_hdr)
	col.add_child(HSeparator.new())

	# Quick actions
	var actions_label = _make_label("Quick actions:", 9, Color(0.5, 0.6, 0.7))
	col.add_child(actions_label)
	var actions = [
		["Tìm nhân viên", "search"],
		["Gọi agent", "agent"],
		["Tạo yêu cầu", "request"],
	]
	for act: Array in actions:
		var qbtn = Button.new(); qbtn.text = act[0]
		var qstyle = StyleBoxFlat.new()
		qstyle.bg_color = Color(0.12, 0.12, 0.24, 0.85)
		qstyle.set_corner_radius_all(6); qstyle.set_border_width_all(1)
		qstyle.border_color = Color(0.25, 0.25, 0.5)
		qbtn.add_theme_stylebox_override("normal", qstyle)
		qbtn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		qbtn.add_theme_font_size_override("font_size", 10)
		var action_type: String = act[1]
		qbtn.pressed.connect(func(): _ai_quick_action(action_type))
		col.add_child(qbtn)

	col.add_child(HSeparator.new())

	# Log area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ai_bar_log = VBoxContainer.new()
	_ai_bar_log.add_theme_constant_override("separation", 4)
	_ai_bar_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ai_bar_log)
	col.add_child(scroll)

	# Input
	var inp_row = HBoxContainer.new(); inp_row.add_theme_constant_override("separation", 4)
	var ai_input = LineEdit.new(); ai_input.name = "AIInput"
	ai_input.placeholder_text = "Nhập yêu cầu..."
	ai_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ai_send = Button.new(); ai_send.text = "▶"
	var ai_send_style = StyleBoxFlat.new()
	ai_send_style.bg_color = Color(0.2, 0.4, 0.8, 0.9)
	ai_send_style.set_corner_radius_all(6)
	ai_send.add_theme_stylebox_override("normal", ai_send_style)
	ai_send.pressed.connect(func(): _ai_bar_send(ai_input))
	ai_input.text_submitted.connect(func(_t): _ai_bar_send(ai_input))
	inp_row.add_child(ai_input); inp_row.add_child(ai_send)
	col.add_child(inp_row)

	# API key note
	var api_note = _make_label(" Claude API: connected (claude-haiku-4-5)", 8, Color(0.4, 0.8, 0.5))
	api_note.name = "APIKeyNote"
	col.add_child(api_note)

	bg.add_child(col)
	_ai_bar_panel.add_child(bg)
	add_child(_ai_bar_panel)

	# System welcome message
	_ai_log_msg("AI Assistant đã sẵn sàng. Bạn cần giúp gì?", false)
	_ai_log_msg(" Thử: 'Tìm Hiếu PT', 'Tạo task mới', 'Xem sprint hiện tại'", false)

func _ai_log_msg(text: String, is_user: bool) -> void:
	if _ai_bar_log == null: return
	var lbl = _make_label(("Bạn: " if is_user else "AI: ") + text, 9,
		Color(0.9, 0.95, 1.0) if is_user else Color(0.7, 0.85, 0.7))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ai_bar_log.add_child(lbl)

func _ai_bar_send(input: LineEdit) -> void:
	var msg: String = input.text.strip_edges()
	if msg.is_empty(): return
	input.clear()
	_ai_log_msg(msg, true)
	AIAgent.ask_workspace_assistant(msg)

func _on_ai_response(response: String, context_id: String) -> void:
	if not context_id.begins_with("workspace_"): return
	_ai_log_msg(response, false)

func _on_ai_error(error: String, context_id: String) -> void:
	if not context_id.begins_with("workspace_"): return
	_ai_log_msg("[!] " + error, false)

func _ai_quick_action(action: String) -> void:
	match action:
		"search":
			_ai_log_msg("Tìm kiếm nhân viên: nhập tên vào ô bên dưới", false)
		"agent":
			_ai_log_msg("Gọi agent: đang kết nối Claude API...", false)
			AIAgent.ask_workspace_assistant("Tôi có thể làm gì hôm nay?")
		"request":
			# Open workspace panel at tab 0 (Book Room) for general requests
			_open_workspace_at_tab(0)
			return
		"leave":
			# Xin nghỉ: open workspace panel at tab 3 (last tab)
			_open_workspace_at_tab(3)
			return

func _open_workspace_at_tab(tab_idx: int) -> void:
	if workspace_panel == null: return
	workspace_panel.visible = true
	if current_player_ref: current_player_ref.set_busy(true)
	if _workspace_tabs != null:
		_workspace_tabs.current_tab = tab_idx

# ── Web Chat Panel (C key — workspace.zingplay.com/chat iframe) ──
func _build_web_chat_panel() -> void:
	_web_is_platform = OS.get_name() == "Web"

	# Full-screen Control — blocks click-through when open
	web_chat_panel = Control.new()
	web_chat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	web_chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	web_chat_panel.visible = false

	# Semi-transparent backdrop — captures clicks outside the chat panel
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_close_web_chat_slide()
	)
	web_chat_panel.add_child(backdrop)

	# Desktop fallback: shown only when NOT web export
	if not _web_is_platform:
		var box := PanelContainer.new()
		box.anchor_left = 1.0; box.anchor_right = 1.0
		box.anchor_top = 0.0; box.anchor_bottom = 1.0
		box.offset_left = 0; box.offset_right = 0 # start off-screen (right), animated on open
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.10, 0.18, 0.96)
		style.set_corner_radius_all(0)
		box.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = "Chat: workspace.zingplay.com/chat\n\n(iframe chi hoat dong khi chay web export)"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95))
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_child(lbl)
		web_chat_panel.add_child(box)
		_chat_box = box

	add_child(web_chat_panel)

	# Toggle button — Mobile: vertical stack slot 2; Desktop: left of [AI]
	var anchor := Control.new()
	anchor.anchor_left = 1.0; anchor.anchor_right = 1.0
	anchor.anchor_top = 0.0; anchor.anchor_bottom = 0.0
	if _is_mobile:
		anchor.offset_left = -68; anchor.offset_right = -4
		anchor.offset_top = 8 + 60; anchor.offset_bottom = 8 + 60 * 2
	else:
		anchor.offset_left = -98; anchor.offset_right = -54
		anchor.offset_top = 8; anchor.offset_bottom = 40

	var btn := Button.new()
	btn.tooltip_text = "Workspace Chat"
	if _is_mobile:
		btn.text = ""
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_theme_font_size_override("font_size", 18)
	else:
		btn.text = ""
		btn.size = Vector2(44, 32)
		btn.add_theme_font_size_override("font_size", 14)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.10, 0.14, 0.22, 0.92)
	bs.set_corner_radius_all(8); bs.set_border_width_all(1)
	bs.border_color = Color(0.3, 0.5, 0.7)
	btn.add_theme_stylebox_override("normal", bs)
	btn.pressed.connect(_toggle_web_chat_panel)
	anchor.add_child(btn)
	add_child(anchor)

# ── Workspace Panel (H key) ──
func _build_workspace_panel() -> void:
	workspace_panel = load("res://scripts/ui/WorkspacePanel.gd").new() if false else _create_workspace_panel_inline()
	workspace_panel.visible = false
	add_child(workspace_panel)

func _create_workspace_panel_inline() -> Control:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "WorkspacePanelRoot"

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)
	bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_toggle_workspace_panel()
	)
	root.add_child(bg)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -340; panel.offset_right = 340
	panel.offset_top = -260; panel.offset_bottom = 260
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.1, 0.18)
	ps.set_corner_radius_all(12); ps.set_border_width_all(1)
	ps.border_color = Color(0.3, 0.3, 0.5)
	panel.add_theme_stylebox_override("panel", ps)

	var vbox = VBoxContainer.new()

	# Header
	var header = HBoxContainer.new()
	var title = _make_label(" Workspace Panel", 16, Color(0.9, 0.8, 0.5), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_make_x_btn(func(): _toggle_workspace_panel()))
	vbox.add_child(header)

	# Separator
	vbox.add_child(HSeparator.new())

	# Tab container
	var tabs = TabContainer.new()
	tabs.name = "WorkspaceTabs"
	tabs.custom_minimum_size = Vector2(0, 360)
	_workspace_tabs = tabs

	# ── Tab 1: Book Room ──
	var book_tab = _build_book_room_tab()
	book_tab.name = "Đặt Phòng"
	tabs.add_child(book_tab)

	# ── Tab 1: Sprint ──
	var sprint_tab = _build_sprint_tab()
	sprint_tab.name = " Sprint"
	tabs.add_child(sprint_tab)

	# ── Tab 2: AI Assistant ──
	var ai_tab = _build_ai_tab()
	ai_tab.name = "[AI] AI Hỏi Đáp"
	tabs.add_child(ai_tab)

	# ── Tab 3: My Tasks ──
	var task_tab = _build_task_tab()
	task_tab.name = "Tasks"
	tabs.add_child(task_tab)

	# ── Tab 4: Leave ──
	var leave_tab = _build_leave_tab()
	leave_tab.name = "Xin Nghỉ"
	tabs.add_child(leave_tab)

	vbox.add_child(tabs)
	panel.add_child(vbox)
	root.add_child(panel)
	return root

func _build_book_room_tab() -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_make_label("Chọn phòng họp:", 11, Color(0.8, 0.8, 0.9)))

	# Time slot selector
	tab.add_child(_make_label("Ngày:", 10, Color(0.7, 0.7, 0.8)))
	var date_field := LineEdit.new()
	date_field.text = Time.get_date_string_from_system()
	date_field.placeholder_text = "YYYY-MM-DD"
	tab.add_child(date_field)

	tab.add_child(_make_label("Khung giờ:", 10, Color(0.7, 0.7, 0.8)))
	var slot_opt := OptionButton.new()
	for s: String in ["09:00-10:00", "10:00-11:00", "13:00-14:00", "14:00-15:00", "15:00-16:00"]:
		slot_opt.add_item(s)
	tab.add_child(slot_opt)

	var result_lbl := _make_label("", 11, Color.GREEN)
	result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for room_id: String in GameManager.meeting_rooms:
		var room: Dictionary = GameManager.meeting_rooms[room_id]
		var btn := Button.new()
		btn.text = "%s — %d người | %s" % [
			room["name"],
			room.get("capacity", 0),
			", ".join(room.get("equipment", [])),
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func():
			result_lbl.text = "Đang đặt..."
			result_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))

			if HttpManager.jwt_token.is_empty():
				# Offline fallback
				var ok := GameManager.book_room(room_id, slot_opt.get_item_text(slot_opt.selected), PlayerData.player_id)
				result_lbl.text = "[v] Đã đặt %s!" % room["name"] if ok else "[x] Slot đã bị đặt rồi!"
				result_lbl.add_theme_color_override("font_color", Color.GREEN if ok else Color(1.0, 0.4, 0.4))
				return

			var payload := {
				"date": date_field.text,
				"time_slot": slot_opt.get_item_text(slot_opt.selected),
				"booker_id": PlayerData.player_id,
			}
			var ep := "rooms/%s/book" % room_id
			HttpManager.post(ep, payload)

			HttpManager.response_received.connect(
				func(endpoint: String, data: Variant):
					if endpoint != ep:
						return
					if data is Dictionary and (data as Dictionary).get("success", false):
						result_lbl.text = "[v] Đã đặt %s lúc %s!" % [room["name"], payload["time_slot"]]
						result_lbl.add_theme_color_override("font_color", Color.GREEN)
						GameManager.notify("Phòng %s đã đặt lúc %s [v]" % [room["name"], payload["time_slot"]], "success")
					else:
						var err_msg: String = ""
						if data is Dictionary:
							err_msg = (data as Dictionary).get("error", "Lỗi không xác định")
						result_lbl.text = "[x] %s" % err_msg
						result_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)),
				CONNECT_ONE_SHOT
			)
			HttpManager.error.connect(
				func(endpoint: String, msg: String):
					if endpoint != ep:
						return
					result_lbl.text = "[x] Lỗi đặt phòng: %s" % msg
					result_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)),
				CONNECT_ONE_SHOT
			)
		)
		tab.add_child(btn)

	tab.add_child(result_lbl)
	return tab

func _build_leave_tab() -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_make_label("Loại nghỉ:", 11, Color(0.8, 0.8, 0.9)))

	var type_opt := OptionButton.new()
	for t: String in ["Nghỉ phép năm", "Nghỉ ốm", "Nghỉ không lương", "Nghỉ đặc biệt"]:
		type_opt.add_item(t)
	tab.add_child(type_opt)

	tab.add_child(_make_label("Từ ngày:", 11, Color(0.8, 0.8, 0.9)))
	var from_date := LineEdit.new()
	from_date.text = Time.get_date_string_from_system()
	from_date.placeholder_text = "YYYY-MM-DD"
	tab.add_child(from_date)

	tab.add_child(_make_label("Đến ngày:", 11, Color(0.8, 0.8, 0.9)))
	var to_date := LineEdit.new()
	to_date.text = Time.get_date_string_from_system()
	tab.add_child(to_date)

	tab.add_child(_make_label("Lý do:", 11, Color(0.8, 0.8, 0.9)))
	var reason := TextEdit.new()
	reason.custom_minimum_size = Vector2(0, 60)
	tab.add_child(reason)

	var result_lbl := _make_label("", 11, Color.GREEN)
	result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var submit := Button.new()
	submit.text = "Gửi đơn xin nghỉ"

	submit.pressed.connect(func():
		var leave_title: String = "Xin nghỉ: %s (%s → %s)" % [
			type_opt.get_item_text(type_opt.selected),
			from_date.text,
			to_date.text,
		]
		submit.disabled = true
		result_lbl.text = "Đang gửi..."
		result_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))

		if HttpManager.jwt_token.is_empty():
			# Offline mode fallback — call legacy GameManager helper
			GameManager.request_leave({
				"type": type_opt.get_item_text(type_opt.selected),
				"dates": "%s → %s" % [from_date.text, to_date.text],
				"reason": reason.text,
			})
			result_lbl.text = "[v] Đơn đã gửi (offline)! HR sẽ xét duyệt trong 24h."
			result_lbl.add_theme_color_override("font_color", Color.GREEN)
			submit.disabled = false
			return

		var payload := {
			"title": leave_title,
			"assignee_id": PlayerData.player_id,
			"due_date": to_date.text,
		}
		HttpManager.post("tasks", payload)

		var on_resp := func(endpoint: String, _data: Variant) -> void:
			if endpoint != "tasks":
				return
			result_lbl.text = "[v] Đơn đã gửi! HR sẽ xét duyệt trong 24h."
			result_lbl.add_theme_color_override("font_color", Color.GREEN)
			submit.disabled = false

		var on_err := func(endpoint: String, msg: String) -> void:
			if endpoint != "tasks":
				return
			result_lbl.text = "[x] Lỗi gửi đơn: %s" % msg
			result_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			submit.disabled = false

		HttpManager.response_received.connect(on_resp, CONNECT_ONE_SHOT)
		HttpManager.error.connect(on_err, CONNECT_ONE_SHOT)
	)
	tab.add_child(submit)
	tab.add_child(result_lbl)
	return tab

func _build_sprint_tab() -> VBoxContainer:
	var tab = VBoxContainer.new()
	tab.add_theme_constant_override("separation", 10)
	for sprint in GameManager.active_sprints:
		var card = PanelContainer.new()
		var s = StyleBoxFlat.new(); s.bg_color = Color(0.12, 0.15, 0.22); s.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", s)
		var cv = VBoxContainer.new()
		cv.add_child(_make_label(" " + sprint.get("name", "?"), 12, Color.WHITE, true))
		cv.add_child(_make_label("%s · %s" % [sprint.get("team","?"), sprint.get("deadline","?")], 10, Color(0.6,0.6,0.6)))
		var pb = ProgressBar.new(); pb.value = sprint.get("progress", 0.0) * 100
		pb.custom_minimum_size.y = 14; cv.add_child(pb)
		cv.add_child(_make_label("%d / %d tasks" % [sprint.get("tasks_done",0), sprint.get("tasks_total",0)], 10, Color(0.7,0.7,0.7)))
		card.add_child(cv); tab.add_child(card)
	return tab

func _build_ai_tab() -> VBoxContainer:
	var tab = VBoxContainer.new()
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_make_label("Hỏi AI Workspace Assistant:", 11, Color(0.8,0.8,0.9)))
	var resp = _make_label("Nhập câu hỏi bên dưới và nhấn Enter...", 11, Color(0.6,0.6,0.6))
	resp.name = "AIResponse"; resp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resp.custom_minimum_size = Vector2(0, 80)
	tab.add_child(resp)
	var input = LineEdit.new(); input.placeholder_text = "Vd: Phòng Alpha còn trống không?"
	input.text_submitted.connect(func(q):
		resp.text = " Đang hỏi AI..."; resp.modulate = Color.WHITE
		AIAgent.ask_workspace_assistant(q)
		input.clear()
	)
	tab.add_child(input)
	AIAgent.response_ready.connect(func(r, cid):
		if cid.begins_with("workspace_"): resp.text = r
	)
	return tab

# ── Task Panel tab (T shortcut maps to this tab index) ──
func _build_task_tab() -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "TaskTab"
	tab.add_theme_constant_override("separation", 6)

	var header_row := HBoxContainer.new()
	header_row.add_child(_make_label("Công việc của tôi", 12, Color(0.9, 0.85, 0.6), true))
	header_row.add_spacer(false)
	var refresh_btn := Button.new()
	refresh_btn.text = "↻ Tải lại"
	refresh_btn.flat = true
	header_row.add_child(refresh_btn)
	tab.add_child(header_row)

	var status_lbl := _make_label("", 10, Color(0.6, 0.6, 0.6))
	status_lbl.name = "TaskStatusLabel"
	tab.add_child(status_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list := VBoxContainer.new()
	list.name = "TaskList"
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	tab.add_child(scroll)

	# ── Load tasks from REST ──
	var load_tasks := func() -> void:
		if HttpManager.jwt_token.is_empty():
			# Offline: show a placeholder
			status_lbl.text = "(offline — đăng nhập để xem task thật)"
			return
		status_lbl.text = "Đang tải..."
		for child in list.get_children():
			child.queue_free()
		HttpManager.get_request("tasks")

	var on_tasks_loaded: Callable
	var on_tasks_error: Callable

	on_tasks_loaded = func(endpoint: String, data: Variant) -> void:
		if endpoint != "tasks":
			return
		status_lbl.text = ""
		for child in list.get_children():
			child.queue_free()
		if not data is Array or (data as Array).is_empty():
			list.add_child(_make_label("Không có task nào.", 10, Color(0.6, 0.6, 0.6)))
			return
		for item: Variant in data:
			if not item is Dictionary:
				continue
			var task: Dictionary = item
			var card := PanelContainer.new()
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.12, 0.14, 0.22)
			s.set_corner_radius_all(6)
			card.add_theme_stylebox_override("panel", s)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			var status_val: String = task.get("status", "todo")
			var status_color := Color(0.6, 0.6, 0.6)
			match status_val:
				"todo": status_color = Color(0.7, 0.7, 0.35)
				"in-progress": status_color = Color(0.3, 0.7, 1.0)
				"done": status_color = Color(0.3, 0.9, 0.3)
			var status_dot := _make_label("●", 12, status_color)
			row.add_child(status_dot)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(_make_label(task.get("title", "?"), 11, Color.WHITE))
			info.add_child(_make_label("Due: %s" % task.get("due_date", "?"), 9, Color(0.6, 0.6, 0.6)))
			row.add_child(info)

			var toggle_btn := Button.new()
			toggle_btn.custom_minimum_size = Vector2(80, 0)
			match status_val:
				"todo": toggle_btn.text = "▶ Bắt đầu"
				"in-progress": toggle_btn.text = "[v] Xong"
				"done": toggle_btn.text = "↩ Mở lại"

			var task_id: String = task.get("id", "")
			var next_status := "in-progress"
			match status_val:
				"todo": next_status = "in-progress"
				"in-progress": next_status = "done"
				"done": next_status = "todo"

			toggle_btn.pressed.connect(func():
				toggle_btn.disabled = true
				HttpManager.patch("tasks/%s" % task_id, {"status": next_status})
				HttpManager.response_received.connect(
					func(ep: String, _d: Variant):
						if ep == "tasks/%s" % task_id:
							load_tasks.call(),
					CONNECT_ONE_SHOT
				)
				HttpManager.error.connect(
					func(ep: String, msg: String):
						if ep == "tasks/%s" % task_id:
							toggle_btn.disabled = false
							GameManager.notify("Lỗi cập nhật task: %s" % msg, "error"),
					CONNECT_ONE_SHOT
				)
			)
			row.add_child(toggle_btn)
			card.add_child(row)
			list.add_child(card)

	on_tasks_error = func(endpoint: String, msg: String) -> void:
		if endpoint != "tasks":
			return
		status_lbl.text = "[x] Lỗi tải task: %s" % msg

	HttpManager.response_received.connect(on_tasks_loaded)
	HttpManager.error.connect(on_tasks_error)
	refresh_btn.pressed.connect(load_tasks)

	# Auto-load on first open
	tab.visibility_changed.connect(func():
		if tab.visible:
			load_tasks.call()
	)

	return tab

# ── Avatar Customizer (Shift+A) ──
func _build_avatar_customizer() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false; root.name = "AvatarCustomizerRoot"

	var bg = ColorRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55); root.add_child(bg)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -300; panel.offset_right = 300
	panel.offset_top = -320; panel.offset_bottom = 320
	var ps = StyleBoxFlat.new(); ps.bg_color = Color(0.1, 0.1, 0.18)
	ps.set_corner_radius_all(12); ps.set_border_width_all(1); ps.border_color = Color(0.3,0.3,0.5)
	panel.add_theme_stylebox_override("panel", ps)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hdr = HBoxContainer.new()
	var ac_ttl = _make_label("Avatar Customizer", 15, Color(0.9,0.8,0.5), true)
	ac_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(ac_ttl)
	hdr.add_child(_make_x_btn(func(): _toggle_avatar_customizer()))
	vbox.add_child(hdr)
	vbox.add_child(HSeparator.new())

	# Outfit grid
	vbox.add_child(_make_label("Chọn trang phục hôm nay:", 11, Color(0.8,0.8,0.9)))
	var outfit_today = _make_label("Hiện tại: " + PlayerData.current_outfit.replace("_"," ").capitalize(), 11, Color.GREEN)
	outfit_today.name = "OutfitToday"; vbox.add_child(outfit_today)

	var outfits = [
		{"id":"work_casual","name":"Work Casual"},{"id":"formal","name":"Formal"},
		{"id":"creative","name":"Creative"},{"id":"initiate_class","name":"Initiate Class"},
	]
	var hbox = HBoxContainer.new(); hbox.add_theme_constant_override("separation", 6)
	for outfit in outfits:
		var btn = Button.new(); btn.text = outfit["name"]
		if outfit["id"] == PlayerData.current_outfit:
			btn.disabled = true; btn.modulate = Color(0.5, 1.0, 0.5)
		var oid: String = outfit["id"] # capture tại thời điểm tạo, không bị override bởi vòng lặp
		btn.pressed.connect(func():
			PlayerData.set_outfit_for_today(oid)
			outfit_today.text = "Hiện tại: " + PlayerData.current_outfit.replace("_"," ").capitalize()
			_update_player_card()
		)
		hbox.add_child(btn)
	vbox.add_child(hbox)

	vbox.add_child(HSeparator.new())
	# AI Agent settings
	vbox.add_child(_make_label("[AI] AI Agent (khi bạn offline):", 11, Color(0.8,0.8,0.9)))
	var ai_toggle = CheckButton.new(); ai_toggle.text = "Bật AI Agent"
	ai_toggle.button_pressed = PlayerData.ai_agent_enabled
	ai_toggle.toggled.connect(func(v): PlayerData.ai_agent_enabled = v; PlayerData.save_data())
	vbox.add_child(ai_toggle)

	vbox.add_child(_make_label("Context cho AI biết về bạn:", 10, Color(0.6,0.6,0.6)))
	var ctx = TextEdit.new(); ctx.text = PlayerData.ai_agent_context
	ctx.custom_minimum_size = Vector2(0, 60)
	ctx.placeholder_text = "Vd: Mình đang lead sprint này, thường online 9am-6pm..."
	vbox.add_child(ctx)

	var save_btn = Button.new(); save_btn.text = "Lưu Avatar"
	save_btn.pressed.connect(func():
		PlayerData.set_ai_context(ctx.text)
		GameManager.notify("Avatar đã lưu!", "success")
	)
	vbox.add_child(save_btn)

	vbox.add_child(HSeparator.new())

	# ── AI Portrait section ──
	vbox.add_child(_make_label("AI Portrait (ảnh đại diện):", 11, Color(0.8, 0.8, 0.9)))
	var portrait_hint = _make_label("Upload ảnh thật → AI tạo avatar Chibi/Anime/3D Pixar", 9, Color(0.5, 0.5, 0.5))
	portrait_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(portrait_hint)

	var maker_panel = load("res://scripts/ui/AvatarMakerPanel.gd").new()
	maker_panel.custom_minimum_size = Vector2(0, 320)
	maker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(maker_panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	panel.add_child(scroll)
	root.add_child(panel)
	avatar_customizer = root
	add_child(avatar_customizer)

# ── Interaction Dialog ──
func _build_interaction_dialog() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false; root.name = "InteractionDialogRoot"

	var bg = ColorRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55); root.add_child(bg)

	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -280; panel.offset_right = 280
	panel.offset_top = -280; panel.offset_bottom = 280
	var ps = StyleBoxFlat.new(); ps.bg_color = Color(0.08, 0.08, 0.15)
	ps.set_corner_radius_all(14); ps.set_border_width_all(1)
	ps.border_color = Color(0.3, 0.3, 0.55)
	ps.content_margin_left = 16; ps.content_margin_right = 16
	ps.content_margin_top = 12; ps.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", ps)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# ── Header: circular avatar + name/title + close ──
	var hdr = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)

	# Circular avatar placeholder (48×48 RenderingServer circle via SubViewport is heavy;
	# use a TextureRect clipped to circle shape via shader-lite: just a square with rounded corners)
	var avatar_frame = Control.new()
	avatar_frame.custom_minimum_size = Vector2(48, 48)
	avatar_frame.name = "AvatarFrame"
	var av_bg = ColorRect.new()
	av_bg.size = Vector2(48, 48); av_bg.color = Color(0.2, 0.2, 0.35)
	avatar_frame.add_child(av_bg)
	var av_tex := TextureRect.new()
	av_tex.name = "AvatarTex"
	av_tex.position = Vector2(0, 0); av_tex.size = Vector2(48, 48)
	av_tex.stretch_mode = TextureRect.STRETCH_SCALE
	av_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	avatar_frame.add_child(av_tex)
	# Circular clip via StyleBox on a Panel overlay
	var av_circle = Panel.new()
	av_circle.size = Vector2(48, 48)
	var av_style = StyleBoxFlat.new()
	av_style.bg_color = Color(0, 0, 0, 0)
	av_style.set_corner_radius_all(24)
	av_style.set_border_width_all(2)
	av_style.border_color = Color(0.5, 0.6, 0.9, 0.8)
	av_circle.add_theme_stylebox_override("panel", av_style)
	avatar_frame.add_child(av_circle)
	hdr.add_child(avatar_frame)

	var name_col = VBoxContainer.new(); name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emp_name_lbl = _make_label("", 14, Color.WHITE, true); emp_name_lbl.name = "EmpName"
	var emp_meta = _make_label("", 10, Color(0.6, 0.7, 0.9)); emp_meta.name = "EmpMeta"
	var emp_task = _make_label("", 9, Color(0.6, 0.8, 0.5)); emp_task.name = "EmpTask"
	emp_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(emp_name_lbl); name_col.add_child(emp_meta); name_col.add_child(emp_task)
	hdr.add_child(name_col)

	var close_btn = Button.new(); close_btn.text = "X"
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.3, 0.1, 0.1, 0.8); close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	close_btn.pressed.connect(func(): close_interaction_dialog())
	hdr.add_child(close_btn)
	vbox.add_child(hdr)
	vbox.add_child(HSeparator.new())

	# ── Chat area ──
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	var chat_vbox = VBoxContainer.new(); chat_vbox.name = "ChatHistory"
	chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(chat_vbox); vbox.add_child(scroll)

	# ── Input row ──
	var input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	var chat_input = LineEdit.new(); chat_input.name = "ChatInput"
	chat_input.placeholder_text = "Nhắn tin... (AI sẽ reply thay họ nếu offline)"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var send_btn = Button.new(); send_btn.text = "Gửi"
	var send_style = StyleBoxFlat.new(); send_style.bg_color = Color(0.15, 0.35, 0.65, 0.9)
	send_style.set_corner_radius_all(6)
	send_btn.add_theme_stylebox_override("normal", send_style)
	send_btn.pressed.connect(func(): _dialog_send(panel))
	chat_input.text_submitted.connect(func(_t): _dialog_send(panel))
	input_row.add_child(chat_input); input_row.add_child(send_btn)
	vbox.add_child(input_row)

	panel.add_child(vbox); root.add_child(panel)
	interaction_dialog = root
	add_child(interaction_dialog)

	# Connect AI response
	AIAgent.response_ready.connect(func(resp, cid):
		if not (cid.begins_with("emp_") or cid.begins_with("hieupt")): return
		var ch = interaction_dialog.get_node_or_null("PanelContainer/VBoxContainer/ScrollContainer/ChatHistory")
		if ch: _add_chat_msg(ch, "AI Agent", resp, false)
	)

func _dialog_send(panel: PanelContainer) -> void:
	var input = panel.get_node_or_null("VBoxContainer/HBoxContainer/ChatInput")
	if input == null:
		input = panel.get_node_or_null("VBoxContainer/ChatInput")
	var chat_history = panel.get_node_or_null("VBoxContainer/ScrollContainer/ChatHistory")
	if input == null or chat_history == null: return
	var msg = input.text.strip_edges()
	if msg.is_empty(): return
	_add_chat_msg(chat_history, PlayerData.display_name, msg, true)
	input.clear()
	if current_employee_node != null:
		var emp_id = current_employee_node.get("employee_id") if current_employee_node.get("employee_id") != null else ""
		if emp_id != "":
			AIAgent.ask_employee_agent(emp_id, msg)

func _add_chat_msg(parent: VBoxContainer, sender: String, message: String, is_player: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if is_player:
		row.alignment = BoxContainer.ALIGNMENT_END

	# Small circular avatar dot (NPC side only)
	if not is_player:
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(28, 28)
		# Generate a consistent color from the sender name
		var h: float = float(sender.hash() & 0xFFFF) / 65535.0
		dot.color = Color.from_hsv(h, 0.55, 0.75)
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = dot.color; dot_style.set_corner_radius_all(14)
		var dot_panel = Panel.new(); dot_panel.custom_minimum_size = Vector2(28, 28)
		dot_panel.add_theme_stylebox_override("panel", dot_style)
		# Initial of sender name
		var init_lbl = Label.new()
		init_lbl.text = sender.substr(sender.rfind(" ") + 1, 1).to_upper()
		init_lbl.add_theme_font_size_override("font_size", 10)
		init_lbl.add_theme_color_override("font_color", Color.WHITE)
		init_lbl.set_anchors_preset(Control.PRESET_CENTER)
		dot_panel.add_child(init_lbl)
		row.add_child(dot_panel)

	var bubble = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.32, 0.58) if is_player else Color(0.18, 0.18, 0.28)
	s.set_corner_radius_all(10)
	s.corner_radius_top_left = 4 if is_player else 10
	s.corner_radius_top_right = 10 if is_player else 4
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 6; s.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", s)
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	if not is_player:
		cv.add_child(_make_label(sender, 8, Color(0.6, 0.75, 1.0)))
	var ml = _make_label(message, 11, Color.WHITE)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size.x = 120
	cv.add_child(ml); bubble.add_child(cv)

	if is_player:
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_spacer(false)
	parent.add_child(row)

# ─────────────────────────────────────────────
# Per-frame updates
# ─────────────────────────────────────────────
func _process(_delta: float) -> void:
	_update_zone_indicator_position()
	_update_minimap()
	_update_zone_from_player()

func _update_zone_indicator_position() -> void:
	# Position zone indicator just below player_card once it has laid out
	var zone_node: Control = get_node_or_null("ZoneIndicator")
	if zone_node == null: return
	if player_card != null:
		zone_node.position.y = player_card.position.y + player_card.size.y + 6
	else:
		zone_node.position.y = 90

func _world_to_minimap(world_pos: Vector2, dot_size: float) -> Vector2:
	var half := dot_size * 0.5
	var x := clampf(world_pos.x * _MAP_PX_W / _MINIMAP_W - half, 0.0, _MAP_PX_W - dot_size)
	var y := clampf(world_pos.y * _MAP_PX_H / _MINIMAP_H - half, 0.0, _MAP_PX_H - dot_size)
	return Vector2(x, y)

func _update_minimap() -> void:
	if _minimap_player_dot == null or current_player_ref == null: return
	# Update player dot
	_minimap_player_dot.position = _world_to_minimap(current_player_ref.global_position, 6.0)

	# ── RTS camera viewport rect ──
	if _minimap_cam_rect != null:
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null:
			var vp_size: Vector2 = get_viewport().get_visible_rect().size
			var zoom: Vector2    = cam.zoom
			# Visible world size = viewport pixels / zoom
			var world_w: float = vp_size.x / zoom.x
			var world_h: float = vp_size.y / zoom.y
			# Top-left corner in world space (camera.global_position = center of view)
			var world_left: float = cam.global_position.x - world_w * 0.5
			var world_top:  float = cam.global_position.y - world_h * 0.5
			# Convert to minimap pixel space
			var rx: float = world_left * _MAP_PX_W / _MINIMAP_W
			var ry: float = world_top  * _MAP_PX_H / _MINIMAP_H
			var rw: float = world_w    * _MAP_PX_W / _MINIMAP_W
			var rh: float = world_h    * _MAP_PX_H / _MINIMAP_H
			# Clamp to map_area bounds
			var cx: float = clampf(rx, 0.0, _MAP_PX_W)
			var cy: float = clampf(ry, 0.0, _MAP_PX_H)
			var cw: float = clampf(rw, 4.0, _MAP_PX_W - cx)
			var ch: float = clampf(rh, 4.0, _MAP_PX_H - cy)
			_minimap_cam_rect.position = Vector2(cx, cy)
			_minimap_cam_rect.size     = Vector2(cw, ch)

	# NPC dots: position-only update (dots created/removed via minimap_add/remove_npc_dot)
	if _minimap_map_area == null: return
	for emp_id in _minimap_npc_dots.keys():
		var npc_dot: ColorRect = _minimap_npc_dots[emp_id]
		# Find the employee node via cached group lookup
		var emp_node: Node = null
		for n in get_tree().get_nodes_in_group("employees"):
			if "employee_id" in n and n.employee_id == emp_id:
				emp_node = n
				break
		if emp_node != null and is_instance_valid(emp_node):
			npc_dot.position = _world_to_minimap(emp_node.global_position, 4.0)

func minimap_add_npc_dot(emp_id: String, is_online: bool) -> void:
	if _minimap_map_area == null or _minimap_npc_dots.has(emp_id): return
	var dot := ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.z_index = 5
	dot.color = Color(0.2, 0.9, 0.3) if is_online else Color(0.45, 0.45, 0.45)
	_minimap_map_area.add_child(dot)
	_minimap_npc_dots[emp_id] = dot

func minimap_remove_npc_dot(emp_id: String) -> void:
	if not _minimap_npc_dots.has(emp_id): return
	var dot: ColorRect = _minimap_npc_dots[emp_id]
	if is_instance_valid(dot): dot.queue_free()
	_minimap_npc_dots.erase(emp_id)

func _update_zone_from_player() -> void:
	if _zone_label == null or current_player_ref == null: return
	# Try to get zone from the Office node in the scene tree
	var office: Node = _find_office()
	var zone_id: String = ""
	if office != null and office.has_method("get_room_at_position"):
		zone_id = office.get_room_at_position(current_player_ref.global_position)
	else:
		# Fallback: compute locally using copied rect data
		zone_id = _local_get_zone(current_player_ref.global_position)

	if zone_id == _last_zone: return
	_last_zone = zone_id
	var display: String = _ZONE_DISPLAY_NAMES.get(zone_id, "Office")
	_zone_label.text = "" + display

func _local_get_zone(world_pos: Vector2) -> String:
	# World is pixel space — check zones directly
	for zone_id in _ZONE_RECTS:
		if (_ZONE_RECTS[zone_id] as Rect2).has_point(world_pos):
			return zone_id
	return ""

func _find_office() -> Node:
	# Walk up from HUD's owner scene to find the Office node
	var root: Node = get_tree().current_scene
	if root == null: return null
	if root.has_method("get_room_at_position"): return root
	for child in root.get_children():
		if child.has_method("get_room_at_position"): return child
	return null

# ── Sprint label refresh ──
func _refresh_sprint_label() -> void:
	if _sprint_label == null: return
	if GameManager.active_sprints.is_empty():
		_sprint_label.text = ""
		return
	# Show the first (most relevant) sprint
	var s: Dictionary = GameManager.active_sprints[0]
	var pct: int = int(s.get("progress", 0.0) * 100)
	var done: int = s.get("tasks_done", 0)
	var total: int = s.get("tasks_total", 0)
	_sprint_label.text = "%s %d%% (%d/%d tasks) %s" % [
		s.get("name", "Sprint"), pct, done, total, s.get("deadline", "")
	]

# ─────────────────────────────────────────────
# Panel toggle helpers
# ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_toggle_workspace_panel()
		elif event.keycode == KEY_C and not event.shift_pressed and not event.ctrl_pressed:
			var _focus := get_viewport().gui_get_focus_owner()
			if _focus == null or not (_focus is LineEdit):
				_toggle_ingame_chat()
		elif event.keycode == KEY_A and event.shift_pressed:
			_toggle_avatar_customizer()
		elif event.keycode == KEY_Q:
			_toggle_emote_menu()

func _toggle_ingame_chat() -> void:
	if _chat_log_node and _chat_log_node.has_method("toggle"):
		_chat_log_node.toggle()

func _toggle_ai_bar() -> void:
	var was_open := _ai_bar_open
	_close_side_panels()
	if not was_open:
		_ai_bar_open = true
		if _ai_bar_panel:    _ai_bar_panel.visible    = true
		if _ai_bar_backdrop: _ai_bar_backdrop.visible = true

func _toggle_workspace_panel() -> void:
	if workspace_panel == null: return
	var was_open := workspace_panel.visible
	_close_side_panels()
	if not was_open:
		workspace_panel.visible = true
		if current_player_ref: current_player_ref.set_busy(true)

func _toggle_avatar_maker() -> void:
	_avatar_iframe_visible = not _avatar_iframe_visible
	if _web_is_platform:
		_avatar_iframe_ensure()
		_avatar_iframe_set_visible(_avatar_iframe_visible)
		if _avatar_iframe_visible:
			_avatar_iframe_poll_close()
	else:
		if _avatar_maker_panel == null:
			_avatar_maker_panel = _build_avatar_maker_desktop_info()
			add_child(_avatar_maker_panel)
		_avatar_maker_panel.visible = _avatar_iframe_visible
	if current_player_ref:
		current_player_ref.set_busy(_avatar_iframe_visible)

# Tạo iframe overlay trong DOM — avatar-maker-green.vercel.app
# JavaScriptBridge.eval() là API chuẩn Godot 4 Web. Tất cả strings hardcoded.
func _avatar_iframe_ensure() -> void:
	if _avatar_iframe_created: return
	_avatar_iframe_created = true
	var js: String = (
		"(function(){"
		+ "if(document.getElementById('zps-av-overlay'))return;"
		+ "var ov=document.createElement('div');"
		+ "ov.id='zps-av-overlay';"
		+ "ov.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,0.78);z-index:500;display:none;';"
		+ "var panel=document.createElement('div');"
		+ "panel.style.cssText='position:absolute;top:3%;left:4%;width:92%;height:94%;display:flex;flex-direction:column;background:#1a1a2e;border-radius:12px;overflow:hidden;box-shadow:0 8px 40px rgba(0,0,0,0.7);';"
		+ "var hdr=document.createElement('div');"
		+ "hdr.style.cssText='display:flex;align-items:center;justify-content:space-between;padding:8px 16px;background:#16213e;flex-shrink:0;border-bottom:1px solid #e8c97a44;';"
		+ "var ttl=document.createElement('span');"
		+ "ttl.textContent='AI Avatar Maker';"
		+ "ttl.style.cssText='color:#e8c97a;font-weight:bold;font-size:15px;font-family:sans-serif;';"
		+ "var xbtn=document.createElement('button');"
		+ "xbtn.textContent='Dong X';"
		+ "xbtn.style.cssText='background:#c0392b;color:#fff;border:none;padding:5px 14px;border-radius:5px;cursor:pointer;font-size:13px;font-family:sans-serif;';"
		+ "xbtn.onmouseenter=function(){this.style.background='#e74c3c';};"
		+ "xbtn.onmouseleave=function(){this.style.background='#c0392b';};"
		+ "xbtn.onclick=function(){window._zps_av_close_req=1;};"
		+ "hdr.appendChild(ttl);hdr.appendChild(xbtn);"
		+ "var f=document.createElement('iframe');"
		+ "f.id='zps-av-iframe';"
		+ "f.src='https://avatar-maker-green.vercel.app';"
		+ "f.allow='camera;microphone;clipboard-write';"
		+ "f.style.cssText='flex:1;border:none;';"
		+ "panel.appendChild(hdr);panel.appendChild(f);"
		+ "ov.appendChild(panel);"
		+ "document.body.appendChild(ov);"
		+ "window._zps_av_close_req=0;"
		# Click backdrop (ngoài panel) cũng đóng
		+ "ov.addEventListener('click',function(e){if(e.target===ov)window._zps_av_close_req=1;});"
		+ "})();"
	)
	JavaScriptBridge.eval(js)

func _avatar_iframe_set_visible(show: bool) -> void:
	var display := "flex" if show else "none"
	JavaScriptBridge.eval(
		"var ov=document.getElementById('zps-av-overlay');"
		+ "if(ov)ov.style.display='" + display + "';"
		+ "window._zps_av_close_req=0;"
	)

# Poll mỗi 0.3s — detect khi user bấm Dong X hoặc click backdrop trong JS
func _avatar_iframe_poll_close() -> void:
	if not _avatar_iframe_visible: return
	# Dùng số nguyên (0/1) thay bool để tránh type mismatch khi JavaScriptBridge convert
	var req = JavaScriptBridge.eval("window._zps_av_close_req|0")
	if req != null and int(req) == 1:
		_avatar_iframe_visible = false
		_avatar_iframe_set_visible(false)
		if current_player_ref: current_player_ref.set_busy(false)
		return
	get_tree().create_timer(0.3).timeout.connect(_avatar_iframe_poll_close)

# Desktop fallback — iframe chỉ chạy trên web build
func _build_avatar_maker_desktop_info() -> Control:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "AvatarMakerDesktopInfo"
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_avatar_iframe_visible = false
			root.visible = false
			if current_player_ref: current_player_ref.set_busy(false)
	)
	root.add_child(bg)
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -200; panel.offset_right = 200
	panel.offset_top = -80;   panel.offset_bottom = 80
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.07, 0.13)
	ps.set_corner_radius_all(10); ps.set_border_width_all(1)
	ps.border_color = Color(0.65, 0.52, 0.20)
	panel.add_theme_stylebox_override("panel", ps)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(_make_label("AI Avatar Maker", 13, Color(0.9, 0.8, 0.5), true))
	vb.add_child(_make_label("Chi hoat dong tren Web build.\nMo http://localhost:3000 de su dung.", 10, Color(0.75, 0.75, 0.75)))
	var close_b = Button.new(); close_b.text = "Dong"
	close_b.pressed.connect(func():
		_avatar_iframe_visible = false
		root.visible = false
		if current_player_ref: current_player_ref.set_busy(false)
	)
	vb.add_child(close_b)
	root.add_child(panel)
	return root

func _toggle_avatar_customizer() -> void:
	if avatar_customizer == null: return
	avatar_customizer.visible = not avatar_customizer.visible
	if current_player_ref:
		current_player_ref.set_busy(avatar_customizer.visible)

# ── Character Generator panel (Ngoại hình) ────────────────────────────────────
func _toggle_char_gen_panel() -> void:
	if _char_gen_panel == null:
		_char_gen_panel = _build_char_gen_panel()
		add_child(_char_gen_panel)
	_char_gen_panel.visible = not _char_gen_panel.visible
	if current_player_ref:
		current_player_ref.set_busy(_char_gen_panel.visible)

func _build_char_gen_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "CharGenPanel"

	# Dim bg
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.65)
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed: _toggle_char_gen_panel()
	)
	root.add_child(bg)

	# Panel
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -300; panel.offset_right = 300
	panel.offset_top = -220; panel.offset_bottom = 220
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.06, 0.12)
	ps.set_corner_radius_all(12)
	ps.set_border_width_all(2); ps.border_color = Color(0.55, 0.45, 0.90)
	ps.content_margin_left = 20; ps.content_margin_right = 20
	ps.content_margin_top = 16; ps.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	var title_lbl := _make_label("NGOẠI HÌNH NHÂN VẬT", 14, Color(0.75, 0.65, 1.0), true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_lbl)
	hdr.add_child(_make_x_btn(_toggle_char_gen_panel))
	vbox.add_child(hdr)
	vbox.add_child(ColorRect.new()) # thin separator
	(vbox.get_child(vbox.get_child_count() - 1) as ColorRect).color = Color(0.55, 0.45, 0.90, 0.35)
	(vbox.get_child(vbox.get_child_count() - 1) as ColorRect).custom_minimum_size = Vector2(0, 1)

	# Icon area
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_lbl := _make_label("🎮", 36, Color.WHITE)
	icon_row.add_child(icon_lbl)
	vbox.add_child(icon_row)

	vbox.add_child(_make_label("Character Generator", 13, Color(0.90, 0.85, 1.0), true))
	vbox.add_child(_make_label(
		"Công cụ tạo sprite nhân vật 2D cho ZPS World.\nChạy trên Windows — không thể mở trực tiếp trong trình duyệt.",
		10, Color(0.75, 0.75, 0.85)))

	var sep2 := ColorRect.new()
	sep2.color = Color(0.4, 0.35, 0.7, 0.30)
	sep2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep2)

	# Info box
	var info_panel := PanelContainer.new()
	var ips := StyleBoxFlat.new()
	ips.bg_color = Color(0.10, 0.08, 0.18); ips.set_corner_radius_all(6)
	ips.set_border_width_all(1); ips.border_color = Color(0.40, 0.35, 0.65)
	ips.content_margin_left = 12; ips.content_margin_right = 12
	ips.content_margin_top = 8; ips.content_margin_bottom = 8
	info_panel.add_theme_stylebox_override("panel", ips)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vbox)
	var steps: Array[String] = [
		"1. Chạy CharacterGenerator.exe trên Windows",
		"2. Tuỳ chỉnh nhân vật → Export sprite sheet (PNG)",
		"3. Đặt file vào assets/sprites/ và cập nhật AvatarRenderer",
	]
	for step_str: String in steps:
		info_vbox.add_child(_make_label(step_str, 9, Color(0.80, 0.82, 0.95)))
	vbox.add_child(info_panel)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	var close_b := Button.new()
	close_b.text = "Đóng"
	close_b.pressed.connect(_toggle_char_gen_panel)
	btn_row.add_child(close_b)
	vbox.add_child(btn_row)

	return root

func _toggle_web_chat_panel() -> void:
	if web_chat_panel == null: return
	if web_chat_panel.visible:
		_close_web_chat_slide()
	else:
		_open_web_chat_slide()

func _open_web_chat_slide() -> void:
	web_chat_panel.visible = true
	if current_player_ref:
		current_player_ref.set_busy(true)
	if _web_is_platform:
		_web_chat_ensure_iframe()
		_web_chat_slide_in()
	elif _chat_box:
		# Desktop: slide in from off-screen right
		_chat_box.offset_left = 0.0
		var t := create_tween()
		t.tween_property(_chat_box, "offset_left", -380.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _close_web_chat_slide() -> void:
	if _web_is_platform:
		_web_chat_slide_out()
		await get_tree().create_timer(0.22).timeout
	elif _chat_box:
		# Desktop: slide out to right
		var t := create_tween()
		t.tween_property(_chat_box, "offset_left", 0.0, 0.20).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await t.finished
	web_chat_panel.visible = false
	if current_player_ref:
		current_player_ref.set_busy(false)

func _web_chat_ensure_iframe() -> void:
	if _web_chat_iframe_created: return
	_web_chat_iframe_created = true
	# JavaScriptBridge.eval() is the only Godot 4 API for DOM access in web exports.
	# All strings here are fully hardcoded — no user input is interpolated.
	var js := (
		"(function(){"
		+ "if(document.getElementById('zps-chat-iframe'))return;"
		+ "var f=document.createElement('iframe');"
		+ "f.id='zps-chat-iframe';"
		+ "f.src='https://workspace.zingplay.com/chat';"
		+ "f.allow='camera;microphone';"
		+ "f.setAttribute('style',"
		+ "'position:fixed;top:0;right:0;width:380px;height:100%;border:none;"
		+ "z-index:9999;display:none;box-shadow:-6px 0 28px rgba(0,0,0,0.65)');"
		+ "document.body.appendChild(f);"
		+ "})();"
	)
	JavaScriptBridge.eval(js)

func _web_chat_set_visible(show: bool) -> void:
	var display := "block" if show else "none"
	JavaScriptBridge.eval(
		"var f=document.getElementById('zps-chat-iframe');"
		+ "if(f)f.style.display='" + display + "';"
	)

# Slide iframe in from right (CSS transition, fully hardcoded strings)
func _web_chat_slide_in() -> void:
	JavaScriptBridge.eval(
		"(function(){"
		+ "var f=document.getElementById('zps-chat-iframe');if(!f)return;"
		+ "f.style.transition='none';"
		+ "f.style.transform='translateX(380px)';"
		+ "f.style.display='block';"
		+ "requestAnimationFrame(function(){"
		+ "requestAnimationFrame(function(){"
		+ "f.style.transition='transform 0.22s ease-out';"
		+ "f.style.transform='translateX(0)';"
		+ "});});})();"
	)

# Slide iframe out to right (CSS transition, fully hardcoded strings)
func _web_chat_slide_out() -> void:
	JavaScriptBridge.eval(
		"(function(){"
		+ "var f=document.getElementById('zps-chat-iframe');if(!f)return;"
		+ "f.style.transition='transform 0.2s ease-in';"
		+ "f.style.transform='translateX(380px)';"
		+ "setTimeout(function(){"
		+ "f.style.display='none';"
		+ "f.style.transform='';"
		+ "f.style.transition='';"
		+ "},210);})();"
	)

func show_employee_interaction(employee_data: Dictionary, emp_node: Node, player: Node) -> void:
	current_employee_node = emp_node
	current_player_ref = player
	var p: Node = interaction_dialog.get_node_or_null("PanelContainer")
	if p == null:
		interaction_dialog.show()
		return

	# ── Avatar ──
	var av_tex: TextureRect = p.get_node_or_null("VBoxContainer/HBoxContainer/AvatarFrame/AvatarTex")
	if av_tex:
		var emp_id: String = employee_data.get("id", "")
		var avatar_path: String = "res://assets/sprites/characters/avatars/%s.png" % emp_id
		var tex: Texture2D = null
		if ResourceLoader.exists(avatar_path):
			tex = load(avatar_path) as Texture2D
		if tex == null:
			var abs_p := ProjectSettings.globalize_path(avatar_path)
			if FileAccess.file_exists(abs_p):
				var img := Image.load_from_file(abs_p)
				if img: tex = ImageTexture.create_from_image(img)
		av_tex.texture = tex # null = blank colored circle fallback

	# ── Name / meta / task ──
	var n: Node = p.get_node_or_null("VBoxContainer/HBoxContainer/VBoxContainer/EmpName")
	if n: n.text = employee_data.get("name", "?")
	var m: Node = p.get_node_or_null("VBoxContainer/HBoxContainer/VBoxContainer/EmpMeta")
	if m: m.text = "%s · %s" % [employee_data.get("title","?"), employee_data.get("department","?")]
	var t: Node = p.get_node_or_null("VBoxContainer/HBoxContainer/VBoxContainer/EmpTask")
	if t: t.text = " " + employee_data.get("current_task","?")

	# ── Chat history ──
	var ch: Node = p.get_node_or_null("VBoxContainer/ScrollContainer/ChatHistory")
	if ch:
		for c in ch.get_children(): c.queue_free()
		var workspace: Dictionary = employee_data.get("workspace", {})
		var fake_chat: Array = workspace.get("fake_chat", [])
		if fake_chat.size() > 0:
			# Load pre-written conversation (e.g. HieuPT workspace)
			for msg_data: Dictionary in fake_chat:
				_add_chat_msg(ch, msg_data.get("sender","?"), msg_data.get("msg",""), false)
		else:
			var online: bool = employee_data.get("is_online", false)
			var greet: String
			if online:
				greet = "Xin chào! Mình đang làm '%s'. Cần gì không?" % employee_data.get("current_task","việc")
			else:
				greet = "(Offline) AI sẽ trả lời thay mình nhé!"
			_add_chat_msg(ch, employee_data.get("name","?"), greet, false)

	interaction_dialog.show()
	if current_player_ref:
		current_player_ref.set_busy(true)

func close_interaction_dialog() -> void:
	if interaction_dialog: interaction_dialog.hide()
	if current_employee_node and current_employee_node.has_method("finish_interaction"):
		current_employee_node.finish_interaction()
	if current_player_ref: current_player_ref.set_busy(false)
	current_employee_node = null

# ─────────────────────────────────────────────
# Player card update
# ─────────────────────────────────────────────
func _on_login_complete_refresh_ui() -> void:
	_update_player_card()
	# Destroy profile panel so it rebuilds with fresh account data on next open
	if _char_profile_panel != null:
		_char_profile_panel.queue_free()
		_char_profile_panel = null

func _update_player_card() -> void:
	if pc_name == null: return
	# Outside: show only domain name (part before " - " if present)
	var domain_name := PlayerData.display_name
	var sep_idx := domain_name.find(" - ")
	if sep_idx > 0:
		domain_name = domain_name.left(sep_idx)
	pc_name.text = domain_name
	# Title in gold below name
	pc_title.text = PlayerData.hr_title
	pc_title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	pc_class.text = "Class: " + PlayerData.zps_class.capitalize()
	pc_outfit.text = "" + PlayerData.current_outfit.replace("_"," ").capitalize()
	# Portrait: hien thi neu da co AI avatar
	if _pc_portrait != null:
		var tex := ProfilePicture.base64_to_texture(PlayerData.avatar_portrait_base64)
		if tex != null:
			_pc_portrait.texture = tex
			_pc_portrait.visible = true
		else:
			_pc_portrait.visible = false

# ─────────────────────────────────────────────
# Notification toast
# ─────────────────────────────────────────────
func _on_notification(message: String, type: String = "info") -> void:
	if notification_stack == null: return
	var panel = PanelContainer.new()
	var type_colors = {
		"success": Color(0.1, 0.3, 0.1, 0.92), "error": Color(0.3, 0.08, 0.08, 0.92),
		"info": Color(0.08, 0.12, 0.28, 0.92), "achievement": Color(0.22, 0.18, 0.04, 0.92),
	}
	var s = StyleBoxFlat.new(); s.bg_color = type_colors.get(type, type_colors["info"])
	s.set_corner_radius_all(7); s.set_border_width_all(1); s.border_color = Color(1,1,1,0.18)
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 7; s.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", s); panel.custom_minimum_size.x = 280
	var icons = {"success":"[v]","error":"[x]","info":"i","achievement":"[+]"}
	var lbl = _make_label("%s %s" % [icons.get(type,"•"), message], 11, Color.WHITE)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(lbl); notification_stack.add_child(panel)
	get_tree().create_timer(3.5).timeout.connect(func():
		if is_instance_valid(panel):
			var tw = create_tween()
			tw.tween_property(panel, "modulate:a", 0.0, 0.35)
			tw.tween_callback(panel.queue_free)
	)

# ─────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────
func _make_label(text: String, size: int, color: Color, _bold: bool = false) -> Label:
	var lbl = Label.new(); lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ─────────────────────────────────────────────
# Char-Profile Panel (click player card top-left)
# ─────────────────────────────────────────────
func _build_char_profile_panel() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false; root.name = "CharProfileRoot"

	# Dim background
	var bg = ColorRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.65); root.add_child(bg)
	bg.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed: _toggle_char_profile()
	)

	# Main panel
	var panel = PanelContainer.new(); panel.name = "Panel"
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -390; panel.offset_right = 390
	panel.offset_top = -320; panel.offset_bottom = 320
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.05, 0.10)
	ps.set_border_width_all(2); ps.border_color = Color(0.65, 0.52, 0.20)
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 0; ps.content_margin_right = 0
	ps.content_margin_top = 0; ps.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# ── Header bar ──
	var header_bg = PanelContainer.new()
	var hs = StyleBoxFlat.new(); hs.bg_color = Color(0.10, 0.08, 0.16)
	hs.border_color = Color(0.65, 0.52, 0.20); hs.border_width_bottom = 1
	hs.corner_radius_top_left = 10; hs.corner_radius_top_right = 10
	hs.content_margin_left = 18; hs.content_margin_right = 12
	hs.content_margin_top = 10; hs.content_margin_bottom = 10
	header_bg.add_theme_stylebox_override("panel", hs)
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	var h_title = _make_label("PLAYER PROFILE", 13, Color(0.90, 0.75, 0.30), true)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(h_title)
	header_row.add_child(_make_x_btn(_toggle_char_profile))
	header_bg.add_child(header_row); outer.add_child(header_bg)

	# ── Body (left avatar column + right content) ──
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Left column
	var left = VBoxContainer.new(); left.custom_minimum_size.x = 170
	left.add_theme_constant_override("separation", 8)
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.06, 0.14)
	left_style.border_color = Color(0.65, 0.52, 0.20); left_style.border_width_right = 1
	left_style.corner_radius_bottom_left = 10
	left_style.content_margin_left = 14; left_style.content_margin_right = 14
	left_style.content_margin_top = 14; left_style.content_margin_bottom = 14
	var left_panel = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", left_style)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.add_child(left)
	left_panel.add_child(left_scroll); body.add_child(left_panel)

	# Avatar frame — SubViewport + circular shader clip
	const _AV_OGV := "res://assets/avatars/avatar-animation-sangvk.ogv"
	const _AV_SIZE := 142
	var av_frame = Control.new()
	av_frame.custom_minimum_size = Vector2(_AV_SIZE, _AV_SIZE)
	av_frame.size = Vector2(_AV_SIZE, _AV_SIZE)

	var sv_container = SubViewportContainer.new()
	sv_container.size = Vector2(_AV_SIZE, _AV_SIZE)
	sv_container.custom_minimum_size = Vector2(_AV_SIZE, _AV_SIZE)
	sv_container.stretch = true

	var sv = SubViewport.new()
	sv.size = Vector2i(_AV_SIZE, _AV_SIZE)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var used_video := false
	if ResourceLoader.exists(_AV_OGV):
		var stream_res: VideoStream = load(_AV_OGV) as VideoStream
		if stream_res != null:
			var vsp = VideoStreamPlayer.new(); vsp.name = "AvatarVideo"
			vsp.stream = stream_res; vsp.autoplay = true; vsp.loop = true
			vsp.expand = true
			vsp.set_anchors_preset(Control.PRESET_FULL_RECT)
			sv.add_child(vsp); used_video = true

	if not used_video:
		var av_bg = ColorRect.new(); av_bg.color = Color(0.14, 0.10, 0.22)
		av_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		sv.add_child(av_bg)
		var av_lbl = Label.new(); av_lbl.text = PlayerData.display_name.left(2).to_upper()
		av_lbl.add_theme_font_size_override("font_size", 32)
		av_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
		av_lbl.set_anchors_preset(Control.PRESET_CENTER)
		sv.add_child(av_lbl)

	sv_container.add_child(sv)

	# Circular shader applied to SubViewportContainer
	var circ_shader = Shader.new()
	circ_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	float edge = fwidth(r) * 1.5;
	float alpha = 1.0 - smoothstep(0.5 - edge, 0.5, r);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}
"""
	var circ_mat = ShaderMaterial.new(); circ_mat.shader = circ_shader
	sv_container.material = circ_mat
	av_frame.add_child(sv_container)

	# Gold border ring overlay (purely visual, no clip needed)
	var av_border = ColorRect.new(); av_border.size = Vector2(_AV_SIZE, _AV_SIZE)
	var border_shader = Shader.new()
	border_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	float ring = smoothstep(0.47, 0.48, r) * (1.0 - smoothstep(0.50, 0.51, r));
	COLOR = vec4(0.65, 0.52, 0.20, ring);
}
"""
	var border_mat = ShaderMaterial.new(); border_mat.shader = border_shader
	av_border.material = border_mat
	av_frame.add_child(av_border)

	# Clickable overlay — click avatar → close profile & open Avatar Maker
	var av_click_btn = Button.new()
	av_click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	av_click_btn.flat = true
	av_click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	av_click_btn.tooltip_text = "Click để tạo AI Avatar mới"
	av_click_btn.pressed.connect(func():
		_toggle_char_profile()
		_toggle_avatar_maker()
	)
	av_frame.add_child(av_click_btn)

	# "Edit" hint label below avatar
	var edit_hint = _make_label("[ Tạo AI Avatar ]", 8, Color(0.65, 0.52, 0.20))
	edit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	left.add_child(av_frame)
	left.add_child(edit_hint)

	# Full name (shown only in profile)
	var name_lbl = _make_label(PlayerData.display_name, 12, Color(0.95, 0.90, 0.70), true)
	name_lbl.name = "ProfileName"; name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(name_lbl)

	# Tier badge
	var tier_panel = PanelContainer.new()
	var tier_s = StyleBoxFlat.new(); tier_s.bg_color = Color(0.35, 0.25, 0.05)
	tier_s.set_border_width_all(1); tier_s.border_color = Color(0.65, 0.52, 0.20)
	tier_s.set_corner_radius_all(6)
	tier_s.content_margin_left = 8; tier_s.content_margin_right = 8
	tier_s.content_margin_top = 3; tier_s.content_margin_bottom = 3
	tier_panel.add_theme_stylebox_override("panel", tier_s)
	tier_panel.add_child(_make_label("LEGENDARY", 9, Color(0.90, 0.75, 0.30)))
	left.add_child(tier_panel)

	# Domain / Role / Title
	left.add_child(_make_label("Domain: " + PlayerData.zps_callsign, 9, Color(0.65, 0.75, 0.95)))
	left.add_child(_make_label("Role: " + PlayerData.department, 9, Color(0.65, 0.85, 0.65)))
	left.add_child(_make_label("Title: " + PlayerData.hr_title, 9, Color(0.90, 0.75, 0.30)))
	left.add_child(HSeparator.new())

	# Status selector
	left.add_child(_make_label("Trạng thái", 9, Color(0.55, 0.60, 0.70)))
	var status_opt = OptionButton.new(); status_opt.name = "StatusOpt"
	status_opt.add_item(" Đang đi làm")
	status_opt.add_item("Đang họp")
	status_opt.add_item("Xin nghỉ phép")
	status_opt.add_item("Work from home")
	status_opt.add_item(" Không xác định")
	status_opt.add_theme_font_size_override("font_size", 10)
	left.add_child(status_opt)

	left.add_child(HSeparator.new())

	# ── Logout button ──
	var logout_btn := Button.new()
	logout_btn.text = "Đăng xuất"
	logout_btn.add_theme_font_size_override("font_size", 10)
	logout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var logout_s := StyleBoxFlat.new()
	logout_s.bg_color = Color(0.52, 0.08, 0.08)
	logout_s.border_color = Color(0.90, 0.25, 0.25)
	logout_s.set_border_width_all(1); logout_s.set_corner_radius_all(5)
	logout_s.content_margin_top = 5; logout_s.content_margin_bottom = 5
	var logout_hover := logout_s.duplicate() as StyleBoxFlat
	logout_hover.bg_color = Color(0.70, 0.12, 0.12)
	logout_btn.add_theme_stylebox_override("normal", logout_s)
	logout_btn.add_theme_stylebox_override("hover", logout_hover)
	logout_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	logout_btn.pressed.connect(func():
		_toggle_char_profile()
		PlayerData.logout()
		var _dlg := LoginDialog.new()
		add_child(_dlg)
	)
	left.add_child(logout_btn)

	left.add_child(HSeparator.new())

	# ── Character sprite display ──
	left.add_child(_make_label("NHÂN VẬT", 9, Color(0.55, 0.80, 0.95), true))
	const _CS_W := 140; const _CS_H := 160
	var char_sprite_frame = Control.new()
	char_sprite_frame.custom_minimum_size = Vector2(_CS_W, _CS_H)
	var char_sv_container = SubViewportContainer.new()
	char_sv_container.size = Vector2(_CS_W, _CS_H)
	char_sv_container.custom_minimum_size = Vector2(_CS_W, _CS_H)
	char_sv_container.stretch = true
	var char_sv = SubViewport.new()
	char_sv.size = Vector2i(_CS_W, _CS_H)
	char_sv.transparent_bg = true
	char_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var char_bg = ColorRect.new()
	char_bg.color = Color(0.10, 0.08, 0.16)
	char_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_sv.add_child(char_bg)
	# Render player sprite inside sub-viewport
	var _char_player_data: Dictionary = GameManager.get_employee(PlayerData.player_id) if \
		GameManager.has_method("get_employee") else {}
	_char_player_data["department"] = PlayerData.department
	var preview_sprite = _AR.make_anim_sprite_for_npc(_char_player_data)
	if preview_sprite == null:
		preview_sprite = _AR.make_sprite(_char_player_data.get("department", "default"))
	if preview_sprite:
		preview_sprite.position = Vector2(_CS_W / 2, _CS_H - 10)
		preview_sprite.scale *= 4.0
		char_sv.add_child(preview_sprite)
	else:
		var fb = Label.new(); fb.text = PlayerData.display_name.left(2).to_upper()
		fb.add_theme_font_size_override("font_size", 38)
		fb.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
		fb.set_anchors_preset(Control.PRESET_CENTER)
		char_sv.add_child(fb)
	char_sv_container.add_child(char_sv)
	char_sprite_frame.add_child(char_sv_container)
	var char_sprite_row = HBoxContainer.new()
	char_sprite_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_sprite_row.add_child(char_sprite_frame)
	left.add_child(char_sprite_row)

	# ── Action buttons: AI Avatar + Thay đổi ngoại hình ──
	var btn_ai_avatar = Button.new()
	btn_ai_avatar.text = "AI Avatar"
	btn_ai_avatar.add_theme_font_size_override("font_size", 9)
	btn_ai_avatar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ai_avatar.pressed.connect(func():
		_toggle_char_profile()
		_toggle_avatar_maker()
	)
	var btn_appearance = Button.new()
	btn_appearance.text = "Ngoại hình"
	btn_appearance.add_theme_font_size_override("font_size", 9)
	btn_appearance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_appearance.pressed.connect(func():
		_toggle_char_profile()
		_toggle_char_gen_panel()
	)
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	action_row.add_child(btn_ai_avatar)
	action_row.add_child(btn_appearance)
	left.add_child(action_row)

	# Right content
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	var right_pad = PanelContainer.new()
	var rps = StyleBoxFlat.new(); rps.bg_color = Color(0,0,0,0)
	rps.content_margin_left = 16; rps.content_margin_right = 16
	rps.content_margin_top = 12; rps.content_margin_bottom = 12
	right_pad.add_theme_stylebox_override("panel", rps)
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_pad.add_child(right); body.add_child(right_pad)
	outer.add_child(body)

	# ── Top row: Tasks + Skills ──
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(top_row)

	# Tasks
	var tasks_col = VBoxContainer.new()
	tasks_col.add_theme_constant_override("separation", 6)
	tasks_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tasks_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_child(tasks_col)
	tasks_col.add_child(_make_label("TASKS ĐANG LÀM", 10, Color(0.55, 0.80, 0.55), true))
	tasks_col.add_child(_cp_section_sep())
	var tasks_data: Array[String] = [
		"Designing ZPS World prototype",
		"Review Sprint 4 backlog",
		"Avatar system redesign",
	]
	for t_str: String in tasks_data:
		var t_row = HBoxContainer.new(); t_row.add_theme_constant_override("separation", 6)
		var dot = ColorRect.new(); dot.color = Color(0.30, 0.70, 0.40); dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t_row.add_child(dot)
		var t_lbl = _make_label(t_str, 10, Color(0.85, 0.88, 0.92))
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_row.add_child(t_lbl); tasks_col.add_child(t_row)

	# Skills / Ability kit
	var skills_col = VBoxContainer.new()
	skills_col.add_theme_constant_override("separation", 6)
	skills_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_child(skills_col)
	skills_col.add_child(_make_label(" SKILL KIT", 10, Color(0.65, 0.55, 0.95), true))
	skills_col.add_child(_cp_section_sep())
	var skills_data: Array = [
		["Q", "GDScript / Godot 4", Color(0.35, 0.55, 0.95)],
		["W", "Game Design", Color(0.65, 0.40, 0.95)],
		["E", "Product Thinking", Color(0.40, 0.75, 0.55)],
		["R", "Systems Thinking", Color(0.90, 0.55, 0.30)],
		["P", "UI/UX Design", Color(0.90, 0.80, 0.30)],
	]
	for sk: Array in skills_data:
		var sk_row = HBoxContainer.new(); sk_row.add_theme_constant_override("separation", 6)
		var badge_panel = PanelContainer.new()
		var bps = StyleBoxFlat.new(); bps.bg_color = (sk[2] as Color).darkened(0.5)
		bps.set_border_width_all(1); bps.border_color = sk[2]; bps.set_corner_radius_all(4)
		bps.content_margin_left = 5; bps.content_margin_right = 5
		bps.content_margin_top = 2; bps.content_margin_bottom = 2
		badge_panel.add_theme_stylebox_override("panel", bps)
		badge_panel.add_child(_make_label(sk[0], 9, sk[2]))
		sk_row.add_child(badge_panel)
		sk_row.add_child(_make_label(sk[1], 10, Color(0.88, 0.88, 0.92)))
		skills_col.add_child(sk_row)

	right.add_child(HSeparator.new())

	# ── Bottom row: Stats + Lore ──
	var bot_row = HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 14)
	bot_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(bot_row)

	# Stats
	var stats_col = VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 5)
	stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_row.add_child(stats_col)
	stats_col.add_child(_make_label("STATS / DIFFICULTY", 10, Color(0.95, 0.60, 0.30), true))
	stats_col.add_child(_cp_section_sep())
	var stats_data: Array = [
		["Creativity", 5, 5],
		["Leadership", 4, 5],
		["Sys. Thinking", 5, 5],
		["AI Adoption", 5, 5],
	]
	for st: Array in stats_data:
		var st_row = HBoxContainer.new(); st_row.add_theme_constant_override("separation", 6)
		var st_name_lbl = _make_label(st[0], 9, Color(0.75, 0.75, 0.80))
		st_name_lbl.custom_minimum_size.x = 85
		st_row.add_child(st_name_lbl)
		# Star bar
		var stars := ""
		for si: int in st[2]:
			stars += "*" if si < st[1] else "-"
		st_row.add_child(_make_label(stars, 10, Color(0.90, 0.72, 0.28)))
		stats_col.add_child(st_row)

	# Lore
	var lore_col = VBoxContainer.new()
	lore_col.add_theme_constant_override("separation", 6)
	lore_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_row.add_child(lore_col)
	lore_col.add_child(_make_label("LORE", 10, Color(0.55, 0.80, 0.90), true))
	lore_col.add_child(_cp_section_sep())
	var lore_text := "Wanderer of the wild."
	var lore_lbl = _make_label(lore_text, 9, Color(0.72, 0.75, 0.80))
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_col.add_child(lore_lbl)

	_char_profile_panel = root
	add_child(_char_profile_panel)

func _cp_section_sep() -> Control:
	var sep = ColorRect.new()
	sep.color = Color(0.65, 0.52, 0.20, 0.40)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sep

func _toggle_char_profile() -> void:
	# Rebuild if destroyed by re-login refresh
	if _char_profile_panel == null:
		_build_char_profile_panel()
	_char_profile_panel.visible = not _char_profile_panel.visible
	if current_player_ref:
		current_player_ref.set_busy(_char_profile_panel.visible)

# Called by player to register itself
func register_player(player: Node) -> void:
	current_player_ref = player
	_refresh_sprint_label()

# ── Online roster panel ──────────────────────────────────────────────────────
func _roster_short_name(full_name: String) -> String:
	# Show only the part before @ (e.g. "sang.vk@vng.com.vn" → "sang.vk")
	var at := full_name.find("@")
	if at > 0:
		return full_name.left(at)
	return full_name

func _build_roster_panel() -> void:
	# Toggle button — Mobile: vertical stack slot 1 (top); Desktop: left of button group
	var btn_anchor = Control.new()
	btn_anchor.anchor_left = 1.0; btn_anchor.anchor_right = 1.0
	btn_anchor.anchor_top = 0.0;  btn_anchor.anchor_bottom = 0.0
	if _is_mobile:
		btn_anchor.offset_left = -68; btn_anchor.offset_right = -4
		btn_anchor.offset_top = 8; btn_anchor.offset_bottom = 8 + 60
	else:
		btn_anchor.offset_left = -200; btn_anchor.offset_right = -152
		btn_anchor.offset_top = 8;    btn_anchor.offset_bottom = 36
	_roster_toggle_btn = Button.new()
	_roster_toggle_btn.text = "Online"
	_roster_toggle_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _is_mobile:
		_roster_toggle_btn.add_theme_font_size_override("font_size", 12)
	_roster_toggle_btn.pressed.connect(_toggle_roster)
	btn_anchor.add_child(_roster_toggle_btn)
	add_child(btn_anchor)

	# Backdrop — click-outside closes roster
	_roster_backdrop = Control.new()
	_roster_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_roster_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_roster_backdrop.visible = false
	_roster_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_toggle_roster()
	)
	add_child(_roster_backdrop)

	# Panel — anchor top-right corner, drops down below button
	_roster_panel = PanelContainer.new()
	_roster_panel.anchor_left = 1.0; _roster_panel.anchor_right = 1.0
	_roster_panel.anchor_top = 0.0;  _roster_panel.anchor_bottom = 0.0
	_roster_panel.offset_left = -278; _roster_panel.offset_right = -8
	_roster_panel.offset_top = 44;   _roster_panel.offset_bottom = 360
	_roster_panel.visible = false
	add_child(_roster_panel)

	var rvbox = VBoxContainer.new()
	rvbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	rvbox.add_theme_constant_override("separation", 2)
	_roster_panel.add_child(rvbox)

	# Header với nút ✕
	var r_hdr = HBoxContainer.new()
	r_hdr.add_theme_constant_override("separation", 4)
	var r_ttl = _make_label("Đang online", 10, Color(0.85, 0.95, 1.0), true)
	r_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_hdr.add_child(r_ttl)
	r_hdr.add_child(_make_x_btn(_toggle_roster))
	rvbox.add_child(r_hdr)
	rvbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_list = VBoxContainer.new()
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_list)
	rvbox.add_child(scroll)

	# Connect to network events
	NetworkManager.roster_received.connect(_on_roster_update)
	NetworkManager.player_joined.connect(func(id, _x, _y, _av): _refresh_roster())
	NetworkManager.player_left.connect(func(_id): _refresh_roster())
	NetworkManager.status_changed.connect(func(_id, _s, _m): _refresh_roster())

func _toggle_roster() -> void:
	var was_open := _roster_open
	_close_side_panels()
	if not was_open:
		_roster_open = true
		if _roster_panel:    _roster_panel.visible    = true
		if _roster_backdrop: _roster_backdrop.visible = true
		_refresh_roster()

func _on_roster_update(_players: Array) -> void:
	_refresh_roster()

func _refresh_roster() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	# Always show self first (count starts at 1)
	var self_row := HBoxContainer.new()
	var self_dot := ColorRect.new()
	self_dot.size = Vector2(8, 8)
	self_dot.color = Color(0.2, 0.9, 0.2)
	self_row.add_child(self_dot)
	var self_lbl := Label.new()
	self_lbl.text = " " + _roster_short_name(PlayerData.display_name) + " (bạn)"
	self_lbl.add_theme_font_size_override("font_size", 10)
	self_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	self_row.add_child(self_lbl)
	_roster_list.add_child(self_row)

	var count := 1
	for id in GameManager.remote_players:
		var rp = GameManager.remote_players[id]
		var row := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.color = Color(0.5, 0.5, 0.5) if rp.is_npc_mode else Color(0.2, 0.9, 0.2)
		row.add_child(dot)
		var lbl := Label.new()
		var name_raw: String = rp.display_name if rp.display_name != "" else id
		lbl.text = " " + _roster_short_name(name_raw)
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)
		_roster_list.add_child(row)
		count += 1
	_roster_toggle_btn.text = "Online (%d)" % count

# ── Sprint 4: Emote Menu ─────────────────────────────────────────────────────

func _toggle_emote_menu() -> void:
	if is_instance_valid(_emote_menu):
		_emote_menu.queue_free()
		_emote_menu = null
		return
	_emote_menu = load("res://scripts/ui/EmoteMenu.gd").new()
	_emote_menu.set_anchors_preset(Control.PRESET_CENTER)
	_emote_menu.emote_selected.connect(func(_key: String): _emote_menu = null)
	add_child(_emote_menu)

func _build_emote_toast_area() -> void:
	_emote_toast_stack = VBoxContainer.new()
	_emote_toast_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_emote_toast_stack.position = Vector2(-180, 60)
	_emote_toast_stack.custom_minimum_size = Vector2(160, 0)
	add_child(_emote_toast_stack)

func _on_emote_toast(from_id: String, emote: String) -> void:
	if _emote_toast_stack == null:
		return
	var display_name: String = from_id
	var emp_data: Dictionary = GameManager.employees.get(from_id, {})
	if emp_data.has("name"):
		display_name = emp_data["name"]
	var label := Label.new()
	label.text = display_name + ": " + _emote_to_text(emote)
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1.0, 0.9, 0.5)
	_emote_toast_stack.add_child(label)
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func _emote_to_text(key: String) -> String:
	match key:
		"wave": return "[Wave]"
		"thumbsup": return "[+1]"
		"clap": return "[Clap!]"
		"question": return "[?]"
		"think": return "[...]"
		"party": return "[Party!]"
		_: return "[" + key + "]"

# ── Sprint 4: DM + Desk helpers ──────────────────────────────────────────────

func open_dm(player_id: String) -> void:
	var chat := get_tree().get_first_node_in_group("chat_log")
	if chat and chat.has_method("open_dm_with"):
		chat.open_dm_with(player_id)
	if workspace_panel:
		workspace_panel.visible = true

func open_remote_desk(player_id: String) -> void:
	if HttpManager.jwt_token.is_empty():
		GameManager.notify("Khong the tai desk cua " + player_id, "error")
		return
	var ep := "players/%s/desk" % player_id
	HttpManager.get_request(ep)
	HttpManager.response_received.connect(
		func(endpoint: String, data: Variant):
			if endpoint != ep:
				return
			if data is Dictionary:
				_show_remote_desk_view(player_id, (data as Dictionary).get("desk_layout", [])),
		CONNECT_ONE_SHOT
	)
	HttpManager.error.connect(
		func(endpoint: String, _msg: String):
			if endpoint != ep:
				return
			GameManager.notify("Khong tim thay desk cua " + player_id, "warning"),
		CONNECT_ONE_SHOT
	)

func _show_remote_desk_view(player_id: String, layout: Array) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320, 240)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Desk of " + player_id
	title.add_theme_font_size_override("font_size", 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	for i in 12:
		var lbl := Label.new()
		var item_id: String = layout[i] if i < layout.size() else ""
		lbl.text = item_id.replace("_", " ").capitalize() if item_id != "" else "[ ]"
		lbl.custom_minimum_size = Vector2(64, 48)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		grid.add_child(lbl)
	vbox.add_child(grid)

	var close_btn := Button.new()
	close_btn.text = "Dong"
	close_btn.pressed.connect(panel.queue_free)
	vbox.add_child(close_btn)

func set_zone_hint(hint_key: String) -> void:
	if not is_instance_valid(_zone_label):
		return
	match hint_key:
		"near_own_desk":
			if not _zone_label.text.contains("[D]"):
				_zone_label.text = _zone_label.text + " [D] Desk Editor"
		_:
			var parts := _zone_label.text.split(" [D]")
			_zone_label.text = parts[0]
