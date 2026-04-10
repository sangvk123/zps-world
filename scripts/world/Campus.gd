## Campus.gd
## PNG-based campus — ZPS_Layout_Campus.png as the world background.
## Zones are defined in pixel space matching the PNG visual layout.
## Employees spawn inside their zone and wander within it.

extends Node2D

const MAP_IMG_PATH := "res://assets/maps/ZPS_Layout_Campus.png"

# PNG dimensions (pixels)
const MAP_W: float = 1193.0
const MAP_H: float = 896.0

# Player spawn: Main Office area
const SPAWN_POS := Vector2(220.0, 620.0)

# Zone pixel-space rectangles — match the visual layout of ZPS_Layout_Campus.png
# Each entry: {rect, count (employees), label}
# 10 zones, counts total 250 employees.
var _zones: Dictionary = {
	# ── Left section ──────────────────────────────────────────────────────────
	"engineering": {
		"rect":  Rect2(15,  340, 460, 535),
		"count": 30,
		"label": "Engineering Floor",
	},
	"design_studio": {
		"rect":  Rect2(15,  20,  435, 315),
		"count": 16,
		"label": "Design & Product Studio",
	},
	# ── Centre section ────────────────────────────────────────────────────────
	"amenity": {
		"rect":  Rect2(460, 20,  300, 190),
		"count": 10,
		"label": "Amenity Center",
	},
	"library": {
		"rect":  Rect2(460, 215, 295, 145),
		"count": 5,
		"label": "Library & Research",
	},
	"collab_hub": {
		"rect":  Rect2(460, 370, 300, 505),
		"count": 11,
		"label": "Collaboration Hub",
	},
	# ── Right section ─────────────────────────────────────────────────────────
	"facilities": {
		"rect":  Rect2(760, 15,  420, 190),
		"count": 6,
		"label": "Facilities & Logistics",
	},
	"data_lab": {
		"rect":  Rect2(760, 210, 420, 205),
		"count": 7,
		"label": "Data Lab",
	},
	"reception": {
		"rect":  Rect2(760, 420, 280, 250),
		"count": 8,
		"label": "Reception & Innovation",
	},
	"innovation_corner": {
		"rect":  Rect2(1045, 420, 135, 250),
		"count": 2,
		"label": "Innovation Corner",
	},
	"marketing_hub": {
		"rect":  Rect2(760, 675, 420, 200),
		"count": 5,
		"label": "Marketing Hub",
	},
}

var player_node: CharacterBody2D = null
var _hitbox_rects: Array[Rect2] = []   # populated by _build_hitboxes(), used by spawn

@onready var hud_layer: CanvasLayer = $HUDLayer


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.10, 0.06))
	print("[Campus] _ready() — is_logged_in: %s" % PlayerData.is_logged_in)
	# Workaround: Godot 4.6 web render loop may stop after first frame when the
	# browser viewport exactly matches the project size (no resize event fires).
	# Force a resize event after 50ms to restart the loop in that edge case.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("setTimeout(function(){window.dispatchEvent(new Event('resize'))},50)")
	if PlayerData.is_logged_in:
		_after_login()
	else:
		# HUD will show LoginDialog — wait for login_complete then load world
		PlayerData.login_complete.connect(_after_login, CONNECT_ONE_SHOT)


func _after_login() -> void:
	# Start the world immediately — no waiting for the employees API.
	# This prevents black screen when Railway.app is cold-starting (slow first response).
	_start_world()
	# Fetch real employee data async; updates GameManager.employees when ready.
	HttpManager.response_received.connect(_on_employees_loaded, CONNECT_ONE_SHOT)
	HttpManager.error.connect(_on_employees_load_error, CONNECT_ONE_SHOT)
	HttpManager.get_request("employees")


func _on_employees_loaded(endpoint: String, data: Variant) -> void:
	if endpoint != "employees":
		return
	if data is Array:
		# Replace mock employees with real data from the server
		GameManager.employees = {}
		for emp in data:
			if emp is Dictionary and emp.has("id"):
				GameManager.employees[emp["id"]] = emp
		# Re-add the local player entry so HUD roster shows them
		GameManager.employees[PlayerData.player_id] = {
			"id": PlayerData.player_id,
			"name": PlayerData.display_name,
			"department": PlayerData.department,
			"title": PlayerData.hr_title,
			"is_online": true,
			"avatar": PlayerData.avatar_config,
			"current_task": "Exploring ZPS World",
		}
	# World is already running — no second _start_world() needed


func _on_employees_load_error(_endpoint: String, _message: String) -> void:
	push_warning("[Campus] Failed to load employees from REST — using mock data")
	# World is already running — no action needed


func _start_world() -> void:
	_build_background()
	_build_border_collision()
	_build_hitboxes()
	_build_navigation()
	_spawn_player()
	_spawn_employees()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_player"):
		hud.register_player(player_node)

	NetworkManager.roster_received.connect(_on_roster_received)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.positions_updated.connect(_on_positions_updated)

	print("[Campus] ZPS Campus loaded — PNG map %.0f×%.0f px, %d zones, %d employees" % [
		MAP_W, MAP_H, _zones.size(), GameManager.employees.size()
	])


# ── Background: PNG as a single Sprite2D ─────────────────────────────────────
func _build_background() -> void:
	var bg := Sprite2D.new()
	bg.name = "CampusBackground"
	bg.centered = false
	bg.z_index = -10
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = _load_texture(MAP_IMG_PATH)
	if tex:
		bg.texture = tex
	else:
		push_error("[Campus] Map image not found: %s" % MAP_IMG_PATH)
	add_child(bg)


static func _load_texture(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var r = ResourceLoader.load(res_path)
		if r is Texture2D:
			return r as Texture2D
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


# ── Border collision: keep player/NPCs inside map bounds ─────────────────────
func _build_border_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "BorderCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	_add_wall(body, Vector2(-16.0, -16.0), Vector2(MAP_W + 32.0, 16.0))   # top
	_add_wall(body, Vector2(-16.0, MAP_H),  Vector2(MAP_W + 32.0, 16.0))  # bottom
	_add_wall(body, Vector2(-16.0, 0.0),    Vector2(16.0, MAP_H))          # left
	_add_wall(body, Vector2(MAP_W, 0.0),    Vector2(16.0, MAP_H))          # right
	add_child(body)


# ── Hitboxes from campus_hitboxes.json (drawn in hitbox editor) ──────────────
const HITBOX_JSON_PATH := "res://assets/maps/campus_hitboxes.json"

func _build_hitboxes() -> void:
	# Load JSON
	var text: String = ""
	if ResourceLoader.exists(HITBOX_JSON_PATH):
		var f := FileAccess.open(ProjectSettings.globalize_path(HITBOX_JSON_PATH), FileAccess.READ)
		if f: text = f.get_as_text()
	if text.is_empty():
		var abs_path := ProjectSettings.globalize_path(HITBOX_JSON_PATH)
		if FileAccess.file_exists(abs_path):
			var f := FileAccess.open(abs_path, FileAccess.READ)
			if f: text = f.get_as_text()
	if text.is_empty():
		push_warning("[Campus] campus_hitboxes.json not found — skipping hitboxes")
		return

	var parsed = JSON.parse_string(text)
	if not parsed is Array:
		push_warning("[Campus] campus_hitboxes.json invalid format")
		return

	var body := StaticBody2D.new()
	body.name = "HitboxLayer"
	body.collision_layer = 1
	body.collision_mask = 0
	var count := 0
	for entry: Variant in parsed:
		if not entry is Dictionary: continue
		var x: float = float(entry.get("x", 0))
		var y: float = float(entry.get("y", 0))
		var w: float = float(entry.get("w", 0))
		var h: float = float(entry.get("h", 0))
		if w <= 0.0 or h <= 0.0: continue
		_add_wall(body, Vector2(x, y), Vector2(w, h))
		_hitbox_rects.append(Rect2(x, y, w, h))   # store for spawn rejection
		count += 1
	add_child(body)
	print("[Campus] Loaded %d hitboxes from campus_hitboxes.json" % count)


# ── Navigation mesh: walkable area minus hitbox obstacles ────────────────────
func _build_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 8.0
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = 1   # layer 1 = walls
	nav_poly.source_geometry_mode  = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	# Source geometry: walkable boundary + auto-parsed static-body obstacles
	var source_geo := NavigationMeshSourceGeometryData2D.new()
	source_geo.add_traversable_outline(PackedVector2Array([
		Vector2(20.0,        20.0),
		Vector2(MAP_W - 20.0, 20.0),
		Vector2(MAP_W - 20.0, MAP_H - 20.0),
		Vector2(20.0,        MAP_H - 20.0),
	]))

	# Scan this node's children (BorderCollision + HitboxLayer StaticBody2Ds)
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geo, self)
	# Bake synchronously on the main thread
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geo)

	var nav_region := NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
	print("[Campus] Nav mesh baked — %d obstruction outlines parsed" \
			% source_geo.get_obstruction_outlines().size())


static func _add_wall(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = pos + size * 0.5
	body.add_child(col)


# ── Player ────────────────────────────────────────────────────────────────────
func _spawn_player() -> void:
	player_node = CharacterBody2D.new()
	player_node.name = "Player"
	player_node.set_script(load("res://scripts/player/Player.gd"))
	player_node.position = SPAWN_POS
	add_child(player_node)

	var cam := Camera2D.new()
	cam.name = "PlayerCamera"
	# With stretch_mode=canvas_items + aspect=expand, the Godot viewport height can be much
	# larger than MAP_H on portrait mobile (e.g. iPhone 375×812 → vp 1280×2771).
	# At zoom=2.0 the camera window would be 2771/2=1385 world units tall — larger than MAP_H(896)
	# → camera limits invert → entire world off-screen → black canvas.
	# Fix: ensure zoom >= godot_vp_h / MAP_H so the camera window always fits within the map.
	var vp_size := get_viewport().get_visible_rect().size
	var min_zoom_h: float = vp_size.y / MAP_H   # height constraint
	var min_zoom_w: float = vp_size.x / MAP_W   # width  constraint (usually fine)
	var initial_zoom: float = maxf(maxf(min_zoom_h, min_zoom_w) * 1.15, 3.0)
	print("[Campus] zoom=%s (vp=%s map=%s×%s)" % [initial_zoom, vp_size, MAP_W, MAP_H])
	cam.zoom = Vector2(initial_zoom, initial_zoom)
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = int(MAP_W)
	cam.limit_bottom = int(MAP_H)
	var cam_script := "res://scripts/world/CameraController.gd"
	if ResourceLoader.exists(cam_script):
		cam.set_script(load(cam_script))
	player_node.add_child(cam)


# ── Employees: spawned per zone with zone-constrained wandering ───────────────
# 5 % of all spawned NPCs are flagged as "special" (gold nameplate + title).
const SPECIAL_NPC_CHANCE := 0.05

func _spawn_employees() -> void:
	var emp_layer := Node2D.new()
	emp_layer.name = "EmployeeLayer"
	add_child(emp_layer)

	var emp_script: Script = load("res://scripts/npc/Employee.gd")
	var emp_index: int = 1

	for zone_id: String in _zones:
		var zdata: Dictionary = _zones[zone_id]
		var zone_rect: Rect2 = zdata["rect"]
		var count: int        = zdata["count"]

		for _i: int in range(count):
			if emp_index > 100:
				return
			var emp := CharacterBody2D.new()
			emp.set_script(emp_script)
			emp.employee_id = "emp_%03d" % emp_index
			emp.zone_rect   = zone_rect
			emp.is_special  = randf() < SPECIAL_NPC_CHANCE
			emp.position    = _pick_free_spawn(zone_rect)
			emp_layer.add_child(emp)
			emp_index += 1

# Returns a spawn position inside zone_rect that doesn't overlap any hitbox rect.
# Uses rejection sampling (up to 20 tries). Falls back to zone centre on failure.
func _pick_free_spawn(zone_rect: Rect2) -> Vector2:
	const MARGIN    := 10.0
	const MAX_TRIES := 20
	var inner := zone_rect.grow(-MARGIN)
	if not inner.has_area():
		return zone_rect.get_center()
	for _t: int in MAX_TRIES:
		var candidate := Vector2(
			randf_range(inner.position.x, inner.end.x),
			randf_range(inner.position.y, inner.end.y)
		)
		var blocked := false
		for hr: Rect2 in _hitbox_rects:
			if hr.has_point(candidate):
				blocked = true
				break
		if not blocked:
			return candidate
	# Fallback: zone centre (may still be on a hitbox in very dense zones)
	return zone_rect.get_center()


# ── Zone query (used by HUD zone indicator) ───────────────────────────────────
func get_room_at_position(world_pos: Vector2) -> String:
	for zone_id: String in _zones:
		if (_zones[zone_id]["rect"] as Rect2).has_point(world_pos):
			return zone_id
	return ""


# ── Remote player management ─────────────────────────────────────────────────
func _on_roster_received(players: Array) -> void:
	for p in players:
		_spawn_remote_player(p["id"], p["x"], p["y"], p.get("avatar", {}))

func _on_player_joined(id: String, x: float, y: float, avatar: Dictionary) -> void:
	_spawn_remote_player(id, x, y, avatar)

func _on_player_left(id: String) -> void:
	var rp = GameManager.remote_players.get(id)
	if rp:
		rp.enter_npc_mode()

func _on_positions_updated(data: Array) -> void:
	for entry in data:
		var rp = GameManager.remote_players.get(entry["id"])
		if rp:
			rp.set_target_position(entry["x"], entry["y"])

func _spawn_remote_player(id: String, x: float, y: float, avatar: Dictionary) -> void:
	if GameManager.remote_players.has(id):
		return
	var RemotePlayerScript = load("res://scripts/world/RemotePlayer.gd")
	var rp = CharacterBody2D.new()
	rp.set_script(RemotePlayerScript)
	rp.player_id = id
	rp.global_position = Vector2(x, y)
	add_child(rp)
	rp.set_name_and_avatar(id, avatar)
	GameManager.remote_players[id] = rp
	GameManager.remote_player_joined.emit(id)


# ── Desk proximity (Sprint 4) ─────────────────────────────────────────────────

const _DESK_ZONE_MARGIN: float = 60.0
var _near_own_desk: bool = false
var _desk_editor_open: bool = false

func _process(_delta: float) -> void:
	if player_node == null:
		return
	_update_desk_proximity()
	if Input.is_action_just_pressed("ui_desk_editor") and _near_own_desk:
		_toggle_desk_editor()

func _update_desk_proximity() -> void:
	var dept: String = PlayerData.department.to_lower()
	var zone_key: String = _dept_to_zone_key(dept)
	if not _zones.has(zone_key):
		_near_own_desk = false
		return
	var zone_rect: Rect2 = _zones[zone_key]["rect"]
	var desk_center := zone_rect.get_center()
	var dist := player_node.global_position.distance_to(desk_center)
	_near_own_desk = dist < _DESK_ZONE_MARGIN
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_zone_hint"):
		hud.set_zone_hint("near_own_desk" if _near_own_desk else "")

func _dept_to_zone_key(dept: String) -> String:
	match dept:
		"engineering": return "engineering"
		"design":      return "design_studio"
		"product":     return "collab_hub"
		"hr":          return "reception"
		"data":        return "data_lab"
		"marketing":   return "marketing_hub"
		_:             return "engineering"

func _toggle_desk_editor() -> void:
	if _desk_editor_open:
		var existing := get_tree().get_first_node_in_group("desk_editor")
		if existing:
			existing.queue_free()
		_desk_editor_open = false
		return
	var editor := load("res://scripts/ui/DeskEditor.gd").new() as DeskEditor
	editor.add_to_group("desk_editor")
	var hud_layer := get_node_or_null("HUDLayer")
	if hud_layer:
		hud_layer.add_child(editor)
	else:
		add_child(editor)
	editor.closed.connect(func():
		_desk_editor_open = false
	)
	_desk_editor_open = true
