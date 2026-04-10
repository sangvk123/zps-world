## Employee.gd
## NPC representing a ZPS team member — fully self-contained (builds own nodes).
## No scene file required. Works when instantiated programmatically from Office.gd.
## Left-click on an NPC to interact directly.

class_name Employee
extends CharacterBody2D

const _AR = preload("res://scripts/world/AvatarRenderer.gd")


# ── Config (set before adding to scene tree) ──
@export var employee_id: String = "emp_001"
@export var wander_speed: float = 40.0

# Zone boundary — set by Campus spawner to constrain wandering (Rect2 in world pixels).
# If empty (default), wandering is unconstrained.
var zone_rect: Rect2 = Rect2()

# ── Owned visual nodes ──
var _nameplate:     Label            = null
var _title_label:   Label            = null   # visible only for special NPCs
var _interact_hint: Label            = null
var _status_dot:    ColorRect        = null
var _anim_sprite:   AnimatedSprite2D = null
var _nav_agent:     NavigationAgent2D = null

# ── State ──
var employee_data: Dictionary = {}
var is_online:         bool = false
var is_being_talked_to: bool = false
# Set by Campus spawner BEFORE add_child — drives gold nameplate + title display.
var is_special: bool = false

# ── Facing state (persists through idle) ──
var _facing:      String = "south"
var _facing_flip: bool   = false

# ── GDScript state machine (replaces LimboAI behavior tree) ──
const _SM_DETECT_RANGE    := 60.0
const _SM_CROSS_ZONE      := 0.10
const _SM_MAP_MIN         := Vector2(20.0, 20.0)
const _SM_MAP_MAX         := Vector2(1173.0, 876.0)

var _sm_state:           String  = "idle"
var _sm_timer:           float   = 0.0
var _sm_target:          Vector2 = Vector2.ZERO
var _sm_partner:         Node2D  = null
var _sm_sit_dur:         float   = 0.0
var _sm_chat_dur:        float   = 0.0
var _sm_look_total:      float   = 0.0
var _sm_look_turn:       float   = 0.0
var _sm_walk_timer:      float   = 0.0
var _sm_stuck_timer:     float   = 0.0
var _sm_stuck_last_dist: float   = INF


# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("employees")
	collision_layer = 4   # NPC layer — detected by player interaction area
	collision_mask  = 5   # Collides with layer 1 (world) + layer 3 (other NPCs)
	_build_visuals()
	_load_employee_data()
	_sm_start()
	if AIAgent.has_signal("response_ready"):
		AIAgent.response_ready.connect(_on_ai_response)
	# Register dot on minimap
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("minimap_add_npc_dot"):
		hud.minimap_add_npc_dot(employee_id, is_online)

func _exit_tree() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("minimap_remove_npc_dot"):
		hud.minimap_remove_npc_dot(employee_id)

# ─────────────────────────────────────────────
# Build visual nodes (no .tscn required)
# ─────────────────────────────────────────────
func _build_visuals() -> void:
	# ── Character body: sprite or ColorRect fallback ──
	var emp: Dictionary = GameManager.get_employee(employee_id)
	var dept: String = emp.get("department", "").to_lower()

	# Try directional animated sprite first, fall back to static Sprite2D, then ColorRect
	_anim_sprite = _AR.make_anim_sprite_for_npc(emp)
	if _anim_sprite:
		add_child(_anim_sprite)
	else:
		var sprite: Sprite2D = _AR.make_sprite_for_npc(emp)
		if sprite == null:
			sprite = _AR.make_sit_sprite(dept)
		if sprite:
			add_child(sprite)
		else:
			var dept_colors: Dictionary = {
				"engineering": Color(0.35, 0.65, 0.90),
				"design":      Color(0.85, 0.45, 0.80),
				"product":     Color(0.40, 0.80, 0.50),
				"hr":          Color(0.90, 0.60, 0.40),
				"data":        Color(0.40, 0.75, 0.90),
				"marketing":   Color(0.90, 0.80, 0.30),
			}
			var c: Color = dept_colors.get(dept, Color(0.65, 0.55, 0.75))
			var body := ColorRect.new()
			body.size = Vector2(12.0, 16.0); body.position = Vector2(-6.0, -16.0); body.color = c
			add_child(body)
			var head := ColorRect.new()
			head.size = Vector2(10.0, 10.0); head.position = Vector2(-5.0, -26.0); head.color = c.lightened(0.25)
			add_child(head)

	# ── Status dot ──
	_status_dot = ColorRect.new()
	_status_dot.name = "StatusDot"
	_status_dot.size = Vector2(5.0, 5.0)
	_status_dot.position = Vector2(7.0, -28.0)
	_status_dot.color = Color(0.45, 0.45, 0.45)   # updated in _load_employee_data
	add_child(_status_dot)

	# ── Nameplate ──
	_nameplate = Label.new()
	_nameplate.name = "Nameplate"
	_nameplate.add_theme_font_size_override("font_size", 11)
	_nameplate.position = Vector2(-28.0, -42.0)
	_nameplate.modulate = Color(0.9, 0.95, 1.0)
	add_child(_nameplate)

	# ── Title label (special NPCs only — hidden by default) ──
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 9)
	_title_label.position = Vector2(-28.0, -31.0)
	_title_label.modulate = Color(1.0, 0.85, 0.35, 0.85)
	_title_label.visible = false
	add_child(_title_label)

	# ── Interact hint ──
	_interact_hint = Label.new()
	_interact_hint.name = "InteractHint"
	_interact_hint.text = "[Click] Talk"
	_interact_hint.add_theme_font_size_override("font_size", 11)
	_interact_hint.position = Vector2(-24.0, -54.0)
	_interact_hint.modulate = Color(1.0, 0.9, 0.4)
	_interact_hint.visible = false
	add_child(_interact_hint)

	# ── Physics collision shape (prevents NPC overlap) ──
	var phys_col := CollisionShape2D.new()
	var phys_shape := CapsuleShape2D.new()
	phys_shape.radius = 6.0
	phys_shape.height = 14.0
	phys_col.shape = phys_shape
	phys_col.position = Vector2(0.0, -10.0)
	add_child(phys_col)

	# ── Click detection area ──
	var click_area := Area2D.new()
	click_area.name = "ClickArea"
	click_area.input_pickable = true
	click_area.collision_layer = 0
	click_area.collision_mask = 0
	var click_col := CollisionShape2D.new()
	var click_shape := CircleShape2D.new()
	click_shape.radius = 10.0
	click_col.shape = click_shape
	click_area.add_child(click_col)
	click_area.input_event.connect(_on_click_area_input)
	add_child(click_area)

	# ── Navigation agent ──
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.name = "NavAgent"
	_nav_agent.path_desired_distance = 4.0
	_nav_agent.target_desired_distance = 4.0
	_nav_agent.radius = 7.0
	# ORCA avoidance — ngăn NPC xếp chồng lên nhau
	_nav_agent.avoidance_enabled  = true
	_nav_agent.neighbor_distance  = 30.0
	_nav_agent.max_neighbors      = 8
	_nav_agent.time_horizon_agents = 0.5
	add_child(_nav_agent)

# ─────────────────────────────────────────────
func _load_employee_data() -> void:
	employee_data = GameManager.get_employee(employee_id)
	if employee_data.is_empty():
		push_warning("[Employee] Unknown ID: %s" % employee_id)
		return
	is_online = employee_data.get("is_online", false)
	if _nameplate:
		if is_special:
			_nameplate.text = employee_data.get("name", "?")
			_nameplate.modulate = Color(1.0, 0.88, 0.2)
			_nameplate.add_theme_font_size_override("font_size", 9)
		else:
			_nameplate.text = employee_data.get("name", "?")
	if _title_label and is_special:
		_title_label.text = employee_data.get("title", "")
		_title_label.visible = true
	if _status_dot:
		_status_dot.color = Color(0.20, 0.85, 0.35) if is_online else Color(0.45, 0.45, 0.45)

# ─────────────────────────────────────────────
# NPC facing / animation
# ─────────────────────────────────────────────
func update_npc_facing(vel: Vector2) -> void:
	if _anim_sprite == null:
		return
	var moving: bool = vel.length() > 1.0
	var prefix: String = "run" if moving else "idle"
	var facing: String
	var flip: bool
	if moving:
		if abs(vel.x) > abs(vel.y):
			facing = "west"
			flip = vel.x > 0.0   # east = flip west frames
		elif vel.y < 0.0:
			facing = "north"
			flip = false
		else:
			facing = "south"
			flip = false
		_facing      = facing
		_facing_flip = flip
	else:
		# Idle: preserve last moving direction instead of always resetting to south
		facing = _facing
		flip   = _facing_flip
	_anim_sprite.flip_h = flip
	var anim_name: String = prefix + "_" + facing
	# Fallback nếu run animation không có (ví dụ sprite sheet thiếu) → dùng idle
	if not _anim_sprite.sprite_frames.has_animation(anim_name):
		anim_name = "idle_" + facing
	if _anim_sprite.animation != anim_name:
		_anim_sprite.play(anim_name)

# ─────────────────────────────────────────────
# Click area input — left-click on NPC triggers interaction
# ─────────────────────────────────────────────
func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var player = get_tree().get_first_node_in_group("player") as Player
		if player and not player.is_busy:
			on_player_interact(player)

# ─────────────────────────────────────────────
# Interaction interface (called by Player via E key or click)
# ─────────────────────────────────────────────
func on_player_interact(player: Player) -> void:
	is_being_talked_to = true
	player.set_busy(true)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_employee_interaction"):
		hud.show_employee_interaction(employee_data, self, player)

func show_interact_hint() -> void:
	if _interact_hint:
		_interact_hint.visible = true

func hide_interact_hint() -> void:
	if _interact_hint:
		_interact_hint.visible = false

func finish_interaction() -> void:
	is_being_talked_to = false

func start_sit() -> void:
	if _anim_sprite == null:
		return
	var anim := "sit_" + _facing
	if _anim_sprite.sprite_frames.has_animation(anim):
		_anim_sprite.play(anim)
	else:
		_anim_sprite.play("idle_" + _facing)

func stop_sit() -> void:
	if _anim_sprite == null:
		return
	_anim_sprite.play("idle_" + _facing)

# Change facing direction while keeping the IDLE animation (used by BTLookAround).
func face_direction(dir: Vector2) -> void:
	if _anim_sprite == null or dir.length() < 0.1:
		return
	if abs(dir.x) > abs(dir.y):
		_facing      = "west"
		_facing_flip = dir.x > 0.0
	elif dir.y < 0.0:
		_facing      = "north"
		_facing_flip = false
	else:
		_facing      = "south"
		_facing_flip = false
	_anim_sprite.flip_h = _facing_flip
	var anim_name := "idle_" + _facing
	if _anim_sprite.animation != anim_name:
		_anim_sprite.play(anim_name)

# ─────────────────────────────────────────────
# Navigation helper — used by all BT walk actions
# Returns true when arrived within arrive_dist.
# ─────────────────────────────────────────────
func nav_move_toward(target: Vector2, arrive_dist: float = 5.0) -> bool:
	if global_position.distance_to(target) <= arrive_dist:
		velocity = Vector2.ZERO
		return true

	# Direction of last resort — always valid so NPC never freezes
	var direct_dir := (target - global_position).normalized()

	if _nav_agent != null:
		if _nav_agent.target_position != target:
			_nav_agent.target_position = target

		if not _nav_agent.is_navigation_finished():
			# Nav path is active — try to follow it
			var next_pos := _nav_agent.get_next_path_position()
			var nav_dir  := next_pos - global_position
			# If the nav step is valid use it, otherwise fall through to direct move
			if nav_dir.length() >= 1.0:
				var intended_dir := nav_dir.normalized() * wander_speed
				velocity = intended_dir
				move_and_slide()
				# Dùng intended direction để facing — không bị ảnh hưởng bởi collision deflection
				update_npc_facing(intended_dir)
				return false

		# No path yet / path finished / zero-length nav step → move directly
		# Thêm lateral jitter để tránh nhiều NPC cùng đi vào 1 điểm trên tường
		var jitter_angle := (randf() - 0.5) * 0.8  # ±0.4 radian (~±23°)
		var jittered_dir := direct_dir.rotated(jitter_angle)
		var intended_dir := jittered_dir * wander_speed
		velocity = intended_dir
		move_and_slide()
		# Wall-hit detection: nếu velocity sau slide nhỏ hơn nhiều so với intended → đang bị cản
		# Thêm perpendicular push để NPC thoát khỏi tường
		if velocity.length() < wander_speed * 0.25:
			var perp := direct_dir.rotated(PI * 0.5 * sign(randf() - 0.5))
			velocity = perp * wander_speed * 0.7
			move_and_slide()
		update_npc_facing(intended_dir)
	else:
		var intended_dir := direct_dir * wander_speed
		velocity = intended_dir
		move_and_slide()
		update_npc_facing(intended_dir)
	return false

# ─────────────────────────────────────────────
# AI agent
# ─────────────────────────────────────────────
func ask_ai_agent(question: String) -> void:
	AIAgent.ask_employee_agent(employee_id, question)

func _on_ai_response(response: String, context_id: String) -> void:
	if not context_id.begins_with("emp_%s" % employee_id):
		return
	say(response, 5.0)

func say(message: String, _duration: float = 3.0) -> void:
	# Simple overhead label bubble (no scene file required)
	var bubble := Label.new()
	bubble.text = message
	bubble.add_theme_font_size_override("font_size", 9)
	bubble.position = Vector2(-30.0, -68.0)
	bubble.modulate = Color(1.0, 1.0, 0.8)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.custom_minimum_size = Vector2(80.0, 0.0)
	add_child(bubble)
	get_tree().create_timer(_duration).timeout.connect(
		func(): if is_instance_valid(bubble): bubble.queue_free()
	)

# ─────────────────────────────────────────────
# GDScript state machine (no LimboAI dependency)
# Replicates the original BTDynamicSelector behavior:
#   P1 (highest): Talking → stand still
#   P2:           Player nearby → face player
#   P3:           Random activity (chat / sit / look / wander)
# ─────────────────────────────────────────────
func _sm_start() -> void:
	_sm_state = "idle"
	_sm_timer = randf_range(0.5, 2.0)   # stagger startup across NPCs
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# P1: Talking — highest priority
	if is_being_talked_to:
		if _sm_state != "talking":
			_sm_cleanup()
			velocity = Vector2.ZERO
			update_npc_facing(Vector2.ZERO)
			_sm_state = "talking"
		return
	elif _sm_state == "talking":
		_sm_state = "idle"
		_sm_timer = randf_range(0.5, 1.5)

	# P2: Player nearby — face and show hint
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near := player != null and global_position.distance_to(player.global_position) <= _SM_DETECT_RANGE
	if near:
		if _sm_state != "face_player":
			_sm_cleanup()
			velocity = Vector2.ZERO
			show_interact_hint()
			_sm_state = "face_player"
		face_direction(player.global_position - global_position)
		velocity = Vector2.ZERO
		return
	elif _sm_state == "face_player":
		hide_interact_hint()
		_sm_state = "idle"
		_sm_timer = randf_range(0.5, 1.5)

	# P3: Activities
	match _sm_state:
		"idle":
			velocity = Vector2.ZERO
			update_npc_facing(Vector2.ZERO)
			_sm_timer -= delta
			if _sm_timer <= 0.0:
				_sm_pick_activity()

		"wander":
			_sm_walk_timer  += delta
			_sm_stuck_timer += delta
			if _sm_walk_timer >= 7.0:   # hard timeout
				velocity = Vector2.ZERO; update_npc_facing(Vector2.ZERO)
				_sm_state = "idle";     _sm_timer = randf_range(0.5, 1.5)
				return
			if _sm_stuck_timer >= 1.0:
				var d := global_position.distance_to(_sm_target)
				if _sm_stuck_last_dist == INF:
					_sm_stuck_last_dist = d
				elif _sm_stuck_last_dist - d < 6.0:
					velocity = Vector2.ZERO; update_npc_facing(Vector2.ZERO)
					_sm_state = "idle";     _sm_timer = randf_range(0.5, 1.5)
					return
				else:
					_sm_stuck_last_dist = d
				_sm_stuck_timer = 0.0
			if nav_move_toward(_sm_target):
				update_npc_facing(Vector2.ZERO)
				_sm_state = "idle"; _sm_timer = randf_range(0.5, 1.5)

		"look_around":
			velocity = Vector2.ZERO
			_sm_look_total -= delta
			if _sm_look_total <= 0.0:
				_sm_state = "idle"; _sm_timer = randf_range(0.5, 1.5); return
			_sm_look_turn -= delta
			if _sm_look_turn <= 0.0:
				_sm_look_turn = 0.9
				var angle := float(randi() % 8) * (TAU / 8.0)
				face_direction(Vector2(cos(angle), sin(angle)))

		"sit_walk":
			if nav_move_toward(_sm_target, 5.0):
				_sm_state = "sit_work"; _sm_timer = _sm_sit_dur; start_sit()

		"sit_work":
			_sm_timer -= delta
			if _sm_timer <= 0.0:
				stop_sit(); _sm_state = "idle"; _sm_timer = randf_range(0.5, 1.5)

		"chat_approach":
			if not is_instance_valid(_sm_partner):
				_sm_state = "idle"; _sm_timer = randf_range(0.5, 1.5); return
			_sm_walk_timer += delta
			if _sm_walk_timer > 8.0:
				_sm_state = "idle"; _sm_timer = randf_range(0.5, 1.5); return
			if nav_move_toward(_sm_partner.global_position, 14.0):
				update_npc_facing((_sm_partner.global_position - global_position).normalized())
				_sm_state = "chatting"; _sm_timer = _sm_chat_dur

		"chatting":
			if is_instance_valid(_sm_partner):
				velocity = Vector2.ZERO
				update_npc_facing((_sm_partner.global_position - global_position).normalized())
			_sm_timer -= delta
			if _sm_timer <= 0.0:
				_sm_partner = null; _sm_state = "idle"; _sm_timer = randf_range(0.5, 1.5)

func _sm_cleanup() -> void:
	if _sm_state in ["sit_walk", "sit_work"]: stop_sit()
	elif _sm_state == "face_player": hide_interact_hint()
	_sm_partner = null

func _sm_pick_activity() -> void:
	match randi() % 5:
		0: _sm_try_chat()
		1: _sm_start_sit()
		2:
			_sm_state = "look_around"
			_sm_look_total = randf_range(3.0, 6.0)
			_sm_look_turn  = 0.0
		_: _sm_start_wander()   # 2/5 weight

func _sm_try_chat() -> void:
	var nearest: Node2D = null
	var nearest_dist := 80.0
	for body: Node in get_tree().get_nodes_in_group("employees"):
		if body == self: continue
		var other := body as Employee
		if other == null or other.is_being_talked_to: continue
		var d := global_position.distance_to(other.global_position)
		if d < nearest_dist: nearest_dist = d; nearest = other
	if nearest == null: _sm_start_wander(); return
	_sm_partner    = nearest
	_sm_chat_dur   = randf_range(4.0, 10.0)
	_sm_walk_timer = 0.0
	_sm_state      = "chat_approach"

func _sm_start_sit() -> void:
	_sm_sit_dur = randf_range(15.0, 40.0)
	var m := 20.0
	_sm_target = zone_rect.get_center() if not zone_rect.has_area() else \
		Vector2(randf_range(zone_rect.position.x + m, zone_rect.end.x - m),
				randf_range(zone_rect.position.y + m, zone_rect.end.y - m))
	_sm_state = "sit_walk"

func _sm_start_wander() -> void:
	if zone_rect.has_area() and randf() < _SM_CROSS_ZONE:
		var wide := zone_rect.grow(100.0)
		wide.position = wide.position.clamp(_SM_MAP_MIN, _SM_MAP_MAX)
		wide = wide.intersection(Rect2(_SM_MAP_MIN, _SM_MAP_MAX - _SM_MAP_MIN))
		if wide.has_area():
			_sm_target = Vector2(randf_range(wide.position.x, wide.end.x),
								 randf_range(wide.position.y, wide.end.y))
			_sm_walk_timer = 0.0; _sm_stuck_timer = 0.0; _sm_stuck_last_dist = INF
			_sm_state = "wander"; return
	var m := 12.0
	_sm_target = zone_rect.get_center() if not zone_rect.has_area() else \
		Vector2(randf_range(zone_rect.position.x + m, zone_rect.end.x - m),
				randf_range(zone_rect.position.y + m, zone_rect.end.y - m))
	_sm_walk_timer = 0.0; _sm_stuck_timer = 0.0; _sm_stuck_last_dist = INF
	_sm_state = "wander"
