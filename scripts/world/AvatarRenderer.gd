## AvatarRenderer.gd
## Static helper — loads Modern Interiors character sprites and creates Sprite2D nodes.
## Uses AtlasTexture to crop a single frame from idle/sit spritesheets.
## Falls back to ColorRect if the asset is not found.

extends RefCounted
class_name AvatarRenderer

# Department/role → idle spritesheet filename (no extension)
# Modern Interiors: Adam_idle_16x16.png = 64×32 (4 frames of 16×32)
const SPRITE_MAP: Dictionary = {
	"player":      "Adam_idle_16x16",
	"engineering": "Adam_idle_16x16",
	"design":      "Amelia_idle_16x16",
	"product":     "Bob_idle_16x16",
	"hr":          "Alex_idle_16x16",
	"data":        "Adam_idle_16x16",
	"marketing":   "Amelia_idle_16x16",
	"default":     "Adam_idle_16x16",
}

# Sit sprite map — Adam_sit_16x16.png = 384×32 (24 frames of 16×32)
const SIT_MAP: Dictionary = {
	"player":      "Adam_sit_16x16",
	"engineering": "Adam_sit_16x16",
	"design":      "Amelia_sit_16x16",
	"product":     "Bob_sit_16x16",
	"hr":          "Alex_sit_16x16",
	"data":        "Adam_sit_16x16",
	"marketing":   "Amelia_sit_16x16",
	"default":     "Adam_sit_16x16",
}

const BASE_PATH   : String = "res://assets/sprites/characters/modern/"
const SPRITE_SCALE: float  = 0.75  # 16×32 px → 12×24 px in-world (matches player)
const FRAME_W     : float  = 16.0
const FRAME_H     : float  = 32.0

# ─────────────────────────────────────────────
# _load_texture(res_path) → Texture2D or null
# ─────────────────────────────────────────────
static func _load_texture(res_path: String) -> Texture2D:
	var texture: Texture2D = null

	# ── Try import system (works after Godot has scanned the project once) ──
	if ResourceLoader.exists(res_path):
		texture = load(res_path) as Texture2D

	# ── Fallback: direct image load (desktop only — FileAccess path not available on web) ──
	if texture == null and not OS.has_feature("web"):
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				texture = ImageTexture.create_from_image(img)

	return texture

# ─────────────────────────────────────────────
# _make_atlas_sprite(sheet_tex, frame_col, frame_row) → Sprite2D
# Crops a single 16×32 frame from a spritesheet.
# ─────────────────────────────────────────────
static func _make_atlas_sprite(sheet_tex: Texture2D) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_tex
	atlas.region = Rect2(0, 0, FRAME_W, FRAME_H)  # frame 0 only
	atlas.filter_clip = true

	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.name = "CharacterSprite"
	# Anchor feet at node origin — Sprite2D is center-anchored
	sprite.position = Vector2(0.0, -(FRAME_H * SPRITE_SCALE * 0.5))
	return sprite

# ─────────────────────────────────────────────
# make_sprite(role) → Sprite2D or null
#   Uses idle frame 0 (16×32 crop from idle sheet)
# ─────────────────────────────────────────────
static func make_sprite(role: String) -> Sprite2D:
	var fname    : String   = SPRITE_MAP.get(role.to_lower(), SPRITE_MAP["default"])
	var res_path : String   = BASE_PATH + fname + ".png"
	var texture  : Texture2D = _load_texture(res_path)

	if texture == null:
		return null

	return _make_atlas_sprite(texture)

# ─────────────────────────────────────────────
# make_sit_sprite(role) → Sprite2D or null
#   Uses sit frame 0 (16×32 crop from sit sheet)
# ─────────────────────────────────────────────
static func make_sit_sprite(role: String) -> Sprite2D:
	var fname    : String   = SIT_MAP.get(role.to_lower(), SIT_MAP["default"])
	var res_path : String   = BASE_PATH + fname + ".png"
	var texture  : Texture2D = _load_texture(res_path)

	if texture == null:
		# Fall back to standing idle sprite
		return make_sprite(role)

	return _make_atlas_sprite(texture)

const PREMADE_PATH   : String = "res://assets/sprites/characters/premade/"
const GENERATED_PATH : String = "res://assets/sprites/characters/generated/"

# Generated/Premade character sheets are 896×656.
# Each frame is 32×32 px; face-down idle is at column 0, row 0 (content starts y=10).
const GEN_FRAME_W : float = 32.0
const GEN_FRAME_H : float = 32.0
const GEN_FRAME_Y : float = 10.0   # first row content offset
const GEN_SCALE   : float = 1.2    # 32×32 → 38×38 in-world

# ─────────────────────────────────────────────
# _make_gen_sprite(sheet_tex) → Sprite2D
#   Crops face-down idle frame from a 896×656 generated/premade sheet.
# ─────────────────────────────────────────────
static func _make_gen_sprite(sheet_tex: Texture2D) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_tex
	atlas.region = Rect2(0, GEN_FRAME_Y, GEN_FRAME_W, GEN_FRAME_H)
	atlas.filter_clip = true

	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2(GEN_SCALE, GEN_SCALE)
	sprite.name = "CharacterSprite"
	sprite.position = Vector2(0.0, -(GEN_FRAME_H * GEN_SCALE * 0.5))
	return sprite

# ─────────────────────────────────────────────
# make_premade_sprite(char_id) → Sprite2D or null
#   Loads Premade_Character_XX.png. char_id: 1–20
# ─────────────────────────────────────────────
static func make_premade_sprite(char_id: int) -> Sprite2D:
	var fname    : String    = "Premade_Character_%02d.png" % char_id
	var res_path : String    = PREMADE_PATH + fname
	var texture  : Texture2D = _load_texture(res_path)
	if texture == null:
		return null
	return _make_gen_sprite(texture)

# ─────────────────────────────────────────────
# make_generated_sprite(char_id) → Sprite2D or null
#   Loads Generated_Character_XXX.png. char_id: 1–60
# ─────────────────────────────────────────────
static func make_generated_sprite(char_id: int) -> Sprite2D:
	var fname    : String    = "Generated_Character_%03d.png" % char_id
	var res_path : String    = GENERATED_PATH + fname
	var texture  : Texture2D = _load_texture(res_path)
	if texture == null:
		return null
	return _make_gen_sprite(texture)

# ─────────────────────────────────────────────
# make_sprite_for_npc(emp_data) → Sprite2D or null
#   char_id 1–60  → generated character
#   char_id 61–80 → premade character (61→Premade_01, etc.)
#   otherwise     → role-based idle sprite
# ─────────────────────────────────────────────
static func make_sprite_for_npc(emp_data: Dictionary) -> Sprite2D:
	var char_id: int = emp_data.get("char_id", 0)
	if char_id >= 1 and char_id <= 60:
		var sprite: Sprite2D = make_generated_sprite(char_id)
		if sprite != null:
			return sprite
	elif char_id >= 61 and char_id <= 80:
		var sprite: Sprite2D = make_premade_sprite(char_id - 60)
		if sprite != null:
			return sprite
	var role: String = emp_data.get("department", "default")
	return make_sprite(role)

# ─────────────────────────────────────────────
# make_anim_sprite_for_npc(emp_data) → AnimatedSprite2D or null
#   Idle-only directional animation (south/north/east; west = flip_h east).
#   Sheet layout: 24 frames, 6 per direction, row 0.
# ─────────────────────────────────────────────
## Sheet layout: 384×32, 24 frames. south=0-5, north=6-11, west=12-17; east=flip west.
## Nếu sheet chỉ có 4 frames (64 px, ví dụ idle fallback), chỉ dùng south direction.
static func _fill_directional_anims(
		frames: SpriteFrames, sheet: Texture2D,
		prefix: String, fps: float) -> void:
	# Tính số frames theo chiều ngang của sheet
	var sheet_w: int = sheet.get_width()
	var total_frames: int = int(sheet_w / FRAME_W)   # e.g. 384/16=24, 64/16=4
	# dirs phụ thuộc vào số frames: ≥18 → 3 hướng, ≥12 → 2 hướng (south+north), <12 → chỉ south
	var dirs: Dictionary
	if total_frames >= 18:
		dirs = {"south": 0, "north": 6, "west": 12}
	elif total_frames >= 12:
		dirs = {"south": 0, "north": 6}
	else:
		dirs = {"south": 0}
	var frames_per_dir: int = min(6, total_frames)
	for dir: String in dirs:
		var start: int = dirs[dir]
		# Bỏ qua nếu start vượt quá số frames có sẵn
		if start >= total_frames:
			continue
		var anim_name: String = prefix + "_" + dir
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)
		for i: int in frames_per_dir:
			var frame_idx: int = start + i
			if frame_idx >= total_frames:
				break
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(frame_idx * FRAME_W, 0, FRAME_W, FRAME_H)
			atlas.filter_clip = true
			frames.add_frame(anim_name, atlas)
	# Đảm bảo luôn có đủ 3 hướng để update_npc_facing không bị lỗi
	# Nếu thiếu north/west → alias sang south
	for fallback_dir: String in ["north", "west"]:
		var anim_name: String = prefix + "_" + fallback_dir
		var south_name: String = prefix + "_south"
		if not frames.has_animation(anim_name) and frames.has_animation(south_name):
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(anim_name, true)
			for fi: int in frames.get_frame_count(south_name):
				frames.add_frame(anim_name, frames.get_frame_texture(south_name, fi))

static func make_anim_sprite_for_npc(emp_data: Dictionary) -> AnimatedSprite2D:
	var role: String = emp_data.get("department", "default").to_lower()
	var char_name: String = SPRITE_MAP.get(role, SPRITE_MAP["default"])
	# Strip "_idle_16x16" suffix to get base name (e.g. "Adam")
	var base: String = char_name.replace("_idle_16x16", "")
	var idle_tex: Texture2D = _load_texture(BASE_PATH + base + "_idle_anim_16x16.png")
	if idle_tex == null:
		idle_tex = _load_texture(BASE_PATH + base + "_idle_16x16.png")
	if idle_tex == null:
		return null
	var run_tex: Texture2D = _load_texture(BASE_PATH + base + "_run_16x16.png")

	var frames := SpriteFrames.new()
	frames.clear_all()
	_fill_directional_anims(frames, idle_tex, "idle", 5.0)
	if run_tex:
		_fill_directional_anims(frames, run_tex, "run", 8.0)
	else:
		_fill_directional_anims(frames, idle_tex, "run", 5.0)
	var sit_tex: Texture2D = _load_texture(BASE_PATH + base + "_sit_16x16.png")
	if sit_tex:
		_fill_directional_anims(frames, sit_tex, "sit", 5.0)

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.name = "CharacterSprite"
	anim.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	anim.position = Vector2(0.0, -(FRAME_H * SPRITE_SCALE * 0.5))
	anim.play("idle_south")
	return anim


# ─────────────────────────────────────────────
# make_fallback_body(color) → two ColorRects in a Node2D container
# ─────────────────────────────────────────────
static func make_fallback_body(color: Color) -> Node2D:
	var container := Node2D.new()

	var body := ColorRect.new()
	body.size     = Vector2(12.0, 16.0)
	body.position = Vector2(-6.0, -16.0)
	body.color    = color
	container.add_child(body)

	var head := ColorRect.new()
	head.size     = Vector2(10.0, 10.0)
	head.position = Vector2(-5.0, -26.0)
	head.color    = color.lightened(0.3)
	container.add_child(head)

	return container
