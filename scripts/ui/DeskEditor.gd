## DeskEditor.gd
## Desk decoration editor — 4 columns × 3 rows = 12 slots.
## Press D while near own desk to open.
## Shows earned desk_items from PlayerData.earned_cosmetics["desk_items"].

class_name DeskEditor
extends PanelContainer

const GRID_COLS: int = 4
const GRID_ROWS: int = 3
const SLOT_COUNT: int = 12

const DEFAULT_ITEMS: Array = [
	{"id": "plant",       "name": "Plant"},
	{"id": "mug",         "name": "Coffee Mug"},
	{"id": "photo_frame", "name": "Photo Frame"},
	{"id": "sticky_note", "name": "Sticky Note"},
	{"id": "lamp",        "name": "Desk Lamp"},
	{"id": "cactus",      "name": "Cactus"},
]

var _layout: Array[String] = []
var _slot_btns: Array[Button] = []
var _selected_item_id: String = ""
var _item_palette_btns: Array[Button] = []
var _available_items: Array = []

signal closed()

func _ready() -> void:
	_layout.resize(SLOT_COUNT)
	_layout.fill("")
	_load_current_layout()
	_build_ui()

func _load_current_layout() -> void:
	var saved: Array = PlayerData.desk_decorations
	for i in SLOT_COUNT:
		_layout[i] = saved[i] if i < saved.size() else ""

func _get_available_items() -> Array:
	var items: Array = DEFAULT_ITEMS.duplicate()
	var earned: Array = PlayerData.earned_cosmetics.get("desk_items", [])
	for item_id in earned:
		var already := false
		for existing in items:
			if existing["id"] == item_id:
				already = true
				break
		if not already:
			items.append({"id": item_id, "name": item_id.replace("_", " ").capitalize()})
	return items

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	style.set_corner_radius_all(10)
	style.border_color = Color(0.35, 0.45, 0.55)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(360, 380)
	set_anchors_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Desk Decorator"
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.75, 0.9, 1.0)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Chon item tu palette, sau do nhan o trong o de dat."
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.6, 0.6, 0.6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	vbox.add_child(grid)

	_slot_btns.clear()
	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 56)
		var capture_i := i
		btn.pressed.connect(func(): _on_slot_pressed(capture_i))
		grid.add_child(btn)
		_slot_btns.append(btn)
	_refresh_grid_display()

	vbox.add_child(HSeparator.new())

	var palette_label := Label.new()
	palette_label.text = "Item Palette:"
	palette_label.add_theme_font_size_override("font_size", 11)
	palette_label.modulate = Color(0.7, 0.85, 1.0)
	vbox.add_child(palette_label)

	var palette_scroll := ScrollContainer.new()
	palette_scroll.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(palette_scroll)

	var palette_flow := HBoxContainer.new()
	palette_scroll.add_child(palette_flow)

	_available_items = _get_available_items()
	_item_palette_btns.clear()

	var eraser_btn := Button.new()
	eraser_btn.text = "[Xoa]"
	eraser_btn.custom_minimum_size = Vector2(60, 40)
	eraser_btn.toggle_mode = true
	eraser_btn.pressed.connect(func():
		_selected_item_id = ""
		_update_palette_selection(-1)
	)
	palette_flow.add_child(eraser_btn)
	_item_palette_btns.append(eraser_btn)

	for i in _available_items.size():
		var item: Dictionary = _available_items[i]
		var btn := Button.new()
		btn.text = item["name"]
		btn.custom_minimum_size = Vector2(80, 40)
		btn.toggle_mode = true
		var capture_i := i
		btn.pressed.connect(func():
			_selected_item_id = _available_items[capture_i]["id"]
			_update_palette_selection(capture_i + 1)
		)
		palette_flow.add_child(btn)
		_item_palette_btns.append(btn)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)

	var save_btn := Button.new()
	save_btn.text = "Luu Desk"
	save_btn.pressed.connect(_on_save)
	footer.add_child(save_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Xoa het"
	clear_btn.pressed.connect(_on_clear_all)
	footer.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "Dong"
	close_btn.pressed.connect(_on_close)
	footer.add_child(close_btn)

func _on_slot_pressed(slot_index: int) -> void:
	_layout[slot_index] = _selected_item_id
	_refresh_grid_display()

func _refresh_grid_display() -> void:
	for i in SLOT_COUNT:
		var btn := _slot_btns[i]
		var item_id: String = _layout[i]
		if item_id == "":
			btn.text = "[Empty]"
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = item_id.replace("_", " ").capitalize()
			btn.modulate = Color(1.0, 1.0, 1.0)

func _update_palette_selection(selected_index: int) -> void:
	for i in _item_palette_btns.size():
		_item_palette_btns[i].button_pressed = (i == selected_index)

func _on_save() -> void:
	PlayerData.update_desk_layout(_layout)
	GameManager.notify("Desk da luu!", "success")
	closed.emit()
	queue_free()

func _on_clear_all() -> void:
	_layout.fill("")
	_refresh_grid_display()

func _on_close() -> void:
	closed.emit()
	queue_free()
