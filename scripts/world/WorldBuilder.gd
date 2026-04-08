## WorldBuilder.gd
## Static utility class for placing tile-based decorations in Office.gd zones.
## All tilesets are 16×16-pixel tiles.  Tile positions are (col, row) from top-left.
##
## Tileset analysys results (Python PIL scan of non-empty tiles):
##
## 8_Gym_16x16.png  (16×33 tiles)
##   Row 0 : cols 6-10          — machine tops / handles
##   Row 1-5: cols 0-15         — treadmill body, weights, locker sides
##   Row 6-8: cols 0-15         — locker doors, gym mat rows
##   Rows 9-16                  — more equipment
##   Key tiles used:
##     Treadmill top-left  (0,1) to (5,2)   — 6-wide × 2-tall group
##     Weight machine      (6,1) to (8,4)   — 3-wide × 4-tall
##     Locker top-left     (0,4) to (5,5)   — 6-wide × 2-tall group
##
## 12_Kitchen_16x16.png  (16×49 tiles)
##   Rows 0-3  : counter tops, appliances
##   Rows 4-8  : stove, fridge, cabinet faces
##   Rows 9-12 : dining table, chairs
##   Key tiles:
##     Counter top-left   (0,2) → 4-wide counter
##     Fridge top-left    (7,2)
##     Stove top-left     (12,2)
##     Table top-left     (0,9) → 3×3 table
##     Chair (facing down)(6,9)
##
## 13_Conference_Hall_16x16.png  (16×12 tiles)
##   Rows 0-4 : large conference table top
##   Rows 5-8 : chairs, whiteboard, projector
##   Rows 9-10: decorative elements
##   Key tiles:
##     Conf table TL  (1,0)  spans ~8 wide × 4 tall
##     Chair row-top  (1,5)
##     Chair row-bot  (1,7)
##     Whiteboard     (5,5) → (7,5)
##
## 2_LivingRoom_16x16.png  (16×45 tiles)
##   Rows 0-3  : sofa/couch top
##   Rows 4-8  : armchairs, coffee table
##   Rows 9-12 : bookshelf, TV stand, plants
##   Key tiles:
##     Couch TL       (2,0)  3-wide × 3-tall
##     Coffee table   (4,5)  2×2
##     Plant          (5,0)
##     Bookshelf top  (0,9)  2×3
##     TV/screen      (8,2)  single
##
## 1_Generic_16x16.png  (16×78 tiles)
##   Rows 0-2 : desk surfaces (top-view)
##   Rows 3-5 : chairs, cabinets
##   Rows 6-9 : computers, plants, bookshelves
##   Key tiles:
##     Desk top-left  (0,0) → 4-wide × 2-tall
##     Computer/mon   (8,0)  2×2
##     Bookshelf top  (0,5)  2×3
##     Plant          (11,0)
##     Chair          (3,3)
##
## 6_Music_and_sport_16x16.png  (16×48 tiles)
##   Rows 0-3 : ping-pong table top, basketball hoop
##   Rows 4-7 : gym mat, yoga props
##   Key tiles (used for social lounge / extra gym):
##     Ping-pong top-left (6,0) 2×1
##     Yoga mat      (0,1) 6-wide × 3-tall
##
## Room_Builder_Floors_16x16.png  (15×40 tiles)
##   Row 0-1 : wood floor pieces (sparse)
##   Row 2-3 : solid tile/parquet (all cols filled)
##   Row 4-7 : carpet / stone / outdoor
##   Key floor tiles:
##     Wood plank  (0,2) or (1,2)
##     Stone tile  (8,2) or (9,2)
##     Carpet      (4,2) or (5,2)
##     Grass/outdoor (12,2) or (13,2)

class_name WorldBuilder

# ---------------------------------------------------------------------------
#  Asset paths (res:// aliases; also tried as absolute via Image.load_from_file)
# ---------------------------------------------------------------------------
const PATH_GYM        := "res://assets/tilesets/modern_interiors/themes/8_Gym_16x16.png"
const PATH_KITCHEN    := "res://assets/tilesets/modern_interiors/themes/12_Kitchen_16x16.png"
const PATH_CONFERENCE := "res://assets/tilesets/modern_interiors/themes/13_Conference_Hall_16x16.png"
const PATH_LIVING     := "res://assets/tilesets/modern_interiors/themes/2_LivingRoom_16x16.png"
const PATH_GENERIC    := "res://assets/tilesets/modern_interiors/themes/1_Generic_16x16.png"
const PATH_SPORT      := "res://assets/tilesets/modern_interiors/themes/6_Music_and_sport_16x16.png"
const PATH_FLOORS     := "res://assets/tilesets/modern_interiors/subfiles/Room_Builder_Floors_16x16.png"
const PATH_BATHROOM   := "res://assets/tilesets/modern_interiors/themes/3_Bathroom_16x16.png"
const PATH_BEDROOM    := "res://assets/tilesets/modern_interiors/themes/4_Bedroom_16x16.png"
const PATH_HOSPITAL   := "res://assets/tilesets/modern_interiors/themes/19_Hospital_16x16.png"
const PATH_JAPANESE   := "res://assets/tilesets/modern_interiors/themes/20_Japanese_interiors.png"
const PATH_MUSEUM     := "res://assets/tilesets/modern_interiors/themes/22_Museum.png"

# Tile size in pixels
const TILE_PX: int = 16

# ---------------------------------------------------------------------------
#  Key tile constants  — (col, row) in the respective tileset
# ---------------------------------------------------------------------------

# --- Gym ---
const GYM_TREADMILL_TL  := Vector2i(0, 1)   # 6-wide × 2-tall treadmill body
const GYM_TREADMILL_W   := 6
const GYM_TREADMILL_H   := 2

const GYM_WEIGHT_TL     := Vector2i(6, 1)   # 3-wide × 4-tall weight machine
const GYM_WEIGHT_W      := 3
const GYM_WEIGHT_H      := 4

const GYM_LOCKER_TL     := Vector2i(0, 4)   # 6-wide × 2-tall locker bank
const GYM_LOCKER_W      := 6
const GYM_LOCKER_H      := 2

const GYM_MACHINE_TL    := Vector2i(11, 2)  # 4-wide × 3-tall cardio machine
const GYM_MACHINE_W     := 4
const GYM_MACHINE_H     := 3

# --- Kitchen ---
const KITCH_COUNTER_TL  := Vector2i(0, 2)   # 4-wide × 1 counter segment
const KITCH_COUNTER_W   := 4
const KITCH_COUNTER_H   := 1

const KITCH_FRIDGE_TL   := Vector2i(7, 2)   # 2-wide × 2-tall fridge
const KITCH_FRIDGE_W    := 2
const KITCH_FRIDGE_H    := 2

const KITCH_STOVE_TL    := Vector2i(12, 2)  # 2-wide × 2-tall stove
const KITCH_STOVE_W     := 2
const KITCH_STOVE_H     := 2

const KITCH_TABLE_TL    := Vector2i(0, 9)   # 3-wide × 3-tall dining table
const KITCH_TABLE_W     := 3
const KITCH_TABLE_H     := 3

const KITCH_CHAIR_TL    := Vector2i(6, 9)   # single chair tile
const KITCH_CHAIR_W     := 1
const KITCH_CHAIR_H     := 1

# --- Conference ---
const CONF_TABLE_TL     := Vector2i(1, 0)   # 8-wide × 4-tall conference table
const CONF_TABLE_W      := 8
const CONF_TABLE_H      := 4

const CONF_CHAIR_TOP_TL := Vector2i(5, 5)   # chairs on north side of conf table (row 5 is filled)
const CONF_CHAIR_TOP_W  := 7
const CONF_CHAIR_TOP_H  := 1

const CONF_CHAIR_BOT_TL := Vector2i(1, 7)   # chairs on south side
const CONF_CHAIR_BOT_W  := 8
const CONF_CHAIR_BOT_H  := 1

const CONF_WHITEBOARD_TL:= Vector2i(5, 5)   # 3-wide × 1 whiteboard strip
const CONF_WHITEBOARD_W := 3
const CONF_WHITEBOARD_H := 1

# --- Living Room ---
const LIVING_COUCH_TL   := Vector2i(2, 0)   # 3-wide × 3-tall couch
const LIVING_COUCH_W    := 3
const LIVING_COUCH_H    := 3

const LIVING_COFFEE_TL  := Vector2i(4, 5)   # 2×2 coffee table
const LIVING_COFFEE_W   := 2
const LIVING_COFFEE_H   := 2

const LIVING_PLANT_TL   := Vector2i(5, 0)   # single plant tile
const LIVING_PLANT_W    := 1
const LIVING_PLANT_H    := 1

const LIVING_BOOKSHELF_TL := Vector2i(0, 9) # 2-wide × 3-tall bookshelf
const LIVING_BOOKSHELF_W  := 2
const LIVING_BOOKSHELF_H  := 3

const LIVING_TV_TL      := Vector2i(8, 2)   # single large-screen tile
const LIVING_TV_W       := 1
const LIVING_TV_H       := 1

# --- Generic Office ---
const GEN_DESK_TL       := Vector2i(0, 0)   # 4-wide × 2-tall desk surface
const GEN_DESK_W        := 4
const GEN_DESK_H        := 2

const GEN_COMPUTER_TL   := Vector2i(8, 0)   # 2×2 monitor/computer
const GEN_COMPUTER_W    := 2
const GEN_COMPUTER_H    := 2

const GEN_CHAIR_TL      := Vector2i(0, 3)   # office chair (2-wide × 2-tall)
const GEN_CHAIR_W       := 2
const GEN_CHAIR_H       := 2

const GEN_BOOKSHELF_TL  := Vector2i(0, 5)   # 2-wide × 3-tall bookshelf
const GEN_BOOKSHELF_W   := 2
const GEN_BOOKSHELF_H   := 3

const GEN_PLANT_TL      := Vector2i(11, 0)  # single potted plant
const GEN_PLANT_W       := 1
const GEN_PLANT_H       := 1

# --- Sport / Music ---
const SPORT_PINGPONG_TL := Vector2i(6, 0)   # 2×1 ping-pong tabletop
const SPORT_PINGPONG_W  := 2
const SPORT_PINGPONG_H  := 1

const SPORT_MAT_TL      := Vector2i(0, 1)   # 6-wide × 3-tall yoga/gym mat
const SPORT_MAT_W       := 6
const SPORT_MAT_H       := 3

# --- Floors ---
const FLOOR_WOOD_TL     := Vector2i(0, 2)   # wood plank floor tile
const FLOOR_STONE_TL    := Vector2i(8, 2)   # stone/tile floor
const FLOOR_CARPET_TL   := Vector2i(4, 2)   # carpet tile
const FLOOR_GRASS_TL    := Vector2i(12, 2)  # grass/outdoor tile

# ---------------------------------------------------------------------------
#  Texture cache — keyed by res:// path string
# ---------------------------------------------------------------------------
static var _tex_cache: Dictionary = {}

# ---------------------------------------------------------------------------
#  Tile Catalog — name-based tile lookup from JSON catalog files
#  catalog_tile(tileset_stem, tile_name) → Vector2i(col, row)  or  Vector2i(-1,-1)
#
#  Example:
#    var pos := WorldBuilder.catalog_tile("13_Conference_Hall_16x16", "whiteboard_top_left")
#    _place(parent, PATH_CONFERENCE, pos.x, pos.y, 3, 1, x, y)
# ---------------------------------------------------------------------------
const CATALOG_BASE := "res://assets/tilesets/modern_interiors/catalog/"
static var _catalog_cache: Dictionary = {}   # stem → { name: Vector2i }

static func catalog_tile(tileset_stem: String, tile_name: String) -> Vector2i:
	if not _catalog_cache.has(tileset_stem):
		var path := CATALOG_BASE + tileset_stem + "_catalog.json"
		var abs_path := ProjectSettings.globalize_path(path)
		var index: Dictionary = {}
		if FileAccess.file_exists(abs_path):
			var f := FileAccess.open(abs_path, FileAccess.READ)
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if data is Dictionary:
				for tile in data.get("tiles", []):
					index[tile["name"]] = Vector2i(tile["col"], tile["row"])
		_catalog_cache[tileset_stem] = index
	var result: Vector2i = _catalog_cache[tileset_stem].get(tile_name, Vector2i(-1, -1))
	if result == Vector2i(-1, -1):
		push_warning("[WorldBuilder] Tile not found: '%s' in %s" % [tile_name, tileset_stem])
	return result

# place_named — place a single tile by catalog name
static func place_named(parent: Node2D, tileset_path: String,
		tile_name: String,
		world_x: float, world_y: float,
		scale_factor: float = 1.0,
		node_name: String = "") -> void:
	var stem := tileset_path.get_file().get_basename()
	var pos   := catalog_tile(stem, tile_name)
	if pos == Vector2i(-1, -1):
		return
	_place(parent, tileset_path, pos.x, pos.y, 1, 1, world_x, world_y, scale_factor, node_name)

# ---------------------------------------------------------------------------
#  make_tile_sprite
#  Creates a Sprite2D showing a single 16×16 tile from an atlas tileset.
#  scale_factor: multiply the rendered size (1.0 = 16px square as drawn)
# ---------------------------------------------------------------------------
static func make_tile_sprite(tileset_path: String,
		tile_col: int, tile_row: int,
		scale_factor: float = 1.0) -> Sprite2D:
	var texture := _get_texture(tileset_path)
	if texture == null:
		return null

	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(tile_col * TILE_PX, tile_row * TILE_PX, TILE_PX, TILE_PX)
	atlas.filter_clip = true

	var sp := Sprite2D.new()
	sp.texture = atlas
	sp.centered = false
	if scale_factor != 1.0:
		sp.scale = Vector2(scale_factor, scale_factor)
	sp.z_index = 0
	return sp


# make_multi_tile_sprite: returns a Node2D containing a w×h grid of Sprite2Ds
# starting from (tile_col, tile_row) in the atlas.
static func make_multi_tile_sprite(tileset_path: String,
		tile_col: int, tile_row: int,
		tile_w: int, tile_h: int,
		scale_factor: float = 1.0) -> Node2D:
	var container := Node2D.new()
	for dy in range(tile_h):
		for dx in range(tile_w):
			var sp := make_tile_sprite(tileset_path, tile_col + dx, tile_row + dy, scale_factor)
			if sp:
				sp.position = Vector2(dx * TILE_PX, dy * TILE_PX) * scale_factor
				container.add_child(sp)
	container.z_index = 0
	return container


# ---------------------------------------------------------------------------
# make_packed_2x2
# Many Modern Interiors sprites store TL/TR/BL/BR tiles in a single row of
# the sheet (NOT as a 2×2 grid):
#   sheet col:  tl_col+0  tl_col+1  tl_col+2  tl_col+3
#   sheet row:  tl_row    tl_row    tl_row    tl_row
# This function assembles them into the correct 2×2 display layout:
#   display (0,0) ← tl_col+0   display (1,0) ← tl_col+1
#   display (0,1) ← tl_col+2   display (1,1) ← tl_col+3
# ---------------------------------------------------------------------------
static func make_packed_2x2(tileset_path: String,
		tl_col: int, tl_row: int,
		scale_factor: float = 1.0) -> Node2D:
	var container := Node2D.new()
	# i=0→TL, i=1→TR, i=2→BL, i=3→BR (all in the same sheet row)
	# display grid: col = i%2, row = i/2
	for i: int in range(4):
		var sp := make_tile_sprite(tileset_path, tl_col + i, tl_row, scale_factor)
		if sp:
			var disp_x: float = float(i % 2) * TILE_PX
			var disp_y: float = float(i / 2) * TILE_PX
			sp.position = Vector2(disp_x, disp_y) * scale_factor
			container.add_child(sp)
	container.z_index = 0
	return container


# ---------------------------------------------------------------------------
#  _get_texture — loads (and caches) a Texture2D from res:// or absolute path
# ---------------------------------------------------------------------------
static func _get_texture(res_path: String) -> Texture2D:
	if _tex_cache.has(res_path):
		return _tex_cache[res_path]

	var texture: Texture2D = null

	# Try ResourceLoader first (works when imported)
	if ResourceLoader.exists(res_path):
		var loaded = ResourceLoader.load(res_path)
		if loaded is Texture2D:
			texture = loaded as Texture2D

	# Fallback: raw file load via Image (works even without .import)
	if texture == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				texture = ImageTexture.create_from_image(img)

	if texture == null:
		push_warning("[WorldBuilder] Could not load texture: %s" % res_path)

	_tex_cache[res_path] = texture   # cache even if null to avoid repeated misses
	return texture


# ---------------------------------------------------------------------------
#  _place  — convenience: add a multi-tile sprite at a world position
# ---------------------------------------------------------------------------
static func _place(parent: Node2D, path: String,
		col: int, row: int, w: int, h: int,
		world_x: float, world_y: float,
		scale_factor: float = 1.0,
		node_name: String = "") -> void:
	var node := make_multi_tile_sprite(path, col, row, w, h, scale_factor)
	if node == null:
		return
	node.position = Vector2(world_x, world_y)
	if node_name != "":
		node.name = node_name
	parent.add_child(node)


# ---------------------------------------------------------------------------
#  decorate_gym_zone
#  Gym: cols 0-60, rows 20-200  (tile coords). Pixel origin passed in.
#  Places treadmills, weight machines, lockers, yoga mats.
# ---------------------------------------------------------------------------
static func decorate_gym_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)
	var zw := float(zone_rect.size.x * tile_size)   # zone pixel width
	var _zh := float(zone_rect.size.y * tile_size)  # zone pixel height

	# --- Treadmill row along top of gym (4 treadmills side-by-side) ---
	var tread_y := oy + 2.0 * tile_size
	var tread_spacing := (zw - 4.0 * tile_size) / 4.0
	for i in range(4):
		var tx := ox + float(i) * tread_spacing + 2.0 * tile_size
		_place(parent, PATH_GYM,
			GYM_TREADMILL_TL.x, GYM_TREADMILL_TL.y,
			GYM_TREADMILL_W, GYM_TREADMILL_H,
			tx, tread_y, 1.0,
			"GymTread_%d" % i)

	# --- Weight machines: 3 units in the middle band ---
	var wm_y := oy + 20.0 * tile_size
	for i in range(3):
		var wx := ox + float(i) * 18.0 * tile_size + 2.0 * tile_size
		_place(parent, PATH_GYM,
			GYM_WEIGHT_TL.x, GYM_WEIGHT_TL.y,
			GYM_WEIGHT_W, GYM_WEIGHT_H,
			wx, wm_y, 1.5,
			"GymWeight_%d" % i)

	# --- Cardio machines row (different tiles, row further down) ---
	var cardio_y := oy + 38.0 * tile_size
	for i in range(3):
		var cx := ox + float(i) * 18.0 * tile_size + 4.0 * tile_size
		_place(parent, PATH_GYM,
			GYM_MACHINE_TL.x, GYM_MACHINE_TL.y,
			GYM_MACHINE_W, GYM_MACHINE_H,
			cx, cardio_y, 1.5,
			"GymCardio_%d" % i)

	# --- Yoga/sport mats (bottom of exercise area) ---
	var mat_y := oy + 58.0 * tile_size
	for i in range(4):
		var mx := ox + float(i) * 13.0 * tile_size + 2.0 * tile_size
		_place(parent, PATH_SPORT,
			SPORT_MAT_TL.x, SPORT_MAT_TL.y,
			SPORT_MAT_W, SPORT_MAT_H,
			mx, mat_y, 1.0,
			"GymMat_%d" % i)

	# --- Locker banks along bottom section ---
	var locker_start_y := oy + 100.0 * tile_size
	for row in range(5):
		for col in range(3):
			var lx := ox + float(col) * 18.0 * tile_size + 2.0 * tile_size
			var ly := locker_start_y + float(row) * 14.0 * tile_size
			_place(parent, PATH_GYM,
				GYM_LOCKER_TL.x, GYM_LOCKER_TL.y,
				GYM_LOCKER_W, GYM_LOCKER_H,
				lx, ly, 1.5,
				"GymLocker_%d_%d" % [row, col])


# ---------------------------------------------------------------------------
#  decorate_kitchen_zone  (Cafeteria)
#  Cafeteria: cols 420-480, rows 20-200
# ---------------------------------------------------------------------------
static func decorate_kitchen_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)
	var zw := float(zone_rect.size.x * tile_size)

	# --- Kitchen counter along top wall (multiple counter segments) ---
	var counter_y := oy + 2.0 * tile_size
	var seg_count := int(zw / (KITCH_COUNTER_W * tile_size)) - 1
	seg_count = max(seg_count, 1)
	for i in range(seg_count):
		var kx := ox + float(i) * float(KITCH_COUNTER_W * tile_size)
		_place(parent, PATH_KITCHEN,
			KITCH_COUNTER_TL.x, KITCH_COUNTER_TL.y,
			KITCH_COUNTER_W, KITCH_COUNTER_H,
			kx, counter_y, 1.0,
			"KitchCounter_%d" % i)

	# --- Fridge (right side of counter) ---
	_place(parent, PATH_KITCHEN,
		KITCH_FRIDGE_TL.x, KITCH_FRIDGE_TL.y,
		KITCH_FRIDGE_W, KITCH_FRIDGE_H,
		ox + zw - 5.0 * tile_size, oy + 2.0 * tile_size, 1.5,
		"KitchFridge")

	# --- Stove (left end of counter) ---
	_place(parent, PATH_KITCHEN,
		KITCH_STOVE_TL.x, KITCH_STOVE_TL.y,
		KITCH_STOVE_W, KITCH_STOVE_H,
		ox + 2.0 * tile_size, oy + 2.0 * tile_size, 1.5,
		"KitchStove")

	# --- Dining tables grid ---
	var row_count := 7
	var col_count := 2
	for row in range(row_count):
		for col in range(col_count):
			var tx := ox + float(col) * 28.0 * tile_size + 3.0 * tile_size
			var ty := oy + float(row) * 22.0 * tile_size + 14.0 * tile_size
			_place(parent, PATH_KITCHEN,
				KITCH_TABLE_TL.x, KITCH_TABLE_TL.y,
				KITCH_TABLE_W, KITCH_TABLE_H,
				tx, ty, 1.5,
				"DiningTable_%d_%d" % [row, col])
			# Chairs above and below table
			_place(parent, PATH_KITCHEN,
				KITCH_CHAIR_TL.x, KITCH_CHAIR_TL.y,
				KITCH_CHAIR_W, KITCH_CHAIR_H,
				tx + tile_size, ty - tile_size, 1.5,
				"DC_%d_%d_T" % [row, col])
			_place(parent, PATH_KITCHEN,
				KITCH_CHAIR_TL.x, KITCH_CHAIR_TL.y,
				KITCH_CHAIR_W, KITCH_CHAIR_H,
				tx + tile_size, ty + float(KITCH_TABLE_H + 1) * tile_size, 1.5,
				"DC_%d_%d_B" % [row, col])


# ---------------------------------------------------------------------------
#  decorate_office_zone  (Generic office — used for engineering/design/etc.)
# ---------------------------------------------------------------------------
static func decorate_office_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int, zone_id: String) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)
	var zw := float(zone_rect.size.x * tile_size)
	var _zh := float(zone_rect.size.y * tile_size)

	# Plant in top-right corner
	_place(parent, PATH_GENERIC,
		GEN_PLANT_TL.x, GEN_PLANT_TL.y,
		GEN_PLANT_W, GEN_PLANT_H,
		ox + zw - 3.0 * tile_size, oy + 1.5 * tile_size, 1.0,
		zone_id + "_CornerPlant")

	# Bookshelf along left wall
	_place(parent, PATH_GENERIC,
		GEN_BOOKSHELF_TL.x, GEN_BOOKSHELF_TL.y,
		GEN_BOOKSHELF_W, GEN_BOOKSHELF_H,
		ox + 1.0 * tile_size, oy + 5.0 * tile_size, 1.0,
		zone_id + "_Bookshelf")


# ---------------------------------------------------------------------------
#  decorate_conference_zone  (Meeting rooms)
# ---------------------------------------------------------------------------
static func decorate_conference_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int, room_name: String) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)
	var zw := float(zone_rect.size.x * tile_size)

	# Conference table centered in room
	var table_ox := ox + (zw - float(CONF_TABLE_W * tile_size)) * 0.5
	var table_oy := oy + 5.0 * tile_size
	_place(parent, PATH_CONFERENCE,
		CONF_TABLE_TL.x, CONF_TABLE_TL.y,
		CONF_TABLE_W, CONF_TABLE_H,
		table_ox, table_oy, 1.0,
		room_name + "_ConfTable")

	# Chair row on north side of table
	_place(parent, PATH_CONFERENCE,
		CONF_CHAIR_TOP_TL.x, CONF_CHAIR_TOP_TL.y,
		CONF_CHAIR_TOP_W, CONF_CHAIR_TOP_H,
		table_ox, table_oy - float(tile_size), 1.0,
		room_name + "_ChairsN")

	# Chair row on south side of table
	_place(parent, PATH_CONFERENCE,
		CONF_CHAIR_BOT_TL.x, CONF_CHAIR_BOT_TL.y,
		CONF_CHAIR_BOT_W, CONF_CHAIR_BOT_H,
		table_ox, table_oy + float(CONF_TABLE_H * tile_size), 1.0,
		room_name + "_ChairsS")

	# Whiteboard on north wall
	var wb_ox := ox + (zw - float(CONF_WHITEBOARD_W * tile_size)) * 0.5
	_place(parent, PATH_CONFERENCE,
		CONF_WHITEBOARD_TL.x, CONF_WHITEBOARD_TL.y,
		CONF_WHITEBOARD_W, CONF_WHITEBOARD_H,
		wb_ox, oy + 2.0 * tile_size, 1.0,
		room_name + "_Whiteboard")


# ---------------------------------------------------------------------------
#  decorate_lounge_zone  (Social Lounge)
# ---------------------------------------------------------------------------
static func decorate_lounge_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Couches along the left section
	for i in range(3):
		_place(parent, PATH_LIVING,
			LIVING_COUCH_TL.x, LIVING_COUCH_TL.y,
			LIVING_COUCH_W, LIVING_COUCH_H,
			ox + float(i) * 22.0 * tile_size + 4.0 * tile_size,
			oy + 65.0 * tile_size, 1.5,
			"SocialCouch_%d" % i)

	# Coffee table in front of couches
	_place(parent, PATH_LIVING,
		LIVING_COFFEE_TL.x, LIVING_COFFEE_TL.y,
		LIVING_COFFEE_W, LIVING_COFFEE_H,
		ox + 20.0 * tile_size, oy + 75.0 * tile_size, 2.0,
		"SocialCoffeeTable")

	# Bookshelf on the right wall of social zone
	_place(parent, PATH_LIVING,
		LIVING_BOOKSHELF_TL.x, LIVING_BOOKSHELF_TL.y,
		LIVING_BOOKSHELF_W, LIVING_BOOKSHELF_H,
		ox + 140.0 * tile_size, oy + 4.0 * tile_size, 2.0,
		"SocialBookshelf")

	# Plants scattered around
	var plant_positions: Array = [
		Vector2(2, 2), Vector2(145, 2), Vector2(2, 88), Vector2(145, 88),
		Vector2(70, 30),
	]
	var pi := 0
	for pp in plant_positions:
		_place(parent, PATH_LIVING,
			LIVING_PLANT_TL.x, LIVING_PLANT_TL.y,
			LIVING_PLANT_W, LIVING_PLANT_H,
			ox + pp.x * tile_size, oy + pp.y * tile_size, 1.5,
			"SocialPlant_%d" % pi)
		pi += 1

	# Ping-pong table (sport tileset) in top area of social zone
	_place(parent, PATH_SPORT,
		SPORT_PINGPONG_TL.x, SPORT_PINGPONG_TL.y,
		SPORT_PINGPONG_W * 4, SPORT_PINGPONG_H * 3,
		ox + 4.0 * tile_size, oy + 4.0 * tile_size, 3.0,
		"SocialPingPong")


# ---------------------------------------------------------------------------
#  decorate_garden_zone
# ---------------------------------------------------------------------------
static func decorate_garden_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Scatter plants throughout the garden using the Living Room plant tile
	var plant_spots: Array = [
		Vector2(5,  5),  Vector2(20, 8),  Vector2(40, 3),  Vector2(60, 10), Vector2(80, 6),
		Vector2(100,4),  Vector2(125,8),  Vector2(145,5),
		Vector2(10, 55), Vector2(35, 60), Vector2(70, 58), Vector2(110, 62), Vector2(140, 55),
		Vector2(5,  80), Vector2(50, 82), Vector2(90, 78), Vector2(140, 85),
	]
	var gi := 0
	for sp in plant_spots:
		_place(parent, PATH_LIVING,
			LIVING_PLANT_TL.x, LIVING_PLANT_TL.y,
			LIVING_PLANT_W, LIVING_PLANT_H,
			ox + sp.x * tile_size, oy + sp.y * tile_size, 2.0,
			"GardenPlant_%d" % gi)
		gi += 1

	# Some benches (repurpose living room couch tiles as outdoor seating)
	var bench_spots: Array = [
		Vector2(5, 42), Vector2(40, 42), Vector2(80, 42), Vector2(120, 42),
		Vector2(5, 55), Vector2(40, 55), Vector2(80, 55), Vector2(120, 55),
	]
	var bi := 0
	for bp in bench_spots:
		_place(parent, PATH_LIVING,
			LIVING_COUCH_TL.x, LIVING_COUCH_TL.y,
			LIVING_COUCH_W, 1,
			ox + bp.x * tile_size, oy + bp.y * tile_size, 1.0,
			"GardenBench_%d" % bi)
		bi += 1


# ---------------------------------------------------------------------------
#  decorate_terrace_zone
# ---------------------------------------------------------------------------
static func decorate_terrace_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Lounge chairs (living room couch) — 4 clusters
	for i in range(4):
		var cx := ox + float(i) * 36.0 * tile_size + 4.0 * tile_size
		_place(parent, PATH_LIVING,
			LIVING_COUCH_TL.x, LIVING_COUCH_TL.y,
			LIVING_COUCH_W, LIVING_COUCH_H,
			cx, oy + 14.0 * tile_size, 1.5,
			"TerraceLoungeA_%d" % i)
		_place(parent, PATH_LIVING,
			LIVING_COUCH_TL.x, LIVING_COUCH_TL.y,
			LIVING_COUCH_W, LIVING_COUCH_H,
			cx + 22.0 * tile_size, oy + 14.0 * tile_size, 1.5,
			"TerraceLoungeB_%d" % i)
		# Coffee table between chairs
		_place(parent, PATH_LIVING,
			LIVING_COFFEE_TL.x, LIVING_COFFEE_TL.y,
			LIVING_COFFEE_W, LIVING_COFFEE_H,
			cx + 11.0 * tile_size, oy + 16.0 * tile_size, 1.5,
			"TerraceCoffee_%d" % i)

	# Terrace planters along bottom wall
	for pi in range(5):
		_place(parent, PATH_LIVING,
			LIVING_PLANT_TL.x, LIVING_PLANT_TL.y,
			LIVING_PLANT_W, LIVING_PLANT_H,
			ox + float(pi) * 28.0 * tile_size + 4.0 * tile_size,
			oy + 68.0 * tile_size, 2.5,
			"TerracePlant_%d" % pi)


# ---------------------------------------------------------------------------
#  decorate_bathroom_zone
#  Bathroom/Wellness area: toilets, sinks, bathtubs, washing machines
# ---------------------------------------------------------------------------
static func decorate_bathroom_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Toilets row — col 3-10 row 0 in bathroom tileset (4 toilets)
	for i in range(4):
		_place(parent, PATH_BATHROOM, 3 + i, 0, 1, 2,
			ox + float(i) * 4.0 * tile_size, oy + 2.0 * tile_size, 1.0,
			"Toilet_%d" % i)

	# Bathtub — cols 3-5, rows 2-4
	_place(parent, PATH_BATHROOM, 3, 2, 3, 3,
		ox + 2.0 * tile_size, oy + 8.0 * tile_size, 1.0, "Bathtub")

	# Washing machine — col 13, rows 0-1
	_place(parent, PATH_BATHROOM, 13, 0, 2, 2,
		ox + 14.0 * tile_size, oy + 2.0 * tile_size, 1.0, "WashingMachine")

	# Sink — col 0-1, rows 0-1
	_place(parent, PATH_BATHROOM, 0, 0, 2, 2,
		ox + 0.0 * tile_size, oy + 2.0 * tile_size, 1.0, "Sink")

	# Plants in corners
	_place(parent, PATH_LIVING, LIVING_PLANT_TL.x, LIVING_PLANT_TL.y, 1, 1,
		ox + float(zone_rect.size.x - 2) * tile_size, oy + 2.0 * tile_size, 1.0, "BathPlant")


# ---------------------------------------------------------------------------
#  decorate_bedroom_zone
#  Rest/nap room: beds, wardrobes, side tables, stuffed animals
# ---------------------------------------------------------------------------
static func decorate_bedroom_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Beds — col 9-10, rows 0-2 (single bed)
	var bed_count := mini(zone_rect.size.x / 8, 4)
	for i in range(bed_count):
		_place(parent, PATH_BEDROOM, 9, 0, 2, 3,
			ox + float(i) * 8.0 * tile_size + 2.0 * tile_size,
			oy + 3.0 * tile_size, 1.0,
			"Bed_%d" % i)

	# Wardrobe — cols 12-15, rows 0-2
	_place(parent, PATH_BEDROOM, 12, 0, 4, 3,
		ox + float(zone_rect.size.x - 6) * tile_size,
		oy + 2.0 * tile_size, 1.0, "Wardrobe")

	# Teddy bears as decoration — cols 0-2, row 0
	for i in range(3):
		_place(parent, PATH_BEDROOM, i, 0, 1, 1,
			ox + float(i) * 3.0 * tile_size,
			oy + float(zone_rect.size.y - 3) * tile_size, 1.0,
			"TeddyBear_%d" % i)


# ---------------------------------------------------------------------------
#  decorate_hospital_zone
#  Wellness / first-aid room: reception desk, hospital beds, screens
# ---------------------------------------------------------------------------
static func decorate_hospital_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Reception / nurse station — rows 0-3, cols 0-7 (desk shape)
	_place(parent, PATH_HOSPITAL, 0, 0, 8, 4,
		ox + 2.0 * tile_size, oy + 2.0 * tile_size, 1.0, "NurseStation")

	# Medical screen (chart/monitor) — col 0-1, rows 4-5
	_place(parent, PATH_HOSPITAL, 0, 4, 2, 2,
		ox + 0.0 * tile_size, oy + 10.0 * tile_size, 1.0, "MedScreen")

	# Second desk cluster
	_place(parent, PATH_HOSPITAL, 4, 0, 4, 4,
		ox + float(zone_rect.size.x / 2) * tile_size,
		oy + 2.0 * tile_size, 1.0, "HospDesk2")

	# Plants
	_place(parent, PATH_LIVING, LIVING_PLANT_TL.x, LIVING_PLANT_TL.y, 1, 1,
		ox + float(zone_rect.size.x - 2) * tile_size,
		oy + 2.0 * tile_size, 1.0, "HospPlant")


# ---------------------------------------------------------------------------
#  decorate_japanese_zone
#  Zen/relaxation lounge: tatami mats, shoji screens, low tables, cushions
# ---------------------------------------------------------------------------
static func decorate_japanese_zone(parent: Node2D, zone_rect: Rect2i, tile_size: int) -> void:
	var ox := float(zone_rect.position.x * tile_size)
	var oy := float(zone_rect.position.y * tile_size)

	# Tatami mat floor panels — cols 1-8 rows 0-1 (shoji/screen)
	_place(parent, PATH_JAPANESE, 1, 0, 4, 2,
		ox + 2.0 * tile_size, oy + 2.0 * tile_size, 1.0, "ShojiLeft")
	_place(parent, PATH_JAPANESE, 1, 0, 4, 2,
		ox + float(zone_rect.size.x / 2) * tile_size,
		oy + 2.0 * tile_size, 1.0, "ShojiRight")

	# Decorative lanterns/scrolls — cols 11-12, rows 0-1
	for i in range(3):
		_place(parent, PATH_JAPANESE, 11, 0, 2, 2,
			ox + float(i) * 6.0 * tile_size + 1.0 * tile_size,
			oy + 8.0 * tile_size, 1.0,
			"Lantern_%d" % i)

	# Low floor cushions — row 3 area
	for i in range(4):
		_place(parent, PATH_JAPANESE, 5, 3, 2, 2,
			ox + float(i) * 5.0 * tile_size + 2.0 * tile_size,
			oy + 14.0 * tile_size, 1.0,
			"Cushion_%d" % i)
