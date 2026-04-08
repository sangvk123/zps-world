## RoomLoader.gd
## Loads a room_layout.json file and instantiates:
##   - Floor tiles via TileMapLayer
##   - Furniture/decoration sprites via WorldBuilder
##
## Usage:
##   RoomLoader.load_into(parent_node, "res://assets/maps/office_layout.json", origin)
##
## Room layout JSON format:
##   {
##     "room_id": "office",
##     "tileset": "1_Generic_16x16",       # PNG stem under themes/
##     "cols": 32, "rows": 22,
##     "floor": {
##       "fill_tile": [col, row],           # tile coords in tileset for interior
##       "border_tiles": {                  # optional per-edge overrides
##         "tl":[c,r], "tc":[c,r], "tr":[c,r],
##         "ml":[c,r], "mr":[c,r],
##         "bl":[c,r], "bc":[c,r], "br":[c,r]
##       }
##     },
##     "entities": [
##       { "sprite": "desk_wood", "col": 1, "row": 2, "z": 1 },
##       ...
##     ]
##   }
##
## Sprite registry: each "sprite" id maps to a descriptor below.

class_name RoomLoader

const _WB   := preload("res://scripts/world/WorldBuilder.gd")
const TILE_PX: int = 16
const TILESET_BASE := "res://assets/tilesets/modern_interiors/themes/"

# ---------------------------------------------------------------------------
# Sprite registry — mirrors generate_room_layout.py SPRITES dict
# fmt: "grid"   → w×h grid of tiles starting at (col, row)
# fmt: "packed" → w*h tiles packed in ONE row; reassembled as w×h display
# ---------------------------------------------------------------------------
const SPRITE_DEFS: Dictionary = {
	# Floor fill tiles (single)
	"floor_wood_natural_mc":   {"tileset": "1_Generic_16x16", "col": 4,  "row": 35, "w": 1, "h": 1, "fmt": "grid"},
	"floor_wood_medium_tc":    {"tileset": "1_Generic_16x16", "col": 4,  "row": 30, "w": 1, "h": 1, "fmt": "grid"},

	# Furniture — grid format
	"desk_wood":               {"tileset": "1_Generic_16x16", "col": 0,  "row": 52, "w": 3, "h": 2, "fmt": "grid"},
	"desk_wood2":              {"tileset": "1_Generic_16x16", "col": 9,  "row": 71, "w": 5, "h": 1, "fmt": "grid"},
	"bookshelf_wood":          {"tileset": "1_Generic_16x16", "col": 0,  "row": 15, "w": 3, "h": 2, "fmt": "grid"},
	"tv_screen":               {"tileset": "1_Generic_16x16", "col": 4,  "row": 45, "w": 4, "h": 2, "fmt": "grid"},
	"cabinet_wood":            {"tileset": "1_Generic_16x16", "col": 0,  "row": 50, "w": 3, "h": 3, "fmt": "grid"},

	# Furniture — packed format (4 tiles in one row = TL TR BL BR → 2×2 display)
	"chair_office_blue":       {"tileset": "1_Generic_16x16", "col": 10, "row": 39, "w": 2, "h": 2, "fmt": "packed"},
	"chair_office_gray":       {"tileset": "1_Generic_16x16", "col": 14, "row": 39, "w": 2, "h": 2, "fmt": "packed"},
	"chair_office_red":        {"tileset": "1_Generic_16x16", "col": 2,  "row": 40, "w": 2, "h": 2, "fmt": "packed"},
	"sofa_beige":              {"tileset": "1_Generic_16x16", "col": 0,  "row": 18, "w": 2, "h": 2, "fmt": "packed"},
	"sofa_blue":               {"tileset": "1_Generic_16x16", "col": 4,  "row": 18, "w": 2, "h": 2, "fmt": "packed"},
	"sofa_orange":             {"tileset": "1_Generic_16x16", "col": 2,  "row": 19, "w": 2, "h": 2, "fmt": "packed"},
	"plant_tree":              {"tileset": "1_Generic_16x16", "col": 10, "row": 28, "w": 2, "h": 2, "fmt": "packed"},
	"plant_tree2":             {"tileset": "1_Generic_16x16", "col": 14, "row": 29, "w": 2, "h": 2, "fmt": "packed"},
	"plant_tree3":             {"tileset": "1_Generic_16x16", "col": 6,  "row": 57, "w": 2, "h": 2, "fmt": "packed"},
	"plant_potted":            {"tileset": "1_Generic_16x16", "col": 12, "row": 29, "w": 2, "h": 2, "fmt": "packed"},
}

# ---------------------------------------------------------------------------
# load_into — main entry point
# parent: Node2D to add floor + entity children into
# layout_path: res:// path to room layout JSON
# origin: world-space pixel offset for the entire room
# tile_scale: scale factor for all sprites (default 1.0)
# ---------------------------------------------------------------------------
static func load_into(
		parent: Node2D,
		layout_path: String,
		origin: Vector2 = Vector2.ZERO,
		tile_scale: float = 1.0) -> void:

	var layout := _read_json(layout_path)
	if layout.is_empty():
		push_error("[RoomLoader] Failed to load: %s" % layout_path)
		return

	var cols: int   = layout.get("cols", 20)
	var rows: int   = layout.get("rows", 15)
	var tileset_id: String = layout.get("tileset", "1_Generic_16x16")
	var tileset_path: String = TILESET_BASE + tileset_id + ".png"

	# ── Floor layer ────────────────────────────────────────────────────────
	var floor_node := Node2D.new()
	floor_node.name = "Floor"
	floor_node.position = origin
	floor_node.z_index = 0
	parent.add_child(floor_node)

	var floor_data: Dictionary = layout.get("floor", {})
	_build_floor(floor_node, tileset_path, floor_data, cols, rows, tile_scale)

	# ── Entity layer ───────────────────────────────────────────────────────
	var entity_node := Node2D.new()
	entity_node.name = "Entities"
	entity_node.position = origin
	parent.add_child(entity_node)

	var entities: Array = layout.get("entities", [])
	_spawn_entities(entity_node, tileset_path, entities, tile_scale)


# ---------------------------------------------------------------------------
# _build_floor — fill room area with floor tiles
# ---------------------------------------------------------------------------
static func _build_floor(
		parent: Node2D,
		tileset_path: String,
		floor_data: Dictionary,
		cols: int, rows: int,
		scale: float) -> void:

	var fill_tile: Array = floor_data.get("fill_tile", [4, 35])
	var border_tiles: Dictionary = floor_data.get("border_tiles", {})

	var ts := float(TILE_PX) * scale

	for r: int in range(rows):
		for c: int in range(cols):
			var key := _border_key(c, r, cols, rows)
			var tile: Array = fill_tile
			if key != "" and border_tiles.has(key):
				tile = border_tiles[key]

			var sp: Sprite2D = _WB.make_tile_sprite(
				tileset_path, int(tile[0]), int(tile[1]), scale)
			if sp:
				sp.position = Vector2(float(c) * ts, float(r) * ts)
				sp.z_index = 0
				parent.add_child(sp)


# ---------------------------------------------------------------------------
# _spawn_entities — instantiate all entity sprites
# ---------------------------------------------------------------------------
static func _spawn_entities(
		parent: Node2D,
		default_tileset_path: String,
		entities: Array,
		scale: float) -> void:

	var ts := float(TILE_PX) * scale

	for ent: Dictionary in entities:
		var sprite_id: String = ent.get("sprite", "")
		if not SPRITE_DEFS.has(sprite_id):
			push_warning("[RoomLoader] Unknown sprite: '%s'" % sprite_id)
			continue

		var def: Dictionary = SPRITE_DEFS[sprite_id]
		var tpath: String = TILESET_BASE + def.get("tileset", "1_Generic_16x16") + ".png"
		var col: int  = int(def["col"])
		var row: int  = int(def["row"])
		var w: int    = int(def["w"])
		var h: int    = int(def["h"])
		var fmt: String = def.get("fmt", "grid")

		var ent_col: int = int(ent.get("col", 0))
		var ent_row: int = int(ent.get("row", 0))
		var z_idx: int   = int(ent.get("z", 1))
		var world_x := float(ent_col) * ts
		var world_y := float(ent_row) * ts

		var node: Node2D
		if fmt == "packed":
			# w*h tiles in one row → reassemble as w×h display
			node = _make_packed(tpath, col, row, w, h, scale)
		else:
			# standard grid sprite
			node = _WB.make_multi_tile_sprite(tpath, col, row, w, h, scale)

		if node:
			node.position = Vector2(world_x, world_y)
			node.z_index  = z_idx
			node.name     = sprite_id + "_%d_%d" % [ent_col, ent_row]
			parent.add_child(node)


# ---------------------------------------------------------------------------
# _make_packed — assemble a packed sprite
# Packed: w*h tiles stored in ONE sheet row, index 0..(w*h-1)
# Display: index % w → display col, index / w → display row
# ---------------------------------------------------------------------------
static func _make_packed(
		tileset_path: String,
		src_col: int, src_row: int,
		disp_w: int, disp_h: int,
		scale: float) -> Node2D:

	var container := Node2D.new()
	var ts := float(TILE_PX) * scale
	var count: int = disp_w * disp_h

	for i: int in range(count):
		var sp: Sprite2D = _WB.make_tile_sprite(
			tileset_path, src_col + i, src_row, scale)
		if sp:
			var dc: int = i % disp_w
			var dr: int = i / disp_w
			sp.position = Vector2(float(dc) * ts, float(dr) * ts)
			container.add_child(sp)

	container.z_index = 0
	return container


# ---------------------------------------------------------------------------
# _border_key — determine which border region a tile belongs to
# ---------------------------------------------------------------------------
static func _border_key(c: int, r: int, cols: int, rows: int) -> String:
	var top    := (r == 0)
	var bottom := (r == rows - 1)
	var left   := (c == 0)
	var right  := (c == cols - 1)
	if top    and left:  return "tl"
	if top    and right: return "tr"
	if bottom and left:  return "bl"
	if bottom and right: return "br"
	if top:              return "tc"
	if bottom:           return "bc"
	if left:             return "ml"
	if right:            return "mr"
	return ""


# ---------------------------------------------------------------------------
# _read_json — load and parse a JSON file
# ---------------------------------------------------------------------------
static func _read_json(path: String) -> Dictionary:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		push_error("[RoomLoader] File not found: %s" % path)
		return {}
	var f := FileAccess.open(abs_path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var result = JSON.parse_string(text)
	if result is Dictionary:
		return result
	push_error("[RoomLoader] JSON parse error: %s" % path)
	return {}
