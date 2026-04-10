## Employee.gd
## NPC representing a ZPS team member — fully self-contained (builds own nodes).
## No scene file required. Works when instantiated programmatically from Office.gd.
## Left-click on an NPC to interact directly.

class_name Employee
extends CharacterBody2D

const _AR = preload("res://scripts/world/AvatarRenderer.gd")

# ── LimboAI behavior scripts ──
const _BTIsTalking        = preload("res://scripts/ai/conditions/BTIsTalking.gd")
const _BTIsPlayerNearby   = preload("res://scripts/ai/conditions/BTIsPlayerNearby.gd")
const _BTIdleInPlace      = preload("res://scripts/ai/actions/BTIdleInPlace.gd")
const _BTPickWanderTarget = preload("res://scripts/ai/actions/BTPickWanderTarget.gd")
const _BTWalkToTarget     = preload("res://scripts/ai/actions/BTWalkToTarget.gd")
const _BTFacePlayer       = preload("res://scripts/ai/actions/BTFacePlayer.gd")
const _BTChatWithNPC      = preload("res://scripts/ai/actions/BTChatWithNPC.gd")
const _BTSitAtDesk        = preload("res://scripts/ai/actions/BTSitAtDesk.gd")
const _BTLookAround       = preload("res://scripts/ai/actions/BTLookAround.gd")

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


# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("employees")
	collision_layer = 4   # NPC layer — detected by player interaction area
	collision_mask  = 5   # Collides with layer 1 (world) + layer 3 (other NPCs)
	_build_visuals()
	_load_employee_data()
	_setup_behavior_tree()
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
# LimboAI Behavior Tree setup
# ─────────────────────────────────────────────
func _setup_behavior_tree() -> void:
	# ── Build tree structure ──
	# BTDynamicSelector: re-evaluates ALL children from start every tick
	# → higher-priority branches (P1, P2) can interrupt lower ones (P3)
	var root := BTDynamicSelector.new()

	# P1: Talking branch — đứng yên khi đang chat
	# BTDynamicSequence: re-checks BTIsTalking every tick so it can exit when talking ends
	var talking_seq := BTDynamicSequence.new()
	var idle_inf := _BTIdleInPlace.new()
	idle_inf.wait_min = 0.0
	idle_inf.wait_max = 0.0   # vô hạn
	talking_seq.add_child(_BTIsTalking.new())
	talking_seq.add_child(idle_inf)
	root.add_child(talking_seq)

	# P2: React branch — nhìn player khi gần
	# BTDynamicSequence: re-checks BTIsPlayerNearby so BTFacePlayer exits when player leaves
	var react_seq := BTDynamicSequence.new()
	react_seq.add_child(_BTIsPlayerNearby.new())
	react_seq.add_child(_BTFacePlayer.new())
	root.add_child(react_seq)

	# P3: Activity branch — idle ngắn rồi random-chọn hoạt động
	# BTRandomSelector thử các nhánh con theo thứ tự NGẪU NHIÊN:
	#   A. Chat với NPC gần đó (FAIL nếu không tìm được partner)
	#   B. Ngồi làm việc tại bàn
	#   C. Nhìn quanh tại chỗ
	#   D. Wander trong zone
	#   E. Wander cross-zone (copy D — 25% chance của BTPickWanderTarget tự chọn điểm xa)
	var act_sel := BTRandomSelector.new()

	act_sel.add_child(_BTChatWithNPC.new())    # A: pair chat

	act_sel.add_child(_BTSitAtDesk.new())      # B: sit and work

	act_sel.add_child(_BTLookAround.new())     # C: look around in place

	var wander_a := BTSequence.new()           # D: wander (standard)
	wander_a.add_child(_BTPickWanderTarget.new())
	wander_a.add_child(_BTWalkToTarget.new())
	act_sel.add_child(wander_a)

	var wander_b := BTSequence.new()           # E: extra wander weight
	wander_b.add_child(_BTPickWanderTarget.new())
	wander_b.add_child(_BTWalkToTarget.new())
	act_sel.add_child(wander_b)

	var p3_seq := BTSequence.new()
	var idle_wait := _BTIdleInPlace.new()
	idle_wait.wait_min = 0.5
	idle_wait.wait_max = 1.5
	p3_seq.add_child(idle_wait)
	p3_seq.add_child(act_sel)
	root.add_child(p3_seq)

	# ── Setup BTPlayer ──
	# Add WITHOUT behavior_tree first so _try_initialize() returns early (silent).
	# Then set owner (Employee) so LimboAI can detect the scene root.
	# Assigning behavior_tree last re-triggers _try_initialize() with owner already set.
	var bt_player := BTPlayer.new()
	bt_player.update_mode = BTPlayer.UpdateMode.PHYSICS
	add_child(bt_player)       # _ready() fires → _try_initialize → no BT → silent early exit
	bt_player.owner = self     # now owner is valid (node already in tree)

	# ── Init blackboard BEFORE assigning BT (blackboard must exist at init time) ──
	bt_player.blackboard.set_var("zone_rect", zone_rect)
	bt_player.blackboard.set_var("wander_target", position)
	bt_player.blackboard.set_var("idle_remaining", 0.0)

	var bt := BehaviorTree.new()
	bt.root_task = root
	bt_player.behavior_tree = bt  # triggers _try_initialize again — owner set → success
