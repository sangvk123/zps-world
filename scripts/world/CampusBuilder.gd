## CampusBuilder.gd
## Loads campus_layout.json and renders the full map using ONLY real tile assets.
##
## Floor rendering strategy: per-room composited Image → single Sprite2D per room.
##   This keeps node count low (~10 sprites instead of ~4000).
##
## Furniture rendering: one Sprite2D per entity using AtlasTexture.
##
## Collision walls: one StaticBody2D per room boundary (4 sides = 4 segments).
##
## Usage (attach to a Node2D scene):
##   var builder = preload("res://scripts/world/CampusBuilder.gd")
##   builder.build(self, "res://assets/maps/campus_layout.json")

class_name CampusBuilder

const TILE_PX: int = 16

# ── Texture cache ─────────────────────────────────────────────────────────────
static var _tex_cache: Dictionary = {}

static func _get_tex(res_path: String) -> Texture2D:
	if _tex_cache.has(res_path):
		return _tex_cache[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var loaded = ResourceLoader.load(res_path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs):
			var img := Image.load_from_file(abs)
			if img:
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_warning("[CampusBuilder] texture not found: %s" % res_path)
	_tex_cache[res_path] = tex
	return tex


# ── Image cache for per-source blitting ───────────────────────────────────────
static var _img_cache: Dictionary = {}

static func _get_img(res_path: String) -> Image:
	if _img_cache.has(res_path):
		return _img_cache[res_path]
	var abs := ProjectSettings.globalize_path(res_path)
	var img: Image = null
	if FileAccess.file_exists(abs):
		img = Image.load_from_file(abs)
	if img == null:
		push_warning("[CampusBuilder] image not found: %s" % res_path)
	_img_cache[res_path] = img
	return img


# ── Entry point ───────────────────────────────────────────────────────────────
static func build(parent: Node2D, layout_path: String) -> void:
	var layout := _load_json(layout_path)
	if layout.is_empty():
		push_error("[CampusBuilder] Failed to load: %s" % layout_path)
		return

	var cols: int   = layout.get("cols", 80)
	var rows: int   = layout.get("rows", 60)
	var tile_px: int = layout.get("tile_px", TILE_PX)

	var floors_ts: String    = layout.get("tileset_floors", "")
	var generic_ts: String   = layout.get("tileset_generic", "")
	var sprite_defs: Dictionary = layout.get("sprite_defs", {})
	var rooms: Array         = layout.get("rooms", [])
	var entities: Array      = layout.get("entities", [])

	# ── Layer containers ───────────────────────────────────────────────────────
	var floor_layer := Node2D.new()
	floor_layer.name = "FloorLayer"
	floor_layer.z_index = -10
	parent.add_child(floor_layer)

	var furniture_layer := Node2D.new()
	furniture_layer.name = "FurnitureLayer"
	furniture_layer.y_sort_enabled = true
	furniture_layer.z_index = 0
	parent.add_child(furniture_layer)

	var collision_layer := Node2D.new()
	collision_layer.name = "CollisionLayer"
	parent.add_child(collision_layer)

	# ── Build floors ───────────────────────────────────────────────────────────
	for room_def: Dictionary in rooms:
		_build_room_floor(floor_layer, room_def, floors_ts, tile_px)

	# ── Build furniture ────────────────────────────────────────────────────────
	_build_entities(furniture_layer, entities, sprite_defs, generic_ts, tile_px)

	# ── Build collision walls ──────────────────────────────────────────────────
	_build_walls(collision_layer, rooms, cols, rows, tile_px)

	print("[CampusBuilder] Built: %d rooms, %d entities" % [rooms.size(), entities.size()])


# ── Floor: compose one Image per room, display as Sprite2D ───────────────────
static func _build_room_floor(
		parent: Node2D,
		room: Dictionary,
		floors_ts: String,
		tile_px: int) -> void:

	var rx: int = room.get("x", 0)
	var ry: int = room.get("y", 0)
	var rw: int = room.get("w", 1)
	var rh: int = room.get("h", 1)
	var floor_tile: Array = room.get("floor", [0, 0])
	var floor_ts: String  = room.get("floor_tileset", floors_ts)

	var src_img := _get_img(floor_ts)
	if src_img == null:
		return

	var tc: int = int(floor_tile[0])
	var tr: int = int(floor_tile[1])
	var src_rect := Rect2i(tc * tile_px, tr * tile_px, tile_px, tile_px)

	# Compose the room floor as a single image
	var room_img := Image.create(rw * tile_px, rh * tile_px, false, Image.FORMAT_RGBA8)
	for dr: int in range(rh):
		for dc: int in range(rw):
			room_img.blit_rect(src_img, src_rect, Vector2i(dc * tile_px, dr * tile_px))

	var room_tex := ImageTexture.create_from_image(room_img)
	var sp := Sprite2D.new()
	sp.name = "Floor_" + room.get("id", "room")
	sp.texture = room_tex
	sp.centered = false
	sp.position = Vector2(float(rx * tile_px), float(ry * tile_px))
	sp.z_index = -10
	parent.add_child(sp)

	# Optional: room label
	var label_text: String = room.get("label", "")
	if label_text != "":
		var lbl := Label.new()
		lbl.text = label_text
		lbl.position = Vector2(float(rx * tile_px + 4), float(ry * tile_px + 4))
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.modulate = Color(1.0, 1.0, 0.7, 0.65)
		lbl.z_index = 5
		parent.add_child(lbl)


# ── Furniture: one Sprite2D (or Node2D container) per entity ─────────────────
static func _build_entities(
		parent: Node2D,
		entities: Array,
		sprite_defs: Dictionary,
		default_ts: String,
		tile_px: int) -> void:

	# Build tileset image cache from sprite_defs
	var ts_map: Dictionary = {}  # short key → res:// path
	for sp_id: String in sprite_defs:
		var def: Dictionary = sprite_defs[sp_id]
		var ts_key: String = def.get("ts", "generic")
		if not ts_map.has(ts_key):
			if ts_key == "generic":
				ts_map[ts_key] = default_ts
			else:
				ts_map[ts_key] = default_ts  # fallback

	for ent: Dictionary in entities:
		var sp_id: String = ent.get("sprite", "")
		if not sprite_defs.has(sp_id):
			push_warning("[CampusBuilder] Unknown sprite: '%s'" % sp_id)
			continue

		var def: Dictionary = sprite_defs[sp_id]
		var ts_key: String  = def.get("ts", "generic")
		var ts_path: String = ts_map.get(ts_key, default_ts)
		var src_col: int    = int(def.get("col", 0))
		var src_row: int    = int(def.get("row", 0))
		var sp_w: int       = int(def.get("w", 1))
		var sp_h: int       = int(def.get("h", 1))
		var fmt: String     = def.get("fmt", "grid")
		var z_idx: int      = int(ent.get("z", 1))

		var ent_col: int = int(ent.get("col", 0))
		var ent_row: int = int(ent.get("row", 0))

		var node: Node2D
		if fmt == "packed":
			node = _make_packed_sprite(ts_path, src_col, src_row, sp_w, sp_h, tile_px)
		else:
			node = _make_grid_sprite(ts_path, src_col, src_row, sp_w, sp_h, tile_px)

		if node:
			node.position = Vector2(float(ent_col * tile_px), float(ent_row * tile_px))
			node.z_index = z_idx
			node.name = sp_id + "_%d_%d" % [ent_col, ent_row]

			# Attach metadata for game logic
			node.set_meta("sprite_id", sp_id)
			if ent.has("interact"):
				node.set_meta("interact_type", ent["interact"])
			if ent.has("desk_id"):
				node.set_meta("desk_id", ent["desk_id"])

			parent.add_child(node)


# ── Sprite factory — grid format ──────────────────────────────────────────────
static func _make_grid_sprite(
		ts_path: String,
		src_col: int, src_row: int,
		w: int, h: int, tile_px: int) -> Node2D:

	var tex := _get_tex(ts_path)
	if tex == null:
		return null

	var container := Node2D.new()
	for dy: int in range(h):
		for dx: int in range(w):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2((src_col + dx) * tile_px, (src_row + dy) * tile_px,
								  tile_px, tile_px)
			atlas.filter_clip = true
			var sp := Sprite2D.new()
			sp.texture = atlas
			sp.centered = false
			sp.position = Vector2(float(dx * tile_px), float(dy * tile_px))
			container.add_child(sp)
	return container


# ── Sprite factory — packed format ────────────────────────────────────────────
# Packed: w*h tiles in ONE sheet row; reassemble as w×h display
static func _make_packed_sprite(
		ts_path: String,
		src_col: int, src_row: int,
		disp_w: int, disp_h: int, tile_px: int) -> Node2D:

	var tex := _get_tex(ts_path)
	if tex == null:
		return null

	var container := Node2D.new()
	var count: int = disp_w * disp_h
	for i: int in range(count):
		var dc: int = i % disp_w
		var dr: int = i / disp_w
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2((src_col + i) * tile_px, src_row * tile_px,
							  tile_px, tile_px)
		atlas.filter_clip = true
		var sp := Sprite2D.new()
		sp.texture = atlas
		sp.centered = false
		sp.position = Vector2(float(dc * tile_px), float(dr * tile_px))
		container.add_child(sp)
	return container


# ── Collision walls ───────────────────────────────────────────────────────────
# One StaticBody2D rectangle per room boundary.
# Wall thickness = 1 tile (no floor rendered there → dark gap visible).
static func _build_walls(
		parent: Node2D,
		rooms: Array,
		_map_cols: int, _map_rows: int,
		tile_px: int) -> void:

	# Collect all room floor cells into a set
	var floor_cells: Dictionary = {}
	for room: Dictionary in rooms:
		var rx: int = room.get("x", 0)
		var ry: int = room.get("y", 0)
		var rw: int = room.get("w", 1)
		var rh: int = room.get("h", 1)
		for dc: int in range(rw):
			for dr: int in range(rh):
				floor_cells[Vector2i(rx + dc, ry + dr)] = true

	# Walls = everything not in floor_cells that's adjacent to a floor cell.
	# Instead of per-cell walls, add StaticBody2D borders for each room.
	for room: Dictionary in rooms:
		var room_type: String = room.get("type", "")
		if room_type == "corridor":
			continue  # corridors passable

		var rx: int  = room.get("x", 0)
		var ry: int  = room.get("y", 0)
		var rw: int  = room.get("w", 1)
		var rh: int  = room.get("h", 1)

		# One static body per room wall segment
		var px := float(rx * tile_px)
		var py := float(ry * tile_px)
		var pw := float(rw * tile_px)
		var ph := float(rh * tile_px)

		_add_wall_rect(parent, px - float(tile_px),
					   py - float(tile_px),
					   pw + float(tile_px * 2),
					   float(tile_px),
					   "WallN_" + room.get("id", ""))  # north wall
		_add_wall_rect(parent, px - float(tile_px),
					   py + ph,
					   pw + float(tile_px * 2),
					   float(tile_px),
					   "WallS_" + room.get("id", ""))  # south wall
		_add_wall_rect(parent, px - float(tile_px),
					   py,
					   float(tile_px),
					   ph,
					   "WallW_" + room.get("id", ""))  # west wall
		_add_wall_rect(parent, px + pw,
					   py,
					   float(tile_px),
					   ph,
					   "WallE_" + room.get("id", ""))  # east wall


static func _add_wall_rect(parent: Node2D,
		x: float, y: float, w: float, h: float, node_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = Vector2(x, y)
	body.collision_layer = 1
	body.collision_mask  = 0

	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(w * 0.5, h * 0.5)
	body.add_child(shape)
	parent.add_child(body)


# ── JSON helper ───────────────────────────────────────────────────────────────
static func _load_json(path: String) -> Dictionary:
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		push_error("[CampusBuilder] File not found: %s" % path)
		return {}
	var f := FileAccess.open(abs, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var result = JSON.parse_string(text)
	if result is Dictionary:
		return result
	push_error("[CampusBuilder] JSON parse error: %s" % path)
	return {}
