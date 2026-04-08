## Office.gd
## ZPS Game Studio — Villa Campus World Scene
## Inspired by Riot, Naughty Dog, Epic, CD Projekt Red.
## 480×384 tile mega-campus — 5 horizontal bands:
##
##   Y=0–14:    Grand Entrance Gate (fountain, palms, gate arches)
##   Y=14–96:   North Main Building
##                Creative Lab (0-120) | Atrium+Garden (120-260) | Engineering (260-360) | Wellness (360-480)
##   Y=96–210:  Amenities Row
##                Pool+Fitness (0-160) | Open Pods (160-260) | Meeting Suites (260-320) | Game Lab (320-480)
##   Y=210–310: Lifestyle Campus
##                Botanical Park (0-200) | Dining Pavilion (200-340) | Rooftop Terrace (340-480)
##   Y=310–340: Recreation Strip (arcade, billiards, bean bags)
##   Y=340–384: Campus Parking

extends Node2D

const _AR = preload("res://scripts/world/AvatarRenderer.gd")
const _WB = preload("res://scripts/world/WorldBuilder.gd")
const _RL = preload("res://scripts/world/RoomLoader.gd")

@onready var employee_container: Node2D = $Employees

const TILE_SIZE: int = 16
const OFFICE_W:  int = 480
const OFFICE_H:  int = 384

# ─────────────────────────────────────────────────────────────
#  Zone rectangles (tile coordinates)
# ─────────────────────────────────────────────────────────────
const ZONE_RECTS: Dictionary = {
	# ── Grand Entrance ──
	"entrance":         Rect2i(0,    0,   480,  14),

	# ── North Main Building (rows 14–96) ──
	"creative_lab":     Rect2i(0,    14,  120,  82),
	"atrium":           Rect2i(120,  14,  140,  40),
	"inner_garden":     Rect2i(120,  54,  140,  42),
	"engineering_hub":  Rect2i(260,  14,  100,  82),
	"wellness_lounge":  Rect2i(360,  14,  120,  82),

	# ── Amenities Row (rows 96–210) ──
	"pool_complex":     Rect2i(0,    96,  160, 114),
	"work_pods":        Rect2i(160,  96,  100, 114),
	"meeting_suites":   Rect2i(260,  96,   60, 114),
	"game_lab":         Rect2i(320,  96,  160, 114),

	# ── Lifestyle Campus (rows 210–310) ──
	"botanical_park":   Rect2i(0,   210,  200, 100),
	"dining_pavilion":  Rect2i(200, 210,  140, 100),
	"rooftop_terrace":  Rect2i(340, 210,  140, 100),

	# ── Recreation & Parking ──
	"recreation_strip": Rect2i(0,   310,  480,  30),
	"parking":          Rect2i(0,   340,  480,  44),
}

# ─────────────────────────────────────────────────────────────
#  Zone floor colors
# ─────────────────────────────────────────────────────────────
const ZONE_COLORS: Dictionary = {
	"entrance":         Color(0.09, 0.09, 0.15),
	"creative_lab":     Color(0.08, 0.06, 0.14),
	"atrium":           Color(0.11, 0.11, 0.19),
	"inner_garden":     Color(0.07, 0.19, 0.07),
	"engineering_hub":  Color(0.07, 0.09, 0.14),
	"wellness_lounge":  Color(0.10, 0.06, 0.16),
	"pool_complex":     Color(0.62, 0.58, 0.48),
	"work_pods":        Color(0.07, 0.10, 0.17),
	"meeting_suites":   Color(0.07, 0.07, 0.15),
	"game_lab":         Color(0.07, 0.05, 0.14),
	"botanical_park":   Color(0.07, 0.22, 0.06),
	"dining_pavilion":  Color(0.14, 0.10, 0.07),
	"rooftop_terrace":  Color(0.18, 0.13, 0.09),
	"recreation_strip": Color(0.09, 0.07, 0.14),
	"parking":          Color(0.06, 0.06, 0.09),
}

# ─────────────────────────────────────────────────────────────
#  Open Work Pods (work_pods zone: 100×114 tiles @ 160,96)
#  5 pods × 15 desks × 2 half-rows = 150 seats
# ─────────────────────────────────────────────────────────────
const WP_DESK_X0:    int = 162
const WP_CELL_W:     int = 6
const WP_DESKS_HALF: int = 15
const WP_BOT_OFFSET: int = 9
const WP_POD_TOPS: Array = [100, 122, 144, 166, 188]

# ─────────────────────────────────────────────────────────────
#  Engineering Hub (engineering_hub zone: 100×82 tiles @ 260,14)
#  6 rows × 15 desks = 90 seats
# ─────────────────────────────────────────────────────────────
const EH_DESK_X0: int = 262
const EH_CELL_W:  int = 6
const EH_COLS:    int = 15
const EH_CELL_H:  int = 12
const EH_ROW0:    int = 18

# ─────────────────────────────────────────────────────────────
#  Creative Lab (creative_lab zone: 120×82 tiles @ 0,14)
#  3 clusters × 5 wide × 4 deep = 60 seats
# ─────────────────────────────────────────────────────────────
const CL_CLUSTER_X0: Array = [4, 42, 80]
const CL_CLUSTER_Y0: int   = 22
const CL_CELL_W:     int   = 7
const CL_CELL_H:     int   = 16
const CL_COLS:       int   = 5
const CL_ROWS:       int   = 4

const TEAM_COLORS: Array = [
	Color(0.30, 0.55, 0.90),
	Color(0.75, 0.35, 0.85),
	Color(0.30, 0.70, 0.45),
	Color(0.85, 0.50, 0.30),
	Color(0.85, 0.72, 0.20),
]

# ─────────────────────────────────────────────────────────────
#  Tileset paths & sprite atlas coords
#  Grid format  → use _WB.make_multi_tile_sprite(path, col, row, w, h)
#  Packed 2×2   → use _WB.make_packed_2x2(path, tl_col, tl_row)
#    (packed = TL/TR/BL/BR stored in one horizontal row of the sheet)
# ─────────────────────────────────────────────────────────────
const _GENERIC  := "res://assets/tilesets/modern_interiors/themes/1_Generic_16x16.png"
const _CONF     := "res://assets/tilesets/modern_interiors/themes/13_Conference_Hall_16x16.png"
const _GYM      := "res://assets/tilesets/modern_interiors/themes/8_Gym_16x16.png"
const _KITCHEN  := "res://assets/tilesets/modern_interiors/themes/12_Kitchen_16x16.png"
const _LIVING   := "res://assets/tilesets/modern_interiors/themes/2_LivingRoom_16x16.png"

# Grid sprites: [col, row, w, h]
const SP_DESK_WOOD      := [0,  52, 3, 2]  # L-shaped desk + monitor
const SP_WHITEBOARD     := [10,  1, 4, 3]  # conference whiteboard  (13_Conference)

# Packed-2x2 sprites: [tl_col, tl_row] in 1_Generic
const SP_CHAIR_BLUE     := [10, 39]   # office chair blue
const SP_SOFA_BEIGE     := [0,  18]   # sofa beige
const SP_SOFA_ORANGE    := [2,  19]   # sofa orange
const SP_TREE           := [6,  57]   # leafy tree / large plant

const PLAYER_SPAWN_TILE: Vector2 = Vector2(240, 6)

var player_node: CharacterBody2D = null
var _node_counter: int = 0
var _tilemap_active: bool = false

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	employee_container.y_sort_enabled = true
	_build_office()
	_spawn_player()
	_spawn_employees()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_player"):
		hud.register_player(player_node)
	print("[Office] ZPS Villa Campus — 480×384 tiles · 300 employees")

func _tile_to_world(tile: Vector2) -> Vector2:
	return tile * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE * 2.5)

func get_room_at_position(world_pos: Vector2) -> String:
	var tp := Vector2i(world_pos / TILE_SIZE)
	for zone_id in ZONE_RECTS:
		if ZONE_RECTS[zone_id].has_point(tp):
			return zone_id
	return ""

func _uid(base: String) -> String:
	_node_counter += 1
	return "%s_%04d" % [base, _node_counter]

# ─────────────────────────────────────────────────────────────
#  TileMap (optional — falls back to ColorRect if texture missing)
# ─────────────────────────────────────────────────────────────
func _setup_tilemap() -> void:
	var tex_path := "res://assets/tilesets/modern_interiors/Room_Builder_free_16x16.png"
	var texture: Texture2D = null
	if ResourceLoader.exists(tex_path):
		texture = load(tex_path) as Texture2D
	if texture == null:
		var abs_path := ProjectSettings.globalize_path(tex_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				texture = ImageTexture.create_from_image(img)
	if texture == null:
		push_warning("[Office] TileMap texture not found, using ColorRect floor.")
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	var source_id: int = tile_set.add_source(source, 0)
	var needed_coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	]
	for coord in needed_coords:
		if not source.has_tile(coord):
			source.create_tile(coord)
	var tilemap := TileMap.new()
	tilemap.name = "FloorTileMap"
	tilemap.tile_set = tile_set
	tilemap.z_index = -10
	add_child(tilemap)
	_paint_floor_tiles(tilemap, source_id)
	_tilemap_active = true

func _paint_floor_tiles(tilemap: TileMap, source_id: int) -> void:
	for x in range(OFFICE_W):
		for y in range(OFFICE_H):
			tilemap.set_cell(0, Vector2i(x, y), source_id, Vector2i(0, 0))
	var zone_tile_map: Dictionary = {
		"creative_lab":    Vector2i(1, 0),
		"atrium":          Vector2i(2, 0),
		"engineering_hub": Vector2i(3, 0),
		"work_pods":       Vector2i(1, 0),
		"meeting_suites":  Vector2i(1, 1),
		"dining_pavilion": Vector2i(0, 1),
		"botanical_park":  Vector2i(3, 1),
	}
	for zone_name in zone_tile_map:
		var rect: Rect2i = ZONE_RECTS.get(zone_name, Rect2i())
		if rect.size == Vector2i.ZERO:
			continue
		var atlas_coord: Vector2i = zone_tile_map[zone_name]
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				tilemap.set_cell(0, Vector2i(x, y), source_id, atlas_coord)

# ─────────────────────────────────────────────────────────────
#  Core draw primitives
# ─────────────────────────────────────────────────────────────
func _draw_rect(parent: Node2D, rect: Rect2, color: Color, node_name: String) -> ColorRect:
	var cr := ColorRect.new()
	cr.name = node_name
	cr.position = rect.position
	cr.size = rect.size
	cr.color = color
	parent.add_child(cr)
	return cr

func _draw_border(parent: Node2D, rect: Rect2, color: Color, node_name: String, thickness: float = 1.5) -> void:
	var t := thickness
	_draw_rect(parent, Rect2(rect.position, Vector2(rect.size.x, t)), color, node_name + "_t")
	_draw_rect(parent, Rect2(rect.position + Vector2(0.0, rect.size.y - t), Vector2(rect.size.x, t)), color, node_name + "_b")
	_draw_rect(parent, Rect2(rect.position, Vector2(t, rect.size.y)), color, node_name + "_l")
	_draw_rect(parent, Rect2(rect.position + Vector2(rect.size.x - t, 0.0), Vector2(t, rect.size.y)), color, node_name + "_r")

# ─── Sprite placement helpers ───────────────────────────────────────────────
# Place a grid-format multi-tile sprite (w×h from atlas col/row)
func _sp(canvas: Node2D, path: String,
		col: int, row: int, w: int, h: int,
		wx: float, wy: float, z: int = 1,
		scale: float = 1.0) -> void:
	var node: Node2D = _WB.make_multi_tile_sprite(path, col, row, w, h, scale)
	if node:
		node.position = Vector2(wx, wy)
		node.z_index  = z
		canvas.add_child(node)

# Place a packed-2×2 sprite (4 tiles in one sheet row → displayed as 2×2)
func _sp2(canvas: Node2D, path: String,
		tl_col: int, tl_row: int,
		wx: float, wy: float, z: int = 1,
		scale: float = 1.0) -> void:
	var node: Node2D = _WB.make_packed_2x2(path, tl_col, tl_row, scale)
	if node:
		node.position = Vector2(wx, wy)
		node.z_index  = z
		canvas.add_child(node)

func _label(canvas: Node2D, pos: Vector2, text: String, color: Color, size: int = 12) -> void:
	var lbl := Label.new()
	lbl.name = _uid("Lbl")
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", size)
	lbl.modulate = color
	canvas.add_child(lbl)

func _draw_plant(parent: Node2D, pos: Vector2, _pname: String) -> void:
	# plant_tree3 (leafy) — 2×2 packed sprite at (6,57) in 1_Generic
	_sp2(parent, _GENERIC, SP_TREE[0], SP_TREE[1], pos.x, pos.y, 1)

func _draw_tree(parent: Node2D, pos: Vector2) -> void:
	# plant_tree3 scaled up 2× for botanical park / garden visibility
	_sp2(parent, _GENERIC, SP_TREE[0], SP_TREE[1], pos.x, pos.y, 1, 2.0)

func _draw_palm(parent: Node2D, pos: Vector2) -> void:
	var ts := float(TILE_SIZE)
	_draw_rect(parent, Rect2(pos + Vector2(6.0, ts), Vector2(4.0, 7.0 * ts)), Color(0.52, 0.38, 0.18), _uid("PalmT"))
	for i in range(5):
		var a := float(i) * 72.0 * PI / 180.0
		var fx := pos.x + 8.0 + cos(a) * 3.0 * ts
		var fy := pos.y + 2.0 + sin(a) * ts
		_draw_rect(parent, Rect2(Vector2(fx, fy), Vector2(3.0 * ts, 8.0)), Color(0.15, 0.55, 0.12), _uid("PalmF"))

func _draw_sofa(canvas: Node2D, pos: Vector2, w_tiles: float, _color: Color) -> void:
	# sofa_beige — 2×2 packed sprite at (0,18) in 1_Generic.
	# For wider sofas (w_tiles > 2), tile the sprite horizontally.
	var ts := float(TILE_SIZE)
	var copies: int = int(w_tiles * 0.5)
	if copies < 1:
		copies = 1
	for i in range(copies):
		_sp2(canvas, _GENERIC, SP_SOFA_BEIGE[0], SP_SOFA_BEIGE[1],
			pos.x + i * 2.0 * ts, pos.y, 1)

func _draw_dining_table(canvas: Node2D, center: Vector2, r_tiles: float) -> void:
	var ts := float(TILE_SIZE)
	var r := r_tiles * ts
	_draw_rect(canvas, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)),
		Color(0.40, 0.30, 0.18), _uid("DTable"))
	_draw_border(canvas, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)),
		Color(0.58, 0.44, 0.26), _uid("DTableB"), 2.0)
	var cs := Vector2(ts * 1.2, ts * 1.2)
	_draw_rect(canvas, Rect2(Vector2(center.x - cs.x * 0.5, center.y - r - cs.y), cs), Color(0.20, 0.20, 0.30), _uid("DCN"))
	_draw_rect(canvas, Rect2(Vector2(center.x - cs.x * 0.5, center.y + r), cs), Color(0.20, 0.20, 0.30), _uid("DCS"))
	_draw_rect(canvas, Rect2(Vector2(center.x - r - cs.x, center.y - cs.y * 0.5), cs), Color(0.20, 0.20, 0.30), _uid("DCW"))
	_draw_rect(canvas, Rect2(Vector2(center.x + r, center.y - cs.y * 0.5), cs), Color(0.20, 0.20, 0.30), _uid("DCE"))

func _draw_desk_v2(canvas: Node2D, world_pos: Vector2, _desk_color: Color,
		emp_name: String, is_player: bool, is_occupied: bool, _idx: int) -> void:
	# ── Desk: 3×2 grid sprite (desk_wood at col=0,row=52 in 1_Generic) ──────
	_sp(canvas, _GENERIC, SP_DESK_WOOD[0], SP_DESK_WOOD[1],
		SP_DESK_WOOD[2], SP_DESK_WOOD[3], world_pos.x, world_pos.y, 1)

	# ── Chair: 2×2 packed sprite (chair_office_blue at col=10,row=39) ───────
	_sp2(canvas, _GENERIC, SP_CHAIR_BLUE[0], SP_CHAIR_BLUE[1],
		world_pos.x + 8.0, world_pos.y + 32.0, 1)

	# ── Screen tint overlay (indicates player / occupied seat) ───────────────
	if is_player or is_occupied:
		var sc := Color(0.10, 0.50, 0.80, 0.70) if is_player else Color(0.12, 0.55, 0.22, 0.60)
		var overlay := ColorRect.new()
		overlay.position = world_pos + Vector2(24.0, 3.0)  # over monitor area (right tile)
		overlay.size     = Vector2(12.0, 9.0)
		overlay.color    = sc
		overlay.z_index  = 2
		canvas.add_child(overlay)

	# ── Name label ───────────────────────────────────────────────────────────
	if emp_name != "" or is_player:
		var display := emp_name
		if is_player:
			display = PlayerData.display_name if Engine.has_singleton("PlayerData") else "You"
		var np := Label.new()
		np.name = _uid("NP")
		np.text = display
		np.position = world_pos + Vector2(-4.0, -12.0)
		np.add_theme_font_size_override("font_size", 6)
		np.modulate = Color(0.9, 1.0, 0.7)
		canvas.add_child(np)

func _draw_ghost_figure(canvas: Node2D, world_pos: Vector2, dept_color: Color, idx: int) -> void:
	var alpha := 0.45 + fmod(float(idx) * 0.05, 0.25)
	var gc := Color(dept_color.r, dept_color.g, dept_color.b, alpha)
	_draw_rect(canvas, Rect2(world_pos + Vector2(11.0, -22.0), Vector2(10.0, 14.0)), gc.darkened(0.35), _uid("GB"))
	_draw_rect(canvas, Rect2(world_pos + Vector2(12.0, -32.0), Vector2(8.0, 8.0)),   gc.darkened(0.20), _uid("GH"))

# ─────────────────────────────────────────────────────────────
#  Build office
# ─────────────────────────────────────────────────────────────
func _build_office() -> void:
	_setup_tilemap()
	var canvas := Node2D.new()
	canvas.name = "PrototypeCanvas"
	canvas.z_index = -10
	add_child(canvas)

	_draw_base_floor(canvas)
	_draw_zone_floors(canvas)
	_draw_zone_borders(canvas)
	_draw_grand_entrance(canvas)
	_draw_creative_lab(canvas)
	_draw_atrium(canvas)
	_draw_inner_garden(canvas)
	_draw_engineering_hub(canvas)
	_draw_wellness_lounge(canvas)
	_draw_pool_complex(canvas)
	_draw_work_pods(canvas)
	_draw_meeting_suites(canvas)
	_draw_game_lab(canvas)
	_draw_botanical_park(canvas)
	_draw_dining_pavilion(canvas)
	_draw_rooftop_terrace(canvas)
	_draw_recreation_strip(canvas)
	_draw_parking(canvas)
	_draw_outer_wall(canvas)

func _draw_base_floor(canvas: Node2D) -> void:
	if _tilemap_active:
		return
	_draw_rect(canvas,
		Rect2(0.0, 0.0, float(OFFICE_W * TILE_SIZE), float(OFFICE_H * TILE_SIZE)),
		Color(0.07, 0.07, 0.11), "BaseFloor")

func _draw_zone_floors(canvas: Node2D) -> void:
	if _tilemap_active:
		return
	# Entrance, atrium, inner_garden draw their own floors
	var skip: Array = ["entrance", "atrium", "inner_garden"]
	for zone_id in ZONE_COLORS:
		if zone_id in skip:
			continue
		var zr: Rect2i = ZONE_RECTS.get(zone_id, Rect2i())
		if zr.size == Vector2i.ZERO:
			continue
		_draw_rect(canvas,
			Rect2(Vector2(zr.position) * TILE_SIZE, Vector2(zr.size) * TILE_SIZE),
			ZONE_COLORS[zone_id], "Floor_" + zone_id)

func _draw_outer_wall(canvas: Node2D) -> void:
	_draw_border(canvas,
		Rect2(0.0, 0.0, float(OFFICE_W * TILE_SIZE), float(OFFICE_H * TILE_SIZE)),
		Color(0.50, 0.50, 0.65), "OuterWall", 3.0)
	_draw_border(canvas,
		Rect2(3.0, 3.0, float(OFFICE_W * TILE_SIZE) - 6.0, float(OFFICE_H * TILE_SIZE) - 6.0),
		Color(0.60, 0.60, 0.80, 0.25), "OuterWallGlow", 1.0)

func _draw_zone_borders(canvas: Node2D) -> void:
	var wall_c  := Color(0.22, 0.22, 0.32)
	var accent  := Color(0.45, 0.45, 0.65, 0.35)
	var ts      := float(TILE_SIZE)

	# Horizontal band dividers
	for hy in [14, 96, 210, 310, 340]:
		_draw_rect(canvas, Rect2(0.0, float(hy) * ts, float(OFFICE_W) * ts, ts), wall_c, "HDiv_%d" % hy)
		_draw_rect(canvas, Rect2(0.0, float(hy) * ts - 2.0, float(OFFICE_W) * ts, 2.0), accent, "HAccent_%d" % hy)

	# Vertical dividers — North Building
	for vx in [120, 260, 360]:
		_draw_rect(canvas, Rect2(float(vx) * ts, 14.0 * ts, ts, 82.0 * ts), wall_c, "VDiv_N%d" % vx)

	# Atrium / Inner Garden horizontal split
	_draw_rect(canvas, Rect2(120.0 * ts, 54.0 * ts, 140.0 * ts, ts), wall_c, "HDiv_AtrGarden")

	# Vertical dividers — Amenities Row
	for vx in [160, 260, 320]:
		_draw_rect(canvas, Rect2(float(vx) * ts, 96.0 * ts, ts, 114.0 * ts), wall_c, "VDiv_A%d" % vx)

	# Vertical dividers — Lifestyle Campus
	for vx in [200, 340]:
		_draw_rect(canvas, Rect2(float(vx) * ts, 210.0 * ts, ts, 100.0 * ts), wall_c, "VDiv_L%d" % vx)

# ─────────────────────────────────────────────────────────────
#  Grand Entrance  (480×14 tiles @ 0,0)
# ─────────────────────────────────────────────────────────────
func _draw_grand_entrance(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["entrance"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_draw_rect(canvas, Rect2(origin, size), ZONE_COLORS["entrance"], "Ent_Floor")

	# Central driveway
	_draw_rect(canvas, Rect2(Vector2(180.0 * ts, origin.y), Vector2(120.0 * ts, size.y)),
		Color(0.20, 0.20, 0.28), "Ent_Drive")
	# Drive center line
	_draw_rect(canvas, Rect2(Vector2(238.0 * ts, origin.y), Vector2(4.0 * ts, size.y)),
		Color(1.0, 1.0, 1.0, 0.06), "Ent_DriveLine")

	# Gate pillars
	for gx in [178, 298]:
		_draw_rect(canvas, Rect2(Vector2(float(gx) * ts, origin.y), Vector2(2.0 * ts, size.y)),
			Color(0.55, 0.55, 0.72), _uid("GatePillar"))
		_draw_rect(canvas, Rect2(Vector2(float(gx) * ts, origin.y), Vector2(2.0 * ts, 3.0)),
			Color(0.80, 0.80, 0.95), _uid("GatePillarCap"))

	# Studio name
	_label(canvas, Vector2(190.0 * ts, origin.y + 3.0),
		"ZPS GAME STUDIO", Color(0.88, 0.92, 1.0, 0.95), 20)

	# Fountain
	_draw_rect(canvas,
		Rect2(Vector2(224.0 * ts, origin.y + 2.0 * ts), Vector2(32.0 * ts, 9.0 * ts)),
		Color(0.22, 0.52, 0.80, 0.80), "Ent_Fountain")
	_draw_border(canvas,
		Rect2(Vector2(224.0 * ts, origin.y + 2.0 * ts), Vector2(32.0 * ts, 9.0 * ts)),
		Color(0.72, 0.68, 0.54), "Ent_FountainEdge", 2.5)
	_draw_rect(canvas,
		Rect2(Vector2(233.0 * ts, origin.y + 3.5 * ts), Vector2(14.0 * ts, 6.0 * ts)),
		Color(0.30, 0.65, 0.92, 0.55), "Ent_FountainInner")
	# Shimmer
	for si in range(3):
		_draw_rect(canvas,
			Rect2(Vector2(float(226 + si * 8) * ts, origin.y + 5.0 * ts), Vector2(4.0 * ts, 1.5)),
			Color(0.92, 0.96, 1.0, 0.30), _uid("Ent_Shimmer"))

	# Palm trees
	for px in [5, 25, 45, 65, 90, 115, 140, 340, 365, 390, 420, 445, 465]:
		_draw_palm(canvas, Vector2(float(px) * ts, origin.y + ts))

	# Flower beds (skip driveway zone)
	var fl_colors: Array = [Color(0.90, 0.28, 0.25), Color(0.95, 0.82, 0.15), Color(0.45, 0.18, 0.85)]
	for fi in range(8):
		var fx := float(fi * 20 + 5) * ts
		if fx < 174.0 * ts or fx > 310.0 * ts:
			_draw_rect(canvas,
				Rect2(Vector2(fx, origin.y + 9.0 * ts), Vector2(14.0 * ts, 3.0 * ts)),
				fl_colors[fi % fl_colors.size()].darkened(0.12), _uid("Ent_Flower"))

# ─────────────────────────────────────────────────────────────
#  Creative Lab  (120×82 tiles @ 0,14)
# ─────────────────────────────────────────────────────────────
func _draw_creative_lab(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["creative_lab"]
	var origin := Vector2(zr.position) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "CREATIVE LAB", Color(0.85, 0.50, 1.0, 0.80))

	# Colorful art wall (north edge)
	var art_colors: Array = [
		Color(0.85, 0.20, 0.20), Color(0.85, 0.65, 0.10), Color(0.15, 0.72, 0.30),
		Color(0.15, 0.45, 0.92), Color(0.75, 0.20, 0.85), Color(0.10, 0.80, 0.80),
	]
	for ai in range(6):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(ai) * 20.0 * ts, ts), Vector2(18.0 * ts, 6.0 * ts)),
			art_colors[ai].darkened(0.28), _uid("ArtPanel"))
		_draw_border(canvas,
			Rect2(origin + Vector2(float(ai) * 20.0 * ts, ts), Vector2(18.0 * ts, 6.0 * ts)),
			art_colors[ai].lightened(0.10), _uid("ArtFrame"), 1.5)

	# 3 scattered desk clusters
	for cluster_idx in range(3):
		var cx_tile: int = CL_CLUSTER_X0[cluster_idx]
		var tc: Color = TEAM_COLORS[cluster_idx % TEAM_COLORS.size()]
		# Cluster tint
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(cx_tile) * ts, float(CL_CLUSTER_Y0) * ts),
				  Vector2(float(CL_COLS * CL_CELL_W) * ts, float(CL_ROWS * CL_CELL_H) * ts)),
			Color(tc.r, tc.g, tc.b, 0.04), _uid("ClTint"))
		for row in range(CL_ROWS):
			for col in range(CL_COLS):
				var wx := origin.x + float(cx_tile + col * CL_CELL_W) * ts
				var wy := origin.y + float(CL_CLUSTER_Y0 + row * CL_CELL_H) * ts
				var idx := cluster_idx * CL_COLS * CL_ROWS + row * CL_COLS + col
				_draw_desk_v2(canvas, Vector2(wx, wy), Color(0.26, 0.20, 0.14), "", false, false, idx)
				_draw_ghost_figure(canvas, Vector2(wx, wy), tc, idx)

	# Inspiration / mood board wall at bottom
	_draw_rect(canvas, Rect2(origin + Vector2(0.0, 68.0 * ts), Vector2(120.0 * ts, 9.0 * ts)),
		Color(0.14, 0.10, 0.22), "CL_InspiWall")
	for ii in range(7):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(ii * 17 + 2) * ts, 69.0 * ts), Vector2(14.0 * ts, 7.0 * ts)),
			art_colors[ii % art_colors.size()].darkened(0.32), _uid("CL_Inspi"))

	# Plants along right wall
	for py in [20, 36, 52]:
		_draw_plant(canvas, origin + Vector2(115.0 * ts, float(py) * ts), _uid("CL_Plant"))

	_WB.decorate_office_zone(canvas, zr, TILE_SIZE, "creative")

# ─────────────────────────────────────────────────────────────
#  Main Atrium  (140×40 tiles @ 120,14)
# ─────────────────────────────────────────────────────────────
func _draw_atrium(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["atrium"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_draw_rect(canvas, Rect2(origin, size), ZONE_COLORS["atrium"], "Atr_Floor")

	# Marble grid overlay
	for si in range(0, 140, 10):
		_draw_rect(canvas, Rect2(origin + Vector2(float(si) * ts, 0.0), Vector2(ts, size.y)),
			Color(1.0, 1.0, 1.0, 0.022), _uid("AtrGV"))
	for si in range(0, 40, 5):
		_draw_rect(canvas, Rect2(origin + Vector2(0.0, float(si) * ts), Vector2(size.x, ts)),
			Color(1.0, 1.0, 1.0, 0.022), _uid("AtrGH"))

	# Welcome sign / logo banner
	_draw_rect(canvas, Rect2(origin + Vector2(25.0 * ts, 0.5 * ts), Vector2(90.0 * ts, 3.0 * ts)),
		Color(0.08, 0.06, 0.18), "Atr_LogoBg")
	_draw_border(canvas, Rect2(origin + Vector2(25.0 * ts, 0.5 * ts), Vector2(90.0 * ts, 3.0 * ts)),
		Color(0.60, 0.45, 0.90, 0.70), "Atr_LogoBorder", 1.5)
	_label(canvas, origin + Vector2(28.0 * ts, 0.7 * ts),
		"ZPS GAME STUDIO — CAMPUS", Color(0.85, 0.90, 1.0, 0.95), 16)

	# Central rug
	_draw_rect(canvas, Rect2(origin + Vector2(20.0 * ts, 5.0 * ts), Vector2(100.0 * ts, 26.0 * ts)),
		Color(0.16, 0.12, 0.28), "Atr_Rug")
	_draw_border(canvas, Rect2(origin + Vector2(20.0 * ts, 5.0 * ts), Vector2(100.0 * ts, 26.0 * ts)),
		Color(0.55, 0.42, 0.82, 0.60), "Atr_RugBorder", 2.5)

	# Reception desk (L-shape)
	var rdx := origin.x + 30.0 * ts
	var rdy := origin.y + 8.0 * ts
	_draw_rect(canvas, Rect2(Vector2(rdx, rdy), Vector2(80.0 * ts, 4.5 * ts)), Color(0.38, 0.30, 0.18), "Atr_Desk")
	_draw_rect(canvas, Rect2(Vector2(rdx, rdy), Vector2(80.0 * ts, 2.0)), Color(0.58, 0.48, 0.28), "Atr_DeskTop")
	for mi in range(3):
		var mx := rdx + float(10 + mi * 25) * ts
		_draw_rect(canvas, Rect2(Vector2(mx, rdy - 3.0 * ts), Vector2(4.0 * ts, 3.0 * ts)), Color(0.06, 0.06, 0.10), _uid("AtrMon"))
		_draw_rect(canvas, Rect2(Vector2(mx + 3.0, rdy - 2.5 * ts), Vector2(ts * 3.4, ts * 1.8)), Color(0.08, 0.32, 0.52), _uid("AtrScr"))

	# Sofas
	_draw_sofa(canvas, origin + Vector2(22.0 * ts, 15.0 * ts), 12.0, Color(0.28, 0.22, 0.42))
	_draw_sofa(canvas, origin + Vector2(88.0 * ts, 15.0 * ts), 12.0, Color(0.28, 0.22, 0.42))
	_draw_sofa(canvas, origin + Vector2(40.0 * ts, 27.0 * ts), 20.0, Color(0.32, 0.25, 0.48))

	# Feature sculpture
	_draw_rect(canvas, Rect2(origin + Vector2(62.0 * ts, 13.0 * ts), Vector2(16.0 * ts, 16.0 * ts)),
		Color(0.12, 0.08, 0.20), "Atr_SclBase")
	_draw_rect(canvas, Rect2(origin + Vector2(64.0 * ts, 6.0 * ts), Vector2(12.0 * ts, 11.0 * ts)),
		Color(0.50, 0.35, 0.82, 0.70), "Atr_Scl")
	_draw_border(canvas, Rect2(origin + Vector2(64.0 * ts, 6.0 * ts), Vector2(12.0 * ts, 11.0 * ts)),
		Color(0.80, 0.60, 1.0, 0.50), "Atr_SclBorder", 1.5)

	# Lobby plants
	for px in [21, 109]:
		_draw_plant(canvas, origin + Vector2(float(px) * ts, 4.0 * ts), _uid("Atr_Plant"))
	_draw_plant(canvas, origin + Vector2(130.0 * ts, 12.0 * ts), "Atr_PlantCorner")

# ─────────────────────────────────────────────────────────────
#  Inner Garden / Courtyard  (140×42 tiles @ 120,54)
# ─────────────────────────────────────────────────────────────
func _draw_inner_garden(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["inner_garden"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_draw_rect(canvas, Rect2(origin, size), ZONE_COLORS["inner_garden"], "IGarden_Floor")

	# Stone paths (cross)
	_draw_rect(canvas, Rect2(origin + Vector2(60.0 * ts, 0.0), Vector2(20.0 * ts, size.y)),
		Color(0.30, 0.28, 0.33), "IGarden_PathV")
	_draw_rect(canvas, Rect2(origin + Vector2(0.0, 16.0 * ts), Vector2(size.x, 10.0 * ts)),
		Color(0.30, 0.28, 0.33), "IGarden_PathH")

	# Fountain
	_draw_rect(canvas, Rect2(origin + Vector2(62.0 * ts, 6.0 * ts), Vector2(16.0 * ts, 8.0 * ts)),
		Color(0.20, 0.55, 0.82, 0.85), "IGarden_Fountain")
	_draw_border(canvas, Rect2(origin + Vector2(62.0 * ts, 6.0 * ts), Vector2(16.0 * ts, 8.0 * ts)),
		Color(0.65, 0.62, 0.50), "IGarden_FountainEdge", 2.0)
	_draw_rect(canvas, Rect2(origin + Vector2(67.0 * ts, 7.5 * ts), Vector2(6.0 * ts, 5.0 * ts)),
		Color(0.30, 0.70, 0.95, 0.60), "IGarden_FountainInner")
	for si in range(3):
		_draw_rect(canvas, Rect2(origin + Vector2(float(63 + si * 4) * ts, 9.0 * ts), Vector2(2.0 * ts, 1.5)),
			Color(0.85, 0.95, 1.0, 0.30), _uid("IG_Shimmer"))

	# Trees in 4 quadrants
	var qtrees: Array = [
		Vector2(8,3), Vector2(22,7), Vector2(38,3), Vector2(50,8),
		Vector2(95,5), Vector2(110,3), Vector2(122,8), Vector2(130,4),
		Vector2(6,28), Vector2(25,32), Vector2(45,28), Vector2(52,34),
		Vector2(92,30), Vector2(112,28), Vector2(126,32), Vector2(136,30),
	]
	for qt in qtrees:
		_draw_tree(canvas, origin + Vector2(float(qt.x) * ts, float(qt.y) * ts))

	# Benches along paths
	for bx in [5, 50, 90, 128]:
		_draw_rect(canvas, Rect2(origin + Vector2(float(bx) * ts, 14.5 * ts), Vector2(7.0 * ts, 2.5 * ts)),
			Color(0.50, 0.38, 0.22), _uid("IG_Bench"))

	# Flowers
	var fl_c: Array = [Color(0.92, 0.28, 0.28), Color(0.92, 0.85, 0.15), Color(0.50, 0.15, 0.92), Color(0.15, 0.78, 0.88)]
	for fi in range(12):
		var fx := float((fi * 11 + 7) % 130) * ts
		var fy := float((fi * 7 + 4) % 40) * ts
		_draw_rect(canvas, Rect2(origin + Vector2(fx, fy), Vector2(4.0 * ts, 2.0 * ts)),
			fl_c[fi % fl_c.size()].darkened(0.10), _uid("IG_Flower"))

	_WB.decorate_japanese_zone(canvas, zr, TILE_SIZE)

# ─────────────────────────────────────────────────────────────
#  Engineering Hub  (100×82 tiles @ 260,14)
# ─────────────────────────────────────────────────────────────
func _draw_engineering_hub(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["engineering_hub"]
	var origin := Vector2(zr.position) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "ENGINEERING HUB", Color(0.40, 0.85, 0.55, 0.80))

	# Subtle grid overlay
	for gx in range(0, 100, 6):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(gx) * ts, 0.0), Vector2(1.0, float(ZONE_RECTS["engineering_hub"].size.y) * ts)),
			Color(1.0, 1.0, 1.0, 0.018), _uid("EH_GV"))

	# 6 rows × 15 desks
	for row in range(6):
		var wy := origin.y + float(EH_ROW0 + row * EH_CELL_H) * ts
		var tc: Color = TEAM_COLORS[(row * 2) % TEAM_COLORS.size()]
		for col in range(EH_COLS):
			var wx := origin.x + float(2 + col * EH_CELL_W) * ts
			var idx := row * EH_COLS + col
			_draw_desk_v2(canvas, Vector2(wx, wy), Color(0.20, 0.17, 0.12), "", false, false, idx)
			_draw_ghost_figure(canvas, Vector2(wx, wy), tc, idx)
		_label(canvas, Vector2(origin.x + 1.0, wy - ts * 1.2),
			"R%d" % (row + 1), Color(0.40, 0.70, 0.50, 0.22), 7)

	# Server rack corner
	_draw_rect(canvas, Rect2(origin + Vector2(86.0 * ts, 2.0 * ts), Vector2(12.0 * ts, 12.0 * ts)),
		Color(0.14, 0.17, 0.22), "EH_ServerRack")
	_draw_border(canvas, Rect2(origin + Vector2(86.0 * ts, 2.0 * ts), Vector2(12.0 * ts, 12.0 * ts)),
		Color(0.28, 0.55, 0.28, 0.60), "EH_ServerBorder", 1.0)
	for si in range(6):
		_draw_rect(canvas,
			Rect2(origin + Vector2(87.0 * ts, float(2 + si * 2) * ts), Vector2(10.0 * ts, ts * 0.8)),
			Color(0.05, 0.40, 0.10, 0.80), _uid("EH_SRLight"))

	# Whiteboard wall
	_draw_rect(canvas, Rect2(origin + Vector2(0.0, 76.0 * ts), Vector2(100.0 * ts, 5.0 * ts)),
		Color(0.90, 0.92, 0.95), "EH_Whiteboard")
	_draw_border(canvas, Rect2(origin + Vector2(0.0, 76.0 * ts), Vector2(100.0 * ts, 5.0 * ts)),
		Color(0.50, 0.50, 0.58), "EH_WBFrame", 2.0)
	_draw_rect(canvas, Rect2(origin + Vector2(5.0, 76.5 * ts), Vector2(90.0 * ts, 4.0 * ts)),
		Color(0.20, 0.40, 0.70, 0.14), "EH_WBContent")

	_WB.decorate_office_zone(canvas, zr, TILE_SIZE, "engineering")

# ─────────────────────────────────────────────────────────────
#  Wellness Lounge  (120×82 tiles @ 360,14)
# ─────────────────────────────────────────────────────────────
func _draw_wellness_lounge(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["wellness_lounge"]
	var origin := Vector2(zr.position) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "WELLNESS & GAMES", Color(0.70, 0.45, 0.95, 0.80))

	# 3 big-screen gaming stations
	for i in range(3):
		var gx := origin.x + float(5 + i * 38) * ts
		var gy := origin.y + 10.0 * ts
		_draw_rect(canvas, Rect2(Vector2(gx, gy), Vector2(28.0 * ts, 18.0 * ts)),
			Color(0.06, 0.06, 0.10), _uid("WL_TVBase"))
		_draw_rect(canvas, Rect2(Vector2(gx + ts, gy + ts), Vector2(26.0 * ts, 14.0 * ts)),
			Color(0.05, 0.20, 0.38, 0.90), _uid("WL_TV"))
		_draw_border(canvas, Rect2(Vector2(gx, gy), Vector2(28.0 * ts, 18.0 * ts)),
			Color(0.35, 0.35, 0.50, 0.50), _uid("WL_TVFrame"), 1.5)
		_draw_sofa(canvas, Vector2(gx, gy + 22.0 * ts), 7.0, Color(0.22, 0.18, 0.32))

	# Coffee bar
	_draw_rect(canvas, Rect2(origin + Vector2(4.0 * ts, 58.0 * ts), Vector2(112.0 * ts, 6.0 * ts)),
		Color(0.35, 0.28, 0.18), "WL_CoffeeBar")
	_draw_rect(canvas, Rect2(origin + Vector2(4.0 * ts, 58.0 * ts), Vector2(112.0 * ts, 2.0)),
		Color(0.55, 0.44, 0.28), "WL_CoffeeBarTop")
	for si in range(8):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(6 + si * 13) * ts, 56.0 * ts), Vector2(8.0 * ts, 2.0 * ts)),
			Color(0.20, 0.20, 0.28), _uid("WL_Stool"))

	# Bean bag corner
	var bb_c: Array = [Color(0.80, 0.25, 0.25), Color(0.25, 0.60, 0.80), Color(0.80, 0.70, 0.10), Color(0.25, 0.80, 0.35)]
	for bi in range(4):
		var bx := origin + Vector2(float(bi * 26 + 6) * ts, 70.0 * ts)
		_draw_rect(canvas, Rect2(bx, Vector2(16.0 * ts, 8.0 * ts)), bb_c[bi], _uid("WL_BB"))
		_draw_rect(canvas, Rect2(bx + Vector2(3.0 * ts, ts), Vector2(10.0 * ts, 6.0 * ts)),
			bb_c[bi].lightened(0.15), _uid("WL_BBTop"))

	for px in [2, 114]:
		_draw_plant(canvas, origin + Vector2(float(px) * ts, 40.0 * ts), _uid("WL_Plant"))

	_WB.decorate_lounge_zone(canvas, zr, TILE_SIZE)

# ─────────────────────────────────────────────────────────────
#  Pool Complex  (160×114 tiles @ 0,96)
# ─────────────────────────────────────────────────────────────
func _draw_pool_complex(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["pool_complex"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "POOL & FITNESS", Color(0.30, 0.78, 0.95, 0.80))

	# Pool deck (stone tone, already drawn by zone floor)

	# Main lap pool
	var pw := 128.0 * ts
	var ph := 58.0 * ts
	var px := origin.x + 16.0 * ts
	var py := origin.y + 6.0 * ts
	_draw_rect(canvas, Rect2(Vector2(px, py), Vector2(pw, ph)), Color(0.15, 0.52, 0.80), "Pool_Water")
	# Lanes (8)
	for li in range(1, 8):
		_draw_rect(canvas,
			Rect2(Vector2(px + 2.0 * ts, py + float(li) * (ph / 8.0)), Vector2(pw - 4.0 * ts, 1.5)),
			Color(0.80, 0.80, 0.88, 0.55), _uid("Pool_Lane"))
	_draw_border(canvas, Rect2(Vector2(px, py), Vector2(pw, ph)), Color(0.82, 0.78, 0.65), "Pool_Edge", 4.0)
	# Shimmer
	for si in range(5):
		_draw_rect(canvas,
			Rect2(Vector2(px + float(si * 22 + 6) * ts, py + ph * 0.38), Vector2(10.0 * ts, 1.5)),
			Color(0.92, 0.96, 1.0, 0.22), _uid("Pool_Shimmer"))

	# Sun loungers (north of pool)
	for li in range(8):
		var lx := px + float(li) * (pw / 8.0) + ts
		var ly := py - 5.0 * ts
		_draw_rect(canvas, Rect2(Vector2(lx, ly), Vector2(12.0 * ts, 3.0 * ts)), Color(0.95, 0.88, 0.70), _uid("Lounger"))
		_draw_rect(canvas, Rect2(Vector2(lx, ly), Vector2(12.0 * ts, ts * 0.7)), Color(0.70, 0.60, 0.42), _uid("LoungerStripe"))
	# Towels
	for ti in range(4):
		_draw_rect(canvas,
			Rect2(Vector2(px + float(ti * 28 + 8) * ts, py - 3.0 * ts), Vector2(7.0 * ts, 2.0 * ts)),
			Color(0.80, 0.25, 0.25) if ti % 2 == 0 else Color(0.25, 0.50, 0.82), _uid("Towel"))

	# Jacuzzi / spa corner
	_draw_rect(canvas, Rect2(origin + Vector2(2.0 * ts, 6.0 * ts), Vector2(13.0 * ts, 13.0 * ts)),
		Color(0.25, 0.62, 0.82), "Pool_Jacuzzi")
	_draw_border(canvas, Rect2(origin + Vector2(2.0 * ts, 6.0 * ts), Vector2(13.0 * ts, 13.0 * ts)),
		Color(0.82, 0.78, 0.65), "Pool_JacuzziEdge", 2.0)
	_label(canvas, origin + Vector2(2.5 * ts, 11.5 * ts), "SPA", Color(0.50, 0.88, 1.0, 0.75), 9)

	# Changing rooms
	_draw_rect(canvas, Rect2(origin + Vector2(0.0, 70.0 * ts), Vector2(15.0 * ts, 42.0 * ts)),
		Color(0.10, 0.12, 0.17), "Pool_ChangeRoom")
	_draw_border(canvas, Rect2(origin + Vector2(0.0, 70.0 * ts), Vector2(15.0 * ts, 42.0 * ts)),
		Color(0.30, 0.35, 0.45, 0.50), "Pool_ChangeRoomBorder", 1.5)
	_label(canvas, origin + Vector2(ts, 76.0 * ts), "M / F", Color(0.62, 0.68, 0.82, 0.70), 9)

	# Fitness zone
	_draw_rect(canvas, Rect2(origin + Vector2(16.0 * ts, 70.0 * ts), Vector2(144.0 * ts, 42.0 * ts)),
		Color(0.08, 0.10, 0.15), "Fitness_Floor")
	_label(canvas, origin + Vector2(18.0 * ts, 72.0 * ts), "FITNESS CENTER", Color(0.40, 0.85, 0.45, 0.75), 11)
	var fit_zr := Rect2i(zr.position + Vector2i(16, 70), Vector2i(144, 42))
	_WB.decorate_gym_zone(canvas, fit_zr, TILE_SIZE)

# ─────────────────────────────────────────────────────────────
#  Open Work Pods  (100×114 tiles @ 160,96)
# ─────────────────────────────────────────────────────────────
func _draw_work_pods(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["work_pods"]
	var origin := Vector2(zr.position) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "OPEN PODS", Color(0.55, 0.75, 1.0, 0.60))

	var pod_names: Array = ["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON"]

	for pod_idx in range(WP_POD_TOPS.size()):
		var pod_top_abs: int = WP_POD_TOPS[pod_idx]
		var top_y := float(pod_top_abs) * ts
		var bot_y := float(pod_top_abs + WP_BOT_OFFSET) * ts

		_label(canvas, Vector2(origin.x + ts, top_y + ts * 0.3),
			pod_names[pod_idx], Color(0.50, 0.62, 0.85, 0.28), 7)

		# Center aisle
		_draw_rect(canvas,
			Rect2(Vector2(origin.x, float(pod_top_abs + 5) * ts), Vector2(float(zr.size.x) * ts, ts * 2.0)),
			Color(0.04, 0.05, 0.09, 0.50), _uid("WP_Aisle"))

		for s in range(WP_DESKS_HALF):
			var wx := float(WP_DESK_X0 + s * WP_CELL_W) * ts
			var team_idx: int = s / 5
			var tc: Color = TEAM_COLORS[(team_idx + pod_idx) % TEAM_COLORS.size()]
			var idx := pod_idx * WP_DESKS_HALF * 2 + s

			if s % 5 == 0 and s > 0:
				_draw_rect(canvas,
					Rect2(Vector2(wx - 1.0, top_y - ts * 0.5), Vector2(2.0, ts * float(WP_BOT_OFFSET + 3))),
					Color(tc.r, tc.g, tc.b, 0.14), _uid("WP_TeamDiv"))

			_draw_desk_v2(canvas, Vector2(wx, top_y), Color(0.28, 0.22, 0.13), "", false, false, idx)
			_draw_ghost_figure(canvas, Vector2(wx, top_y), tc, idx)
			_draw_desk_v2(canvas, Vector2(wx, bot_y), Color(0.28, 0.22, 0.13), "", false, false, idx + WP_DESKS_HALF)
			_draw_ghost_figure(canvas, Vector2(wx, bot_y - ts * 4.0), tc, idx + WP_DESKS_HALF)

	# Snack bar at bottom
	_draw_rect(canvas, Rect2(origin + Vector2(5.0 * ts, 108.0 * ts), Vector2(90.0 * ts, 4.0 * ts)),
		Color(0.30, 0.24, 0.15), "WP_SnackBar")
	_draw_rect(canvas, Rect2(origin + Vector2(5.0 * ts, 108.0 * ts), Vector2(90.0 * ts, 2.0)),
		Color(0.50, 0.40, 0.22), "WP_SnackTop")

	# Side plants
	for py in [98, 118, 138, 158, 178, 196]:
		_draw_plant(canvas, Vector2(origin.x + ts, float(py) * ts), _uid("WP_PlantL"))
		_draw_plant(canvas, Vector2(origin.x + float(zr.size.x - 2) * ts, float(py) * ts), _uid("WP_PlantR"))

	_WB.decorate_office_zone(canvas, zr, TILE_SIZE, "studio")

# ─────────────────────────────────────────────────────────────
#  Meeting Suites  (60×114 tiles @ 260,96)
#  5 rooms stacked vertically
# ─────────────────────────────────────────────────────────────
func _draw_meeting_suites(canvas: Node2D) -> void:
	# Room Alpha — rendered from layout JSON via RoomLoader
	var alpha_origin := Vector2(260.0 * TILE_SIZE, 96.0 * TILE_SIZE)
	_RL.load_into(canvas, "res://assets/maps/conference_layout.json", alpha_origin)
	# Room Beta–Boardroom — still drawn programmatically
	_draw_meeting_room(canvas, Rect2i(260, 118, 60, 22), 6,  "Room Beta")
	_draw_meeting_room(canvas, Rect2i(260, 140, 60, 22), 8,  "Room Gamma")
	_draw_meeting_room(canvas, Rect2i(260, 162, 60, 24), 10, "Room Delta")
	_draw_meeting_room(canvas, Rect2i(260, 186, 60, 24), 14, "Boardroom")

# ─────────────────────────────────────────────────────────────
#  Game Lab / QA  (160×114 tiles @ 320,96)
# ─────────────────────────────────────────────────────────────
func _draw_game_lab(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["game_lab"]
	var origin := Vector2(zr.position) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "GAME LAB / QA", Color(1.00, 0.50, 0.20, 0.85))

	# Big screen wall (4 screens at top)
	_draw_rect(canvas, Rect2(origin, Vector2(160.0 * ts, 9.0 * ts)), Color(0.06, 0.04, 0.10), "GL_ScreenWall")
	for si in range(4):
		var sx := origin.x + float(4 + si * 38) * ts
		_draw_rect(canvas, Rect2(Vector2(sx, origin.y + ts), Vector2(32.0 * ts, 7.0 * ts)),
			Color(0.05, 0.18, 0.35), _uid("GL_BigScreen"))
		_draw_border(canvas, Rect2(Vector2(sx, origin.y + ts), Vector2(32.0 * ts, 7.0 * ts)),
			Color(0.30, 0.40, 0.60, 0.50), _uid("GL_ScreenFrame"), 1.5)
		_draw_rect(canvas, Rect2(Vector2(sx + 2.0 * ts, origin.y + 2.0 * ts), Vector2(28.0 * ts, 5.0 * ts)),
			Color(0.08, 0.30, 0.55, 0.90), _uid("GL_ScreenOn"))

	# QA testing rows (4 rows × 8 stations, dual-monitor setup)
	for row in range(4):
		for col in range(8):
			var wx := origin.x + float(2 + col * 18) * ts
			var wy := origin.y + float(11 + row * 22) * ts
			_draw_rect(canvas, Rect2(Vector2(wx, wy), Vector2(14.0 * ts, 4.0 * ts)), Color(0.22, 0.17, 0.10), _uid("GL_Desk"))
			# Dual monitors
			_draw_rect(canvas, Rect2(Vector2(wx + ts, wy - 3.5 * ts), Vector2(5.0 * ts, 3.0 * ts)), Color(0.06, 0.06, 0.10), _uid("GL_Mon1"))
			_draw_rect(canvas, Rect2(Vector2(wx + 8.0 * ts, wy - 3.5 * ts), Vector2(5.0 * ts, 3.0 * ts)), Color(0.06, 0.06, 0.10), _uid("GL_Mon2"))
			_draw_rect(canvas, Rect2(Vector2(wx + ts + 3.0, wy - 3.0 * ts), Vector2(3.5 * ts, 2.0 * ts)), Color(0.10, 0.35, 0.15, 0.90), _uid("GL_Scr1"))
			_draw_rect(canvas, Rect2(Vector2(wx + 8.5 * ts, wy - 3.0 * ts), Vector2(3.5 * ts, 2.0 * ts)), Color(0.10, 0.35, 0.55, 0.90), _uid("GL_Scr2"))
			var tc: Color = TEAM_COLORS[(row + col) % TEAM_COLORS.size()]
			_draw_ghost_figure(canvas, Vector2(wx + 4.0 * ts, wy), tc, row * 8 + col)

	# Playtesting corner (couch + big screen)
	_draw_sofa(canvas, origin + Vector2(4.0 * ts, 97.0 * ts),  18.0, Color(0.25, 0.18, 0.38))
	_draw_sofa(canvas, origin + Vector2(82.0 * ts, 97.0 * ts), 18.0, Color(0.25, 0.18, 0.38))
	_draw_rect(canvas, Rect2(origin + Vector2(24.0 * ts, 99.0 * ts), Vector2(56.0 * ts, 14.0 * ts)),
		Color(0.05, 0.15, 0.28), "GL_PlayTV")
	_draw_rect(canvas, Rect2(origin + Vector2(25.0 * ts, 100.0 * ts), Vector2(54.0 * ts, 12.0 * ts)),
		Color(0.08, 0.28, 0.48, 0.90), "GL_PlayScreen")
	# Controller rack
	for ci in range(4):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(ci * 36 + 6) * ts, 112.0 * ts), Vector2(22.0 * ts, ts * 1.2)),
			Color(0.28, 0.28, 0.42), _uid("GL_CtrlRack"))

# ─────────────────────────────────────────────────────────────
#  Botanical Park  (200×100 tiles @ 0,210)
# ─────────────────────────────────────────────────────────────
func _draw_botanical_park(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["botanical_park"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "BOTANICAL PARK", Color(0.35, 0.95, 0.42, 0.85))

	# Paths
	_draw_rect(canvas, Rect2(origin + Vector2(0.0, 40.0 * ts), Vector2(size.x, 8.0 * ts)), Color(0.28, 0.26, 0.32), "BP_PathH")
	_draw_rect(canvas, Rect2(origin + Vector2(88.0 * ts, 0.0), Vector2(8.0 * ts, size.y)), Color(0.28, 0.26, 0.32), "BP_PathV")
	_draw_rect(canvas, Rect2(origin + Vector2(0.0, 68.0 * ts), Vector2(88.0 * ts, 6.0 * ts)), Color(0.26, 0.24, 0.30), "BP_PathH2")

	# Large pond
	_draw_rect(canvas, Rect2(origin + Vector2(100.0 * ts, 14.0 * ts), Vector2(88.0 * ts, 24.0 * ts)),
		Color(0.12, 0.42, 0.65, 0.85), "BP_Pond")
	_draw_border(canvas, Rect2(origin + Vector2(100.0 * ts, 14.0 * ts), Vector2(88.0 * ts, 24.0 * ts)),
		Color(0.22, 0.55, 0.35, 0.80), "BP_PondEdge", 3.0)
	for si in range(4):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(102 + si * 20) * ts, 20.0 * ts), Vector2(10.0 * ts, 1.5)),
			Color(0.60, 0.82, 1.0, 0.28), _uid("BP_Shimmer"))
	_label(canvas, origin + Vector2(128.0 * ts, 22.0 * ts), "POND", Color(0.50, 0.82, 1.0, 0.72), 10)

	# Dense trees
	var tree_pos: Array = [
		Vector2(4,4), Vector2(15,8), Vector2(28,3), Vector2(44,7), Vector2(58,3), Vector2(72,7),
		Vector2(2,18), Vector2(16,22), Vector2(32,19), Vector2(48,24), Vector2(66,18), Vector2(80,23),
		Vector2(6,52), Vector2(20,57), Vector2(36,53), Vector2(52,59), Vector2(68,54), Vector2(82,57),
		Vector2(4,72), Vector2(18,77), Vector2(34,73), Vector2(50,79), Vector2(64,74), Vector2(80,80),
		Vector2(7,88), Vector2(23,86), Vector2(40,90), Vector2(58,87), Vector2(76,92),
		Vector2(100,4), Vector2(114,8), Vector2(128,3), Vector2(148,7), Vector2(168,4), Vector2(186,8),
		Vector2(97,50), Vector2(112,54), Vector2(128,50), Vector2(144,56), Vector2(162,51), Vector2(180,55),
		Vector2(98,65), Vector2(115,70), Vector2(132,74), Vector2(152,67), Vector2(174,72), Vector2(192,68),
		Vector2(96,82), Vector2(110,86), Vector2(126,90), Vector2(144,84), Vector2(160,87), Vector2(180,92),
	]
	for tp in tree_pos:
		_draw_tree(canvas, origin + Vector2(float(tp.x) * ts, float(tp.y) * ts))

	# Flower meadows
	var fl_c: Array = [Color(0.95, 0.25, 0.25), Color(0.95, 0.85, 0.15), Color(0.55, 0.15, 0.95), Color(0.15, 0.80, 0.90), Color(0.95, 0.55, 0.15)]
	for fi in range(20):
		var fx := float((fi * 17 + 5) % 190) * ts
		var fy := float((fi * 11 + 3) % 95) * ts
		_draw_rect(canvas, Rect2(origin + Vector2(fx, fy), Vector2(5.0 * ts, 2.0 * ts)),
			fl_c[fi % fl_c.size()].darkened(0.10), _uid("BP_Flower"))

	# Benches along main path
	for bx in [10, 35, 55, 72, 100, 124, 146, 168, 186]:
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(bx) * ts, 48.0 * ts), Vector2(7.0 * ts, 2.5 * ts)),
			Color(0.48, 0.36, 0.20), _uid("BP_Bench"))

	_WB.decorate_garden_zone(canvas, zr, TILE_SIZE)

# ─────────────────────────────────────────────────────────────
#  Dining Pavilion  (140×100 tiles @ 200,210)
# ─────────────────────────────────────────────────────────────
func _draw_dining_pavilion(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["dining_pavilion"]
	var origin := Vector2(zr.position) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "DINING PAVILION", Color(0.95, 0.72, 0.30, 0.85))

	# Buffet counter (top strip)
	var cw := 120.0 * ts
	var cx := origin.x + 10.0 * ts
	var cy := origin.y + 8.0 * ts
	_draw_rect(canvas, Rect2(Vector2(cx, cy), Vector2(cw, 8.0 * ts)), Color(0.38, 0.30, 0.20), "DP_Counter")
	_draw_rect(canvas, Rect2(Vector2(cx, cy), Vector2(cw, 2.0)), Color(0.58, 0.48, 0.30), "DP_CounterTop")
	for fi in range(6):
		_draw_rect(canvas,
			Rect2(Vector2(cx + float(fi * 20 + 2) * ts, cy + ts), Vector2(16.0 * ts, 5.0 * ts)),
			Color(0.20, 0.15, 0.08), _uid("DP_FoodTray"))
		_draw_rect(canvas,
			Rect2(Vector2(cx + float(fi * 20 + 3) * ts, cy + 1.5 * ts), Vector2(14.0 * ts, 4.0 * ts)),
			Color(0.55, 0.25 + float(fi) * 0.06, 0.10 + float(fi) * 0.04, 0.90), _uid("DP_Food"))

	# Dining tables (3 rows)
	var table_pos: Array = [
		Vector2(16, 26), Vector2(42, 26), Vector2(68, 26), Vector2(94, 26), Vector2(118, 26),
		Vector2(16, 52), Vector2(42, 52), Vector2(68, 52), Vector2(94, 52), Vector2(118, 52),
		Vector2(30, 76), Vector2(58, 76), Vector2(86, 76), Vector2(112, 76),
	]
	for tp in table_pos:
		_draw_dining_table(canvas, origin + Vector2(float(tp.x) * ts, float(tp.y) * ts), 4.0)

	# Bar counter (bottom)
	_draw_rect(canvas, Rect2(origin + Vector2(2.0 * ts, 88.0 * ts), Vector2(136.0 * ts, 8.0 * ts)),
		Color(0.32, 0.25, 0.14), "DP_Bar")
	_draw_rect(canvas, Rect2(origin + Vector2(2.0 * ts, 88.0 * ts), Vector2(136.0 * ts, 2.0)),
		Color(0.52, 0.42, 0.24), "DP_BarTop")
	for si in range(10):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(si * 13 + 4) * ts, 86.0 * ts), Vector2(8.0 * ts, 2.0 * ts)),
			Color(0.22, 0.22, 0.30), _uid("DP_Stool"))

	# Plants / decor
	for px in [2, 68, 136]:
		_draw_plant(canvas, origin + Vector2(float(px) * ts, 18.0 * ts), _uid("DP_Plant"))
		_draw_plant(canvas, origin + Vector2(float(px) * ts, 60.0 * ts), _uid("DP_Plant2"))

	_WB.decorate_kitchen_zone(canvas, zr, TILE_SIZE)

# ─────────────────────────────────────────────────────────────
#  Rooftop Terrace  (140×100 tiles @ 340,210)
# ─────────────────────────────────────────────────────────────
func _draw_rooftop_terrace(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["rooftop_terrace"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_label(canvas, origin + Vector2(4.0, 4.0), "ROOFTOP TERRACE", Color(0.70, 0.88, 1.0, 0.85))

	# Wooden deck strips
	for di in range(0, 100, 4):
		_draw_rect(canvas,
			Rect2(origin + Vector2(0.0, float(di) * ts), Vector2(size.x, 2.0 * ts + 1.0)),
			Color(0.30, 0.22, 0.13, 0.38), _uid("RT_Deck"))

	# String lights along top
	for li in range(26):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(li * 5 + 2) * ts, ts * 1.2), Vector2(ts * 0.5, ts * 0.5)),
			Color(1.0, 0.95, 0.60, 0.75), _uid("RT_Light"))

	# Hammock zone (4 hammocks)
	var h_colors: Array = [Color(0.70, 0.25, 0.25), Color(0.25, 0.50, 0.82), Color(0.25, 0.65, 0.35), Color(0.75, 0.60, 0.15)]
	for hi in range(4):
		var hx := origin.x + float(5 + hi * 32) * ts
		var hy := origin.y + 12.0 * ts
		_draw_rect(canvas, Rect2(Vector2(hx, hy - 5.0 * ts), Vector2(ts * 0.8, 12.0 * ts)),
			Color(0.50, 0.38, 0.18), _uid("RT_PoleA"))
		_draw_rect(canvas, Rect2(Vector2(hx + 20.0 * ts, hy - 5.0 * ts), Vector2(ts * 0.8, 12.0 * ts)),
			Color(0.50, 0.38, 0.18), _uid("RT_PoleB"))
		_draw_rect(canvas, Rect2(Vector2(hx, hy + ts), Vector2(20.0 * ts, 4.0 * ts)),
			h_colors[hi].darkened(0.15), _uid("RT_Hammock"))
		_draw_rect(canvas, Rect2(Vector2(hx, hy + ts + 2.0), Vector2(20.0 * ts, 2.0 * ts)),
			h_colors[hi].lightened(0.12), _uid("RT_HammockTop"))

	# Fire pit
	_draw_rect(canvas, Rect2(origin + Vector2(55.0 * ts, 32.0 * ts), Vector2(30.0 * ts, 22.0 * ts)),
		Color(0.15, 0.10, 0.08), "RT_FireArea")
	_draw_rect(canvas, Rect2(origin + Vector2(64.0 * ts, 36.0 * ts), Vector2(12.0 * ts, 12.0 * ts)),
		Color(0.45, 0.20, 0.06), "RT_FirePit")
	_draw_rect(canvas, Rect2(origin + Vector2(66.5 * ts, 38.0 * ts), Vector2(7.0 * ts, 6.0 * ts)),
		Color(0.92, 0.52, 0.10, 0.80), "RT_Fire")
	for fi in range(5):
		var fa := float(fi) * 72.0 * PI / 180.0
		var fcx := origin.x + 70.0 * ts + cos(fa) * 11.0 * ts
		var fcy := origin.y + 42.0 * ts + sin(fa) * 8.0 * ts
		_draw_rect(canvas, Rect2(Vector2(fcx, fcy), Vector2(ts * 3.0, ts * 3.0)),
			Color(0.30, 0.22, 0.14), _uid("RT_FireSeat"))

	# Outdoor lounge sofas
	for si in range(4):
		_draw_sofa(canvas, origin + Vector2(float(si * 32 + 3) * ts, 62.0 * ts), 8.0, Color(0.24, 0.20, 0.38))

	# Bar counter
	_draw_rect(canvas, Rect2(origin + Vector2(4.0 * ts, 86.0 * ts), Vector2(132.0 * ts, 8.0 * ts)),
		Color(0.35, 0.28, 0.18), "RT_Bar")
	_draw_rect(canvas, Rect2(origin + Vector2(4.0 * ts, 86.0 * ts), Vector2(132.0 * ts, 2.0)),
		Color(0.55, 0.44, 0.28), "RT_BarTop")
	for si in range(9):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(si * 14 + 6) * ts, 84.0 * ts), Vector2(9.0 * ts, 2.0 * ts)),
			Color(0.22, 0.22, 0.32), _uid("RT_Stool"))

	# Planters
	for px in [2, 66, 132]:
		_draw_plant(canvas, origin + Vector2(float(px) * ts, 55.0 * ts), _uid("RT_Plant"))

	_WB.decorate_terrace_zone(canvas, zr, TILE_SIZE)

# ─────────────────────────────────────────────────────────────
#  Recreation Strip  (480×30 tiles @ 0,310)
# ─────────────────────────────────────────────────────────────
func _draw_recreation_strip(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var origin := Vector2(ZONE_RECTS["recreation_strip"].position) * ts

	_label(canvas, origin + Vector2(4.0, 2.0), "RECREATION", Color(0.85, 0.55, 0.85, 0.70), 9)

	# Arcade machines
	var ac_c: Array = [Color(0.80, 0.15, 0.15), Color(0.15, 0.50, 0.82), Color(0.15, 0.72, 0.25), Color(0.82, 0.65, 0.10), Color(0.75, 0.15, 0.82)]
	for ai in range(8):
		var ax := origin.x + float(ai * 50 + 5) * ts
		var ay := origin.y + 2.0 * ts
		var ac: Color = ac_c[ai % ac_c.size()]
		_draw_rect(canvas, Rect2(Vector2(ax, ay), Vector2(12.0 * ts, 18.0 * ts)), ac.darkened(0.35), _uid("Arcade"))
		_draw_rect(canvas, Rect2(Vector2(ax + ts, ay + ts), Vector2(10.0 * ts, 10.0 * ts)), ac.darkened(0.10), _uid("ArcScrBg"))
		_draw_rect(canvas, Rect2(Vector2(ax + ts * 2.0, ay + 2.0 * ts), Vector2(8.0 * ts, 7.0 * ts)),
			Color(0.10, 0.25, 0.45, 0.80), _uid("ArcDisplay"))

	# Ping pong
	_draw_rect(canvas, Rect2(origin + Vector2(420.0 * ts, 2.0 * ts), Vector2(50.0 * ts, 24.0 * ts)),
		Color(0.12, 0.52, 0.20), "PingPong")
	_draw_border(canvas, Rect2(origin + Vector2(420.0 * ts, 2.0 * ts), Vector2(50.0 * ts, 24.0 * ts)),
		Color(0.55, 0.40, 0.15), "PingPong_Rail", 3.0)
	_draw_rect(canvas, Rect2(origin + Vector2(444.5 * ts, 2.0 * ts), Vector2(ts, 24.0 * ts)),
		Color(0.90, 0.90, 0.90), "PingPong_Net")

	# Billiard table
	_draw_rect(canvas, Rect2(origin + Vector2(350.0 * ts, 3.0 * ts), Vector2(55.0 * ts, 22.0 * ts)),
		Color(0.10, 0.48, 0.14), "PoolTable")
	_draw_border(canvas, Rect2(origin + Vector2(350.0 * ts, 3.0 * ts), Vector2(55.0 * ts, 22.0 * ts)),
		Color(0.48, 0.34, 0.18), "PoolTable_Rail", 3.0)

	# Bean bags
	var bb_c: Array = [Color(0.82, 0.25, 0.25), Color(0.25, 0.62, 0.82), Color(0.82, 0.72, 0.10), Color(0.25, 0.82, 0.35), Color(0.82, 0.30, 0.72)]
	for bi in range(5):
		var bx := origin.x + float(bi * 50 + 10) * ts
		_draw_rect(canvas, Rect2(Vector2(bx, origin.y + 16.0 * ts), Vector2(16.0 * ts, 12.0 * ts)),
			bb_c[bi % bb_c.size()], _uid("Rec_BB"))
		_draw_rect(canvas, Rect2(Vector2(bx + 3.0 * ts, origin.y + 17.0 * ts), Vector2(10.0 * ts, 8.0 * ts)),
			bb_c[bi % bb_c.size()].lightened(0.15), _uid("Rec_BBTop"))

# ─────────────────────────────────────────────────────────────
#  Parking
# ─────────────────────────────────────────────────────────────
func _draw_parking(canvas: Node2D) -> void:
	var ts     := float(TILE_SIZE)
	var zr: Rect2i = ZONE_RECTS["parking"]
	var origin := Vector2(zr.position) * ts
	var size   := Vector2(zr.size) * ts

	_draw_rect(canvas, Rect2(origin, size), Color(0.08, 0.08, 0.10), "Parking_Floor")
	for li in range(0, 44, 8):
		_draw_rect(canvas,
			Rect2(origin + Vector2(0.0, float(li) * ts), Vector2(size.x, ts)),
			Color(0.14, 0.14, 0.18), _uid("ParkLane"))
	for col in range(47):
		_draw_rect(canvas,
			Rect2(origin + Vector2(float(col) * 10.0 * ts, 0.0), Vector2(ts * 0.5, size.y)),
			Color(0.35, 0.35, 0.40, 0.50), _uid("ParkLine"))
	var car_c := Color(0.25, 0.30, 0.40)
	for ci in range(20):
		var col_idx: int = ci * 2 + 1
		var row_idx: int = 1 + (ci % 4) * 10
		if col_idx < 46:
			var cp := origin + Vector2(float(col_idx) * 10.0 * ts + ts, float(row_idx) * ts)
			_draw_rect(canvas, Rect2(cp, Vector2(8.0 * ts, 5.0 * ts)), car_c, _uid("Car"))
			_draw_rect(canvas, Rect2(cp + Vector2(ts, -2.0 * ts), Vector2(6.0 * ts, 3.0 * ts)), car_c.lightened(0.15), _uid("CarRoof"))
	_label(canvas, origin + Vector2(4.0, 4.0), "CAMPUS PARKING", Color(0.60, 0.60, 0.65, 0.60), 14)

# ─────────────────────────────────────────────────────────────
#  Meeting room helper (reusable)
# ─────────────────────────────────────────────────────────────
func _draw_meeting_room(canvas: Node2D, room_rect_tiles: Rect2i, capacity: int, room_name: String) -> void:
	var ts  := float(TILE_SIZE)
	var rp  := Vector2(room_rect_tiles.position) * ts
	var rs  := Vector2(room_rect_tiles.size) * ts
	var wc  := Color(0.20, 0.20, 0.30)

	var door_x_tiles := room_rect_tiles.position.x + int(room_rect_tiles.size.x / 2.0) - 1
	var dps := float(door_x_tiles) * ts
	var dpe := dps + 2.0 * ts

	_draw_rect(canvas, Rect2(rp, Vector2(dps - rp.x, ts)), wc, _uid("MWallTL"))
	_draw_rect(canvas, Rect2(Vector2(dpe, rp.y), Vector2(rp.x + rs.x - dpe, ts)), wc, _uid("MWallTR"))
	_draw_rect(canvas, Rect2(rp + Vector2(0.0, rs.y - ts), Vector2(rs.x, ts)), wc, _uid("MWallB"))
	_draw_rect(canvas, Rect2(rp + Vector2(0.0, ts), Vector2(ts, rs.y - 2.0 * ts)), wc, _uid("MWallL"))
	_draw_rect(canvas, Rect2(rp + Vector2(rs.x - ts, ts), Vector2(ts, rs.y - 2.0 * ts)), wc, _uid("MWallR"))
	_draw_rect(canvas, Rect2(Vector2(dps, rp.y), Vector2(2.0 * ts, ts)), Color(0.22, 0.20, 0.32), _uid("MDoor"))
	_draw_rect(canvas, Rect2(Vector2(dps - 1.0, rp.y), Vector2(2.0, ts)), Color(0.55, 0.55, 0.70, 0.65), _uid("MDoorFL"))
	_draw_rect(canvas, Rect2(Vector2(dpe - 1.0, rp.y), Vector2(2.0, ts)), Color(0.55, 0.55, 0.70, 0.65), _uid("MDoorFR"))

	var wbw := rs.x * 0.50
	var wb_rect := Rect2(rp + Vector2((rs.x - wbw) * 0.5, ts + 2.0), Vector2(wbw, 16.0))
	_draw_rect(canvas, wb_rect, Color(0.92, 0.94, 0.96), _uid("WB"))
	_draw_border(canvas, wb_rect, Color(0.50, 0.50, 0.58), _uid("WBFrame"), 1.5)

	var table_size := Vector2(rs.x * (0.65 if capacity <= 8 else 0.72), rs.y * (0.35 if capacity <= 8 else 0.40))
	var table_pos  := rp + Vector2((rs.x - table_size.x) * 0.5, ts * 3.0)
	_draw_rect(canvas, Rect2(table_pos, table_size), Color(0.35, 0.28, 0.18), _uid("MTable"))
	_draw_border(canvas, Rect2(table_pos, table_size), Color(0.55, 0.44, 0.28), _uid("MTableB"), 2.0)

	var chair_c := Color(0.18, 0.18, 0.26)
	@warning_ignore("integer_division")
	var cps: int = capacity / 2
	var spacing := table_size.x / float(cps + 1)
	for ci in range(cps):
		var cx := table_pos.x + spacing * float(ci + 1) - 6.0
		_draw_rect(canvas, Rect2(Vector2(cx, table_pos.y - 14.0), Vector2(12.0, 11.0)), chair_c, _uid("MC_T"))
		_draw_rect(canvas, Rect2(Vector2(cx, table_pos.y + table_size.y + 3.0), Vector2(12.0, 11.0)), chair_c, _uid("MC_B"))
	_draw_rect(canvas, Rect2(Vector2(table_pos.x - 13.0, table_pos.y + table_size.y * 0.5 - 6.0), Vector2(11.0, 12.0)), chair_c, _uid("MC_L"))
	_draw_rect(canvas, Rect2(Vector2(table_pos.x + table_size.x + 2.0, table_pos.y + table_size.y * 0.5 - 6.0), Vector2(11.0, 12.0)), chair_c, _uid("MC_R"))

	_WB.decorate_conference_zone(canvas, room_rect_tiles, TILE_SIZE, room_name.replace(" ", "_"))
	_label(canvas, rp + Vector2(ts + 4.0, ts + 2.0), room_name.to_upper(), Color(0.90, 0.90, 1.0, 0.75), 9)
	_label(canvas, rp + Vector2(ts + 4.0, ts + 13.0), "%d pax" % capacity, Color(0.65, 0.65, 0.80, 0.55), 7)

# ─────────────────────────────────────────────────────────────
#  Player spawn
# ─────────────────────────────────────────────────────────────
func _spawn_player() -> void:
	var spawn_pos := _tile_to_world(PLAYER_SPAWN_TILE)
	player_node = CharacterBody2D.new()
	player_node.name = "Player"
	player_node.set_script(load("res://scripts/player/Player.gd"))
	player_node.position = spawn_pos
	add_child(player_node)

	var cam := Camera2D.new()
	cam.name = "PlayerCamera"
	cam.zoom = Vector2(2.5, 2.5)
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = OFFICE_W * TILE_SIZE
	cam.limit_bottom = OFFICE_H * TILE_SIZE
	var cam_script_path := "res://scripts/world/CameraController.gd"
	if ResourceLoader.exists(cam_script_path):
		cam.set_script(load(cam_script_path))
	player_node.add_child(cam)

# ─────────────────────────────────────────────────────────────
#  Employee spawning — 300 employees across 3 work zones
#  Zone 1 Creative Lab:   3 clusters × 5×4 = 60 desks
#  Zone 2 Engineering:    6 rows × 15    = 90 desks
#  Zone 3 Open Pods:      5 pods × 15×2  = 150 desks
#  Total: 300
# ─────────────────────────────────────────────────────────────
func _spawn_employees() -> void:
	var employee_script = null
	var emp_script_path := "res://scripts/npc/Employee.gd"
	if ResourceLoader.exists(emp_script_path):
		employee_script = load(emp_script_path)

	var all_desks: Array = []

	# Creative Lab — 60 desks
	for cluster_idx in range(3):
		var cx_tile: int = CL_CLUSTER_X0[cluster_idx]
		for row in range(CL_ROWS):
			for col in range(CL_COLS):
				all_desks.append(Vector2(cx_tile + col * CL_CELL_W, CL_CLUSTER_Y0 + row * CL_CELL_H))

	# Engineering Hub — 90 desks
	for row in range(6):
		for col in range(EH_COLS):
			all_desks.append(Vector2(EH_DESK_X0 + col * EH_CELL_W, EH_ROW0 + row * EH_CELL_H))

	# Open Work Pods — 150 desks
	for pod_idx in range(WP_POD_TOPS.size()):
		var pod_top: int = WP_POD_TOPS[pod_idx]
		for s in range(WP_DESKS_HALF):
			all_desks.append(Vector2(WP_DESK_X0 + s * WP_CELL_W, pod_top))
		for s in range(WP_DESKS_HALF):
			all_desks.append(Vector2(WP_DESK_X0 + s * WP_CELL_W, pod_top + WP_BOT_OFFSET))

	var desk_idx: int = 0
	for emp_id in GameManager.employees:
		if emp_id == "player":
			continue
		var world_pos: Vector2
		if desk_idx < all_desks.size():
			world_pos = _tile_to_world(all_desks[desk_idx])
			desk_idx += 1
		else:
			world_pos = _tile_to_world(Vector2(5.0 + float(desk_idx % 40) * 5.0, 315.0))
		var npc := _create_npc(emp_id, employee_script)
		npc.position = world_pos
		employee_container.add_child(npc)

func _create_npc(emp_id: String, emp_script) -> CharacterBody2D:
	var npc := CharacterBody2D.new()
	npc.name = emp_id
	if emp_script != null:
		npc.set_script(emp_script)
		npc.set("employee_id", emp_id)
	return npc
