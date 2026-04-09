## Player.gd
## Player character — prototype-safe, builds own child nodes
## Movement: WASD / Left-click to move, Interaction: E / Left-click on NPC

class_name Player
extends CharacterBody2D

const _AR = preload("res://scripts/world/AvatarRenderer.gd")

@export var move_speed: float = 100.0
@export var run_speed: float = 180.0

# ── Visual nodes (created in _ready) ──
var body_rect: ColorRect = null
var head_rect: ColorRect = null
var nameplate: Label = null
var interact_hint: Label = null
var interaction_area: Area2D = null

# ── State ──
var is_busy: bool = false
var nearby_interactables: Array[Node] = []
var _hint_target: Node = null   # NPC currently showing its interact hint

# ── Click-to-move state ──
var _click_target: Vector2 = Vector2.ZERO
var _click_moving: bool = false
const CLICK_ARRIVE_THRESHOLD: float = 5.0

const WALK_SPEED_THRESHOLD = 0.1

func _ready() -> void:
	add_to_group("player")
	_build_physics_collision()
	_build_visuals()
	_build_interaction_area()
	NetworkManager.chat_received.connect(_on_chat_received_bubble)
	# Connect to multiplayer server only after login is complete
	if PlayerData.is_logged_in:
		_connect_to_server()
	else:
		PlayerData.login_complete.connect(_connect_to_server, CONNECT_ONE_SHOT)

func _connect_to_server() -> void:
	NetworkManager.connect_to_server(
		PlayerData.player_id,
		global_position.x,
		global_position.y,
		PlayerData.avatar_config,
		"main"
	)

func _build_physics_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 5.0
	shape.height = 10.0
	col.shape = shape
	col.position = Vector2(0.0, -8.0)
	add_child(col)

func _build_visuals() -> void:
	# ── Try AnimatedSprite2D first, fallback to ColorRect ──
	var anim_sprite := _build_animated_sprite()
	if anim_sprite:
		add_child(anim_sprite)
		body_rect = null
		head_rect = null
	else:
		body_rect = ColorRect.new()
		body_rect.size = Vector2(12, 16)
		body_rect.position = Vector2(-6, -16)
		body_rect.color = Color(0.35, 0.75, 1.0)
		add_child(body_rect)

		head_rect = ColorRect.new()
		head_rect.size = Vector2(10, 10)
		head_rect.position = Vector2(-5, -26)
		head_rect.color = Color(0.65, 0.92, 1.0)
		add_child(head_rect)

	# Nameplate — 2 dòng căn giữa, không có YOU
	nameplate = Label.new()
	nameplate.name = "Nameplate"
	var _dn := PlayerData.display_name
	var _sep := _dn.find(" - ")
	nameplate.text = _dn.left(_sep) if _sep > 0 else _dn
	nameplate.add_theme_font_size_override("font_size", 8)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.custom_minimum_size = Vector2(80, 0)
	nameplate.position = Vector2(-40, -40)
	nameplate.modulate = Color(0.9, 1.0, 0.7)
	add_child(nameplate)

	# Title label (golden, căn giữa)
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = PlayerData.hr_title
	title_lbl.add_theme_font_size_override("font_size", 7)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.custom_minimum_size = Vector2(80, 0)
	title_lbl.position = Vector2(-40, -30)
	title_lbl.modulate = Color(0.90, 0.75, 0.28)
	add_child(title_lbl)

	# Interact hint (shown when near interactable)
	interact_hint = Label.new()
	interact_hint.name = "InteractHint"
	interact_hint.text = "[E] Talk"
	interact_hint.add_theme_font_size_override("font_size", 8)
	interact_hint.position = Vector2(-18, -62)
	interact_hint.modulate = Color(1.0, 0.9, 0.4)
	interact_hint.visible = false
	add_child(interact_hint)

	# Outfit color indicator (changes with outfit)
	_refresh_outfit_color()

## Sheet layout (Adam_idle_anim_16x16.png / Adam_run_16x16.png): 384×32, 24 frames
## Row 0 — 0-5: south (down), 6-11: north (up), 12-17: west (left); east = flip west
const _CHAR_SCALE: float = 0.75

static func _load_tex_abs(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var t = load(res_path) as Texture2D
		if t:
			return t
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

static func _add_directional_anims(
		frames: SpriteFrames,
		sheet: Texture2D,
		prefix: String,
		fps: float) -> void:
	# Directions: south=col 0, north=col 6, west=col 12 (east = flip west)
	var dirs: Dictionary = {"south": 0, "north": 6, "west": 12}
	for dir: String in dirs:
		var start_col: int = dirs[dir]
		var anim_name: String = prefix + "_" + dir
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)
		for i: int in 6:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2((start_col + i) * 16, 0, 16, 32)
			atlas.filter_clip = true
			frames.add_frame(anim_name, atlas)

func _build_animated_sprite() -> AnimatedSprite2D:
	const BASE := "res://assets/sprites/characters/modern/"
	var idle_tex: Texture2D = _load_tex_abs(BASE + "Adam_idle_anim_16x16.png")
	if idle_tex == null:
		idle_tex = _load_tex_abs(BASE + "Adam_idle_16x16.png")
	if idle_tex == null:
		return null

	var run_tex: Texture2D = _load_tex_abs(BASE + "Adam_run_16x16.png")

	var frames := SpriteFrames.new()
	frames.clear_all()

	_add_directional_anims(frames, idle_tex, "idle", 6.0)
	if run_tex:
		_add_directional_anims(frames, run_tex, "run", 8.0)
	else:
		_add_directional_anims(frames, idle_tex, "run", 6.0)

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.name = "AnimatedSprite"
	anim.scale = Vector2(_CHAR_SCALE, _CHAR_SCALE)
	anim.position = Vector2(0.0, -8.0)
	anim.play("idle_south")  # default: face down
	return anim

func _build_interaction_area() -> void:
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	interaction_area.add_child(col)
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 4  # NPC layer
	interaction_area.body_entered.connect(_on_interactable_entered)
	interaction_area.body_exited.connect(_on_interactable_exited)
	add_child(interaction_area)

func _refresh_outfit_color() -> void:
	if body_rect == null:
		return  # Using sprite — no ColorRect to tint
	var outfit_colors = {
		"work_casual":     Color(0.35, 0.75, 1.0),
		"formal":          Color(0.25, 0.35, 0.60),
		"creative":        Color(0.85, 0.45, 0.80),
		"initiate_class":  Color(0.45, 0.80, 0.50),
		"game_dev":        Color(0.90, 0.55, 0.25),
	}
	var c = outfit_colors.get(PlayerData.current_outfit, Color(0.35, 0.75, 1.0))
	body_rect.color = c
	head_rect.color = c.lightened(0.3)

# ─────────────────────────────────────────────
# Physics / input
# ─────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	if is_busy:
		velocity = Vector2.ZERO
		return

	# ── Click-to-move takes priority over WASD if active ──
	if _click_moving:
		var dir_to_target := _click_target - global_position
		if dir_to_target.length() < CLICK_ARRIVE_THRESHOLD:
			_click_moving = false
			velocity = Vector2.ZERO
		else:
			velocity = dir_to_target.normalized() * move_speed
		var _intended_vel := velocity  # snapshot trước slide
		move_and_slide()
		if NetworkManager.is_connected_to_server():
			NetworkManager.queue_position(global_position)
		_update_animation(_intended_vel)
		return

	# ── WASD movement ──
	var speed = run_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	var dir = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

	# Any WASD input cancels click-to-move
	if dir.length() > WALK_SPEED_THRESHOLD:
		_click_moving = false

	velocity = dir * speed if dir.length() > WALK_SPEED_THRESHOLD else Vector2.ZERO
	var _intended_vel := velocity  # snapshot trước slide
	move_and_slide()
	if NetworkManager.is_connected_to_server():
		NetworkManager.queue_position(global_position)
	_update_animation(_intended_vel)

func _update_animation(intended_vel: Vector2 = Vector2.ZERO) -> void:
	var anim_node: Node = get_node_or_null("AnimatedSprite")
	if not (anim_node and anim_node is AnimatedSprite2D):
		return
	var anim_sprite := anim_node as AnimatedSprite2D
	# Dùng intended velocity để xác định facing (không bị ảnh hưởng bởi collision deflection)
	var vel := intended_vel
	var moving: bool = vel.length() > 10.0
	var prefix: String = "run" if moving else "idle"

	# Determine facing. Sheet col 12 = west (left). East = flip west.
	var facing: String = "south"
	var want_flip: bool = false
	if moving:
		if abs(vel.x) > abs(vel.y):
			if vel.x < 0.0:
				facing = "west"          # native left-facing frames
				want_flip = false
			else:
				facing = "west"          # flip west frames → east
				want_flip = true
		elif vel.y < 0.0:
			facing = "north"
		else:
			facing = "south"
	else:
		# Preserve last facing when idle
		var cur: String = anim_sprite.animation
		if cur.ends_with("_north"):  facing = "north"
		elif cur.ends_with("_west"): facing = "west"; want_flip = anim_sprite.flip_h
		else:                         facing = "south"

	if anim_sprite.flip_h != want_flip:
		anim_sprite.flip_h = want_flip

	var anim_name: String = prefix + "_" + facing
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func _unhandled_input(event: InputEvent) -> void:
	if is_busy:
		return

	# ── Left-click to move ──
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_target = get_global_mouse_position()
		_click_moving = true
		return

	# ── E key interaction ──
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact()

# ── Interaction ──
func _try_interact() -> void:
	if nearby_interactables.is_empty():
		return
	var closest = _closest_interactable()
	if closest and closest.has_method("on_player_interact"):
		closest.on_player_interact(self)

func _closest_interactable() -> Node:
	var min_d = INF
	var best: Node = null
	for n in nearby_interactables:
		if not is_instance_valid(n):
			continue
		var d = global_position.distance_to(n.global_position)
		if d < min_d:
			min_d = d; best = n
	return best

func _on_interactable_entered(body: Node) -> void:
	nearby_interactables.append(body)
	_update_hint_target()

func _on_interactable_exited(body: Node) -> void:
	nearby_interactables.erase(body)
	if body == _hint_target:
		if body.has_method("hide_interact_hint"):
			body.hide_interact_hint()
		_hint_target = null
	_update_hint_target()

# Shows the [E] Talk prompt on the closest reachable NPC, hides it on all others.
func _update_hint_target() -> void:
	var closest := _closest_interactable()
	if closest == _hint_target:
		return
	# Hide previous target
	if _hint_target != null and is_instance_valid(_hint_target):
		if _hint_target.has_method("hide_interact_hint"):
			_hint_target.hide_interact_hint()
	# Show new target
	_hint_target = closest
	if _hint_target != null and _hint_target.has_method("show_interact_hint"):
		_hint_target.show_interact_hint()

# ── Called by HUD / panels ──
func set_busy(busy: bool) -> void:
	is_busy = busy
	if busy:
		_click_moving = false
		velocity = Vector2.ZERO

# ── Floating chat bubble ──
func say(text: String, duration: float = 4.0) -> void:
	var old := get_node_or_null("ChatBubble")
	if old:
		old.queue_free()
	var bubble := Label.new()
	bubble.name = "ChatBubble"
	bubble.text = text
	bubble.add_theme_font_size_override("font_size", 7)
	bubble.position = Vector2(-30.0, -72.0)
	bubble.modulate = Color(1.0, 1.0, 0.8)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.custom_minimum_size = Vector2(80.0, 0.0)
	add_child(bubble)
	get_tree().create_timer(duration).timeout.connect(
		func(): if is_instance_valid(bubble): bubble.queue_free()
	)

func _on_chat_received_bubble(from_id: String, text: String, _ts: int) -> void:
	if from_id == PlayerData.player_id:
		say(text)
