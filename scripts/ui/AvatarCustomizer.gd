## AvatarCustomizer.gd
## Full avatar customization panel — built entirely in code, no .tscn dependency.
## Tabs: Appearance, Outfit, Accessories, AI Agent
## Shift+A to open/close via HUD.

extends Control

# ── Internal state ──
var pending_config: Dictionary = {}
var is_dirty: bool = false

# ── Node references (created in _build_ui) ──
var _tab_bar: TabContainer = null
var _preview_container: Control = null
var _preview_sprite: Control = null       # ColorRect fallback preview
var _save_btn: Button = null
var _close_btn: Button = null

# Appearance tab controls
var _body_type_btn: OptionButton = null
var _skin_tone_btns: Array[Button] = []
var _hair_style_btn: OptionButton = null
var _hair_color_btns: Array[Button] = []
var _eye_color_btn: OptionButton = null

# Outfit tab
var _outfit_grid: GridContainer = null
var _today_outfit_label: Label = null

# Accessories tab
var _accessory_grid: GridContainer = null

# AI Agent tab
var _ai_enable_toggle: CheckButton = null
var _ai_context_input: TextEdit = null
var _ai_test_result: Label = null

# Skin tone palette (0-4)
const SKIN_COLORS: Array = [
	Color(1.0, 0.87, 0.73),   # 0 — fair
	Color(0.96, 0.76, 0.57),  # 1 — light
	Color(0.82, 0.60, 0.38),  # 2 — medium
	Color(0.62, 0.41, 0.22),  # 3 — tan
	Color(0.37, 0.22, 0.10),  # 4 — deep
]

# Hair color palette (0-5)
const HAIR_COLORS: Array = [
	Color(0.10, 0.07, 0.05),  # 0 — black
	Color(0.35, 0.20, 0.08),  # 1 — dark brown
	Color(0.60, 0.38, 0.14),  # 2 — brown
	Color(0.84, 0.65, 0.22),  # 3 — blonde
	Color(0.80, 0.30, 0.10),  # 4 — auburn
	Color(0.75, 0.75, 0.78),  # 5 — silver
]

const ALL_OUTFITS: Array = [
	{"id": "work_casual",    "name": "Work Casual",     "locked": false},
	{"id": "formal",         "name": "Formal",           "locked": false},
	{"id": "creative",       "name": "Creative",         "locked": false},
	{"id": "initiate_class", "name": "Initiate Class",   "locked": false},
	{"id": "game_dev",       "name": "Game Dev Kit",     "locked": true, "req": "First Campaign"},
	{"id": "dragon_slayer",  "name": "Dragon Slayer",    "locked": true, "req": "Dragon Slayer Achievement"},
	{"id": "legend_tier",    "name": "Legend Tier",      "locked": true, "req": "Hall of Legends"},
]

const ALL_ACCESSORIES: Array = [
	{"id": "glasses_round",   "name": "Round Glasses",  "slot": "glasses", "locked": false},
	{"id": "glasses_square",  "name": "Square Glasses", "slot": "glasses", "locked": false},
	{"id": "hat_cap",         "name": "Baseball Cap",   "slot": "hat",     "locked": false},
	{"id": "hat_beanie",      "name": "Beanie",         "slot": "hat",     "locked": false},
	{"id": "earring_simple",  "name": "Simple Earring", "slot": "earring", "locked": false},
	{"id": "badge_star",      "name": "Star Badge",     "slot": "badge",   "locked": true,  "req": "Top Performer"},
	{"id": "halo_angel",      "name": "Angel Halo",     "slot": "halo",    "locked": true,  "req": "1 Year ZPS"},
]

func _ready() -> void:
	_build_ui()
	AIAgent.response_ready.connect(_on_ai_test_response)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "Avatar Customizer"
	header.add_theme_font_size_override("font_size", 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(0.6, 0.9, 1.0)
	vbox.add_child(header)

	_preview_container = _build_preview_strip()
	vbox.add_child(_preview_container)

	_tab_bar = TabContainer.new()
	_tab_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_bar)

	_build_appearance_tab()
	_build_outfit_tab()
	_build_accessories_tab()
	_build_ai_agent_tab()

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)

	_save_btn = Button.new()
	_save_btn.text = "Luu Avatar"
	_save_btn.pressed.connect(_on_save)
	footer.add_child(_save_btn)

	_close_btn = Button.new()
	_close_btn.text = "Dong"
	_close_btn.pressed.connect(_on_close)
	footer.add_child(_close_btn)

func _build_preview_strip() -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 80)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14)
	style.set_corner_radius_all(6)
	container.add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(hbox)
	_preview_sprite = ColorRect.new()
	_preview_sprite.name = "AvatarPreview"
	_preview_sprite.custom_minimum_size = Vector2(40, 60)
	_preview_sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_preview_sprite)
	return container

func _refresh_preview() -> void:
	if _preview_sprite == null:
		return
	var skin_idx: int = pending_config.get("skin_tone", 1)
	if skin_idx >= 0 and skin_idx < SKIN_COLORS.size():
		_preview_sprite.color = SKIN_COLORS[skin_idx]

func _build_appearance_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Appearance"
	_tab_bar.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	vbox.add_child(_section_label("Body Type"))
	_body_type_btn = OptionButton.new()
	_body_type_btn.add_item("Slim",   0)
	_body_type_btn.add_item("Medium", 1)
	_body_type_btn.add_item("Broad",  2)
	_body_type_btn.item_selected.connect(func(idx: int):
		pending_config["body_type"] = idx
		is_dirty = true
		_refresh_preview()
	)
	vbox.add_child(_body_type_btn)

	vbox.add_child(_section_label("Skin Tone"))
	var skin_row := HBoxContainer.new()
	_skin_tone_btns.clear()
	for i in SKIN_COLORS.size():
		var btn := ColorPickerButton.new()
		btn.color = SKIN_COLORS[i]
		btn.custom_minimum_size = Vector2(36, 36)
		btn.toggle_mode = true
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		var capture_i := i
		btn.pressed.connect(func():
			pending_config["skin_tone"] = capture_i
			is_dirty = true
			_refresh_preview()
			for j in _skin_tone_btns.size():
				_skin_tone_btns[j].button_pressed = (j == capture_i)
		)
		skin_row.add_child(btn)
		_skin_tone_btns.append(btn)
	vbox.add_child(skin_row)

	vbox.add_child(_section_label("Hair Style"))
	_hair_style_btn = OptionButton.new()
	var hair_styles := ["Short Crop", "Medium Waves", "Long Straight", "Curly Afro",
						"Side Part", "Bun", "Mohawk", "Buzz Cut"]
	for i in hair_styles.size():
		_hair_style_btn.add_item(hair_styles[i], i)
	_hair_style_btn.item_selected.connect(func(idx: int):
		pending_config["hair_style"] = idx
		is_dirty = true
	)
	vbox.add_child(_hair_style_btn)

	vbox.add_child(_section_label("Hair Color"))
	var hair_row := HBoxContainer.new()
	_hair_color_btns.clear()
	for i in HAIR_COLORS.size():
		var btn := ColorPickerButton.new()
		btn.color = HAIR_COLORS[i]
		btn.custom_minimum_size = Vector2(36, 36)
		btn.toggle_mode = true
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		var capture_i := i
		btn.pressed.connect(func():
			pending_config["hair_color"] = capture_i
			is_dirty = true
			for j in _hair_color_btns.size():
				_hair_color_btns[j].button_pressed = (j == capture_i)
		)
		hair_row.add_child(btn)
		_hair_color_btns.append(btn)
	vbox.add_child(hair_row)

	vbox.add_child(_section_label("Eye Color"))
	_eye_color_btn = OptionButton.new()
	var eye_colors := ["Dark Brown", "Brown", "Hazel", "Green", "Blue"]
	for i in eye_colors.size():
		_eye_color_btn.add_item(eye_colors[i], i)
	_eye_color_btn.item_selected.connect(func(idx: int):
		pending_config["eye_color"] = idx
		is_dirty = true
	)
	vbox.add_child(_eye_color_btn)

func _build_outfit_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Outfit"
	_tab_bar.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	_today_outfit_label = Label.new()
	_today_outfit_label.add_theme_font_size_override("font_size", 11)
	_today_outfit_label.modulate = Color(0.7, 1.0, 0.7)
	vbox.add_child(_today_outfit_label)
	_outfit_grid = GridContainer.new()
	_outfit_grid.columns = 3
	vbox.add_child(_outfit_grid)

func _build_accessories_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Accessories"
	_tab_bar.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	var info := Label.new()
	info.text = "Click to equip / unequip. Locked items require achievements."
	info.add_theme_font_size_override("font_size", 10)
	info.modulate = Color(0.7, 0.7, 0.7)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)
	_accessory_grid = GridContainer.new()
	_accessory_grid.columns = 3
	vbox.add_child(_accessory_grid)

func _build_ai_agent_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "AI Agent"
	_tab_bar.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	vbox.add_child(_section_label("AI Agent khi offline"))
	_ai_enable_toggle = CheckButton.new()
	_ai_enable_toggle.text = "Bat AI Agent khi offline"
	vbox.add_child(_ai_enable_toggle)
	vbox.add_child(_section_label("AI Context (AI biet gi ve ban?)"))
	_ai_context_input = TextEdit.new()
	_ai_context_input.custom_minimum_size = Vector2(0, 100)
	_ai_context_input.placeholder_text = "Vi du: Toi la designer, chuyen product UI..."
	vbox.add_child(_ai_context_input)
	var test_btn := Button.new()
	test_btn.text = "Test AI Agent"
	test_btn.pressed.connect(_on_test_ai_agent)
	vbox.add_child(test_btn)
	_ai_test_result = Label.new()
	_ai_test_result.add_theme_font_size_override("font_size", 10)
	_ai_test_result.modulate = Color(0.8, 0.9, 0.8)
	_ai_test_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_ai_test_result)

func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.6, 0.8, 1.0)
	return lbl

func refresh() -> void:
	pending_config = PlayerData.avatar_config.duplicate(true)
	is_dirty = false
	_sync_controls_to_config()
	_populate_outfit_grid()
	_populate_accessories_grid()
	_update_today_label()
	if is_instance_valid(_ai_enable_toggle):
		_ai_enable_toggle.button_pressed = PlayerData.ai_agent_enabled
	if is_instance_valid(_ai_context_input):
		_ai_context_input.text = PlayerData.ai_agent_context
	_refresh_preview()

func _sync_controls_to_config() -> void:
	if is_instance_valid(_body_type_btn):
		_body_type_btn.selected = pending_config.get("body_type", 0)
	if is_instance_valid(_hair_style_btn):
		_hair_style_btn.selected = pending_config.get("hair_style", 0)
	if is_instance_valid(_eye_color_btn):
		_eye_color_btn.selected = pending_config.get("eye_color", 0)
	var skin_idx: int = pending_config.get("skin_tone", 1)
	for i in _skin_tone_btns.size():
		_skin_tone_btns[i].button_pressed = (i == skin_idx)
	var hair_color_idx: int = pending_config.get("hair_color", 0)
	for i in _hair_color_btns.size():
		_hair_color_btns[i].button_pressed = (i == hair_color_idx)

func _populate_outfit_grid() -> void:
	if _outfit_grid == null:
		return
	for child in _outfit_grid.get_children():
		child.queue_free()
	for outfit in ALL_OUTFITS:
		var card := _create_outfit_card(outfit)
		_outfit_grid.add_child(card)

func _create_outfit_card(outfit: Dictionary) -> PanelContainer:
	var is_current := outfit["id"] == PlayerData.current_outfit
	var is_locked := outfit.get("locked", false) and outfit["id"] not in PlayerData.unlocked_outfits
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_current:
		style.bg_color = Color(0.20, 0.38, 0.20)
		style.border_color = Color(0.4, 0.85, 0.4)
		style.set_border_width_all(2)
	elif is_locked:
		style.bg_color = Color(0.10, 0.10, 0.12)
	else:
		style.bg_color = Color(0.16, 0.18, 0.22)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(100, 80)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = outfit["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.modulate = Color(0.5, 0.5, 0.5) if is_locked else Color.WHITE
	vbox.add_child(name_lbl)
	if is_locked:
		var lock_lbl := Label.new()
		lock_lbl.text = "[Khoa]\n" + outfit.get("req", "???")
		lock_lbl.add_theme_font_size_override("font_size", 8)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.modulate = Color(0.5, 0.5, 0.5)
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(lock_lbl)
	else:
		var equip_btn := Button.new()
		equip_btn.text = "Dang mac" if is_current else "Mac hom nay"
		equip_btn.disabled = is_current
		equip_btn.pressed.connect(func(): _equip_outfit(outfit["id"]))
		vbox.add_child(equip_btn)
	return panel

func _equip_outfit(outfit_id: String) -> void:
	PlayerData.set_outfit_for_today(outfit_id)
	_populate_outfit_grid()
	_update_today_label()
	is_dirty = false

func _update_today_label() -> void:
	if is_instance_valid(_today_outfit_label):
		_today_outfit_label.text = "Hom nay: %s" % PlayerData.current_outfit.replace("_", " ").capitalize()

func _populate_accessories_grid() -> void:
	if _accessory_grid == null:
		return
	for child in _accessory_grid.get_children():
		child.queue_free()
	var equipped: Array = pending_config.get("accessories", [])
	for acc in ALL_ACCESSORIES:
		var card := _create_accessory_card(acc, equipped)
		_accessory_grid.add_child(card)

func _create_accessory_card(acc: Dictionary, equipped: Array) -> PanelContainer:
	var is_equipped := acc["id"] in equipped
	var earned_cosmetics: Dictionary = PlayerData.earned_cosmetics
	var earned_list: Array = earned_cosmetics.get("accessories", [])
	var is_locked := acc.get("locked", false) and acc["id"] not in earned_list
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.18, 0.30, 0.38)
		style.border_color = Color(0.4, 0.75, 1.0)
		style.set_border_width_all(2)
	elif is_locked:
		style.bg_color = Color(0.10, 0.10, 0.12)
	else:
		style.bg_color = Color(0.16, 0.18, 0.22)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(100, 70)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = acc["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.modulate = Color(0.5, 0.5, 0.5) if is_locked else Color.WHITE
	vbox.add_child(name_lbl)
	if is_locked:
		var lock_lbl := Label.new()
		lock_lbl.text = "[Khoa]: " + acc.get("req", "???")
		lock_lbl.add_theme_font_size_override("font_size", 8)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.modulate = Color(0.5, 0.5, 0.5)
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(lock_lbl)
	else:
		var toggle_btn := Button.new()
		toggle_btn.text = "Go bo" if is_equipped else "Trang bi"
		toggle_btn.pressed.connect(func(): _toggle_accessory(acc["id"]))
		vbox.add_child(toggle_btn)
	return panel

func _toggle_accessory(acc_id: String) -> void:
	var equipped: Array = pending_config.get("accessories", []).duplicate()
	if acc_id in equipped:
		equipped.erase(acc_id)
	else:
		equipped.append(acc_id)
	pending_config["accessories"] = equipped
	is_dirty = true
	_populate_accessories_grid()

func _on_test_ai_agent() -> void:
	if not is_instance_valid(_ai_test_result):
		return
	_ai_test_result.text = "Dang test..."
	AIAgent.ask_self_agent("Ban dang lam gi vay?")

func _on_ai_test_response(response: String, context_id: String) -> void:
	if not context_id.begins_with("self_"):
		return
	if is_instance_valid(_ai_test_result):
		_ai_test_result.text = "AI se tra loi: \"%s\"" % response

func _on_save() -> void:
	PlayerData.update_avatar(pending_config)
	if is_instance_valid(_ai_enable_toggle):
		PlayerData.ai_agent_enabled = _ai_enable_toggle.button_pressed
	if is_instance_valid(_ai_context_input):
		PlayerData.set_ai_context(_ai_context_input.text)
	NetworkManager.send_status("online", "")
	GameManager.notify("Avatar da luu!", "success")
	is_dirty = false

func _on_close() -> void:
	if is_dirty:
		GameManager.notify("Co thay doi chua luu — da huy.", "warning")
		pending_config = PlayerData.avatar_config.duplicate(true)
		is_dirty = false
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_toggle_avatar_customizer"):
		hud._toggle_avatar_customizer()
	else:
		hide()
