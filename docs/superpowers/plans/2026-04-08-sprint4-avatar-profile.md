# Sprint 4 Implementation Plan — Avatar Identity & Cosmetic Systems
**Date:** 2026-04-08
**Project:** ZPS World (Godot 4.6 GDScript)
**Sprint Goal:** Rich avatar identity + ZPS Member achievement-based cosmetic unlocks + desk customization + emote system

---

## File Map

### New Godot files
| File | Purpose |
|------|---------|
| `scripts/ui/ProfileCard.gd` | Floating profile popup when clicking any avatar |
| `scripts/ui/EmoteMenu.gd` | Radial emote menu (Q key, 6 emotes) |
| `scripts/ui/DeskEditor.gd` | 4×3 desk decoration grid editor |

### Modified Godot files
| File | Changes |
|------|---------|
| `scripts/autoloads/PlayerData.gd` | Add `poll_achievements()`, `_achievement_poll_timer`, `update_desk_layout()` |
| `scripts/ui/HUD.gd` | Wire Q key → EmoteMenu, wire D key → DeskEditor, add emote toast display |
| `scripts/ui/AvatarCustomizer.gd` | Replace `@onready` scene refs with programmatic build; add live preview; add body/skin/hair/eye controls; show locked accessories |
| `scripts/world/RemotePlayer.gd` | Handle `emote_received` signal (floating emoji), add `_on_input_event` for profile card click |
| `scripts/world/Campus.gd` | Add `_check_desk_proximity()` in `_process`, wire D key to desk editor |

### New backend files
| File | Purpose |
|------|---------|
| `server/src/achievements.js` | In-memory achievements module (GET /achievements/my, GET /achievements/sync) |
| `server/tests/achievements.test.js` | Jest tests for achievement endpoints |

---

## Tasks

---

### Task 1 — Backend: Achievements Module (TDD)

**File:** `server/tests/achievements.test.js` (write test first)
**File:** `server/src/achievements.js`

#### Step 1.1 — Write failing tests

```javascript
// server/tests/achievements.test.js
const request = require("supertest");
const { createApp } = require("../src/app");

describe("GET /achievements/my", () => {
	let app;

	beforeEach(() => {
		app = createApp();
	});

	it("returns 200 with array of achievements", async () => {
		const res = await request(app)
			.get("/achievements/my")
			.set("x-player-id", "player_001");
		expect(res.status).toBe(200);
		expect(Array.isArray(res.body)).toBe(true);
	});

	it("returns achievements with required fields", async () => {
		const res = await request(app)
			.get("/achievements/my")
			.set("x-player-id", "player_001");
		const ach = res.body[0];
		expect(ach).toHaveProperty("id");
		expect(ach).toHaveProperty("title");
		expect(ach).toHaveProperty("unlocks");
	});

	it("returns all 3 seeded achievements for default player", async () => {
		const res = await request(app)
			.get("/achievements/my")
			.set("x-player-id", "player_001");
		expect(res.body).toHaveLength(3);
	});

	it("returns empty array for unknown player", async () => {
		const res = await request(app)
			.get("/achievements/my")
			.set("x-player-id", "unknown_xyz");
		expect(res.status).toBe(200);
		expect(res.body).toEqual([]);
	});
});

describe("GET /achievements/sync", () => {
	let app;

	beforeEach(() => {
		app = createApp();
	});

	it("returns 200 with new achievements since last_synced", async () => {
		const res = await request(app)
			.get("/achievements/sync")
			.query({ last_synced: "2020-01-01T00:00:00Z" })
			.set("x-player-id", "player_001");
		expect(res.status).toBe(200);
		expect(res.body).toHaveProperty("new_achievements");
		expect(Array.isArray(res.body.new_achievements)).toBe(true);
	});

	it("returns empty new_achievements when already up to date", async () => {
		const futureDate = new Date(Date.now() + 999999999).toISOString();
		const res = await request(app)
			.get("/achievements/sync")
			.query({ last_synced: futureDate })
			.set("x-player-id", "player_001");
		expect(res.status).toBe(200);
		expect(res.body.new_achievements).toHaveLength(0);
	});

	it("includes cosmetic unlock data in new achievements", async () => {
		const res = await request(app)
			.get("/achievements/sync")
			.query({ last_synced: "2020-01-01T00:00:00Z" })
			.set("x-player-id", "player_001");
		const ach = res.body.new_achievements[0];
		expect(ach).toHaveProperty("unlocks");
	});
});

describe("GET /players/:id/desk", () => {
	let app;

	beforeEach(() => {
		app = createApp();
	});

	it("returns 200 with desk layout array", async () => {
		const res = await request(app).get("/players/player_001/desk");
		expect(res.status).toBe(200);
		expect(res.body).toHaveProperty("desk_layout");
		expect(Array.isArray(res.body.desk_layout)).toBe(true);
	});

	it("returns 404 for unknown player", async () => {
		const res = await request(app).get("/players/unknown_xyz/desk");
		expect(res.status).toBe(404);
	});
});

describe("POST /players/me/desk", () => {
	let app;

	beforeEach(() => {
		app = createApp();
	});

	it("saves desk layout and returns 200", async () => {
		const layout = ["plant", "mug", "", "", "", "", "", "", "", "", "", ""];
		const res = await request(app)
			.post("/players/me/desk")
			.set("x-player-id", "player_001")
			.send({ desk_layout: layout });
		expect(res.status).toBe(200);
		expect(res.body).toHaveProperty("saved", true);
	});

	it("rejects layout with wrong length", async () => {
		const res = await request(app)
			.post("/players/me/desk")
			.set("x-player-id", "player_001")
			.send({ desk_layout: ["plant"] });
		expect(res.status).toBe(400);
	});
});
```

#### Step 1.2 — Implement achievements.js

```javascript
// server/src/achievements.js

// In-memory store keyed by player_id
const _playerAchievements = {};

// Seeded timestamp for mock data — achievements "earned" 2025-01-01
const SEED_DATE = "2025-01-01T00:00:00.000Z";

// Master achievement catalogue
const ACHIEVEMENT_CATALOGUE = [
	{
		id: "onboarding_complete",
		title: "Welcome to ZPS",
		description: "Complete the onboarding checklist",
		earned_at: SEED_DATE,
		unlocks: { outfit_id: "initiate_class" },
	},
	{
		id: "first_year",
		title: "1 Year ZPS",
		description: "Celebrate your first year at ZPS",
		earned_at: SEED_DATE,
		unlocks: { cape_id: "anniversary_cape" },
	},
	{
		id: "top_performer",
		title: "Top Performer",
		description: "Ranked in top 10% this quarter",
		earned_at: SEED_DATE,
		unlocks: { aura_body: "gold_glow" },
	},
];

// In-memory desk layouts: player_id -> Array[12 strings]
const _deskLayouts = {};

function _getPlayerAchievements(playerId) {
	if (!_playerAchievements[playerId]) {
		// Seed default player with all 3 achievements
		if (playerId === "player_001" || playerId === "player") {
			_playerAchievements[playerId] = [...ACHIEVEMENT_CATALOGUE];
		} else {
			_playerAchievements[playerId] = [];
		}
	}
	return _playerAchievements[playerId];
}

function registerRoutes(router) {
	// GET /achievements/my
	router.get("/achievements/my", (req, res) => {
		const playerId = req.headers["x-player-id"] || "anonymous";
		const achievements = _getPlayerAchievements(playerId);
		res.json(achievements);
	});

	// GET /achievements/sync?last_synced=ISO_DATE
	router.get("/achievements/sync", (req, res) => {
		const playerId = req.headers["x-player-id"] || "anonymous";
		const lastSyncedStr = req.query.last_synced || "1970-01-01T00:00:00Z";
		const lastSyncedMs = new Date(lastSyncedStr).getTime();

		const achievements = _getPlayerAchievements(playerId);
		const newAchievements = achievements.filter((ach) => {
			const earnedMs = new Date(ach.earned_at).getTime();
			return earnedMs > lastSyncedMs;
		});

		res.json({ new_achievements: newAchievements });
	});

	// GET /players/:id/desk
	router.get("/players/:id/desk", (req, res) => {
		const playerId = req.params.id;
		// Seed known players with empty layout
		if (playerId !== "player_001" && playerId !== "player" && !_deskLayouts[playerId]) {
			return res.status(404).json({ error: "Player not found" });
		}
		const layout = _deskLayouts[playerId] || Array(12).fill("");
		res.json({ desk_layout: layout });
	});

	// POST /players/me/desk
	router.post("/players/me/desk", (req, res) => {
		const playerId = req.headers["x-player-id"] || "anonymous";
		const { desk_layout } = req.body;

		if (!Array.isArray(desk_layout) || desk_layout.length !== 12) {
			return res.status(400).json({ error: "desk_layout must be an array of 12 items" });
		}

		_deskLayouts[playerId] = desk_layout.map((item) => (typeof item === "string" ? item : ""));
		res.json({ saved: true, desk_layout: _deskLayouts[playerId] });
	});
}

module.exports = { registerRoutes };
```

#### Step 1.3 — Wire into app.js

Locate `server/src/app.js` (or `server.js`) and add the achievements router:

```javascript
// Add near the top with other requires:
const achievementsModule = require("./achievements");

// Inside createApp() after existing routes:
achievementsModule.registerRoutes(router);
```

**Verification:** `cd server && npm test` — all 10 achievement/desk tests pass.

---

### Task 2 — PlayerData.gd: Achievement Polling + Desk Update

**File:** `scripts/autoloads/PlayerData.gd`

Add three things:
1. A timer-driven polling method that calls `GET /achievements/my` via `HttpManager`
2. `update_desk_layout(layout: Array)` to save and POST desk data
3. `_last_achievement_sync: String` to track the last sync timestamp

```gdscript
# ── Add to existing vars section ──
var _achievement_poll_timer: float = 0.0
const ACHIEVEMENT_POLL_INTERVAL: float = 3600.0  # 60 minutes
var _last_achievement_sync: String = "1970-01-01T00:00:00Z"

# ── Add to _ready() after existing lines ──
# func _ready() -> void:
#     load_data()
#     _set_todays_outfit()
#     set_process(true)   # <-- ADD THIS LINE
#     print(...)

func _process(delta: float) -> void:
	_achievement_poll_timer += delta
	if _achievement_poll_timer >= ACHIEVEMENT_POLL_INTERVAL:
		_achievement_poll_timer = 0.0
		poll_achievements()

func poll_achievements() -> void:
	if not HttpManager.is_available():
		return
	var url = "/achievements/sync?last_synced=" + _last_achievement_sync
	HttpManager.get_request(url, {}, _on_achievements_sync_response)

func _on_achievements_sync_response(status_code: int, body: Dictionary) -> void:
	if status_code != 200:
		push_warning("[PlayerData] Achievement sync failed: %d" % status_code)
		return
	var new_achievements: Array = body.get("new_achievements", [])
	if new_achievements.is_empty():
		return
	for ach in new_achievements:
		var ach_id: String = ach.get("id", "")
		if ach_id.is_empty() or ach_id in earned_achievements:
			continue
		var cosmetics: Dictionary = ach.get("unlocks", {})
		unlock_achievement(ach_id, cosmetics)
		# Show unlock toast via GameManager
		GameManager.notify("Achievement mở khóa: %s" % ach.get("title", ach_id), "achievement")
	# Advance sync cursor to now
	_last_achievement_sync = Time.get_datetime_string_from_system(true)

func update_desk_layout(layout: Array) -> void:
	desk_decorations = layout.duplicate()
	save_data()
	# POST to server
	if HttpManager.is_available():
		HttpManager.post_request(
			"/players/me/desk",
			{ "desk_layout": desk_decorations },
			func(_code: int, _body: Dictionary): pass
		)
```

**Note:** `set_process(true)` must be added to `_ready()`. The existing `_ready()` body stays intact — append the call after `_set_todays_outfit()`.

---

### Task 3 — AvatarCustomizer.gd: Full Programmatic Rebuild

**File:** `scripts/ui/AvatarCustomizer.gd`

Replace the existing `@onready`-based scene binding with a fully programmatic panel. The existing file uses `@onready` nodes that require a `.tscn` scene file — this task rebuilds the Appearance tab controls programmatically so no scene is needed.

Replace the **entire contents** of `scripts/ui/AvatarCustomizer.gd`:

```gdscript
## AvatarCustomizer.gd
## Full avatar customization panel — built entirely in code, no .tscn dependency.
## Tabs: Appearance, Outfit, Accessories, AI Agent, AI Portrait
## Shift+A to open/close via HUD.

extends Control

# ── Internal state ──
var pending_config: Dictionary = {}
var is_dirty: bool = false

# ── Node references (created in _build_ui) ──
var _tab_bar: TabContainer = null
var _preview_container: Control = null
var _preview_sprite: Control = null       # ColorRect fallback preview
var _save_btn: Button = null
var _close_btn: Button = null

# Appearance tab controls
var _body_type_btn: OptionButton = null
var _skin_tone_btns: Array[Button] = []
var _hair_style_btn: OptionButton = null
var _hair_color_btns: Array[Button] = []
var _eye_color_btn: OptionButton = null

# Outfit tab
var _outfit_grid: GridContainer = null
var _today_outfit_label: Label = null

# Accessories tab
var _accessory_grid: GridContainer = null

# AI Agent tab
var _ai_enable_toggle: CheckButton = null
var _ai_context_input: TextEdit = null
var _ai_test_result: Label = null

# Skin tone palette (0-4)
const SKIN_COLORS: Array = [
	Color(1.0, 0.87, 0.73),   # 0 — fair
	Color(0.96, 0.76, 0.57),  # 1 — light
	Color(0.82, 0.60, 0.38),  # 2 — medium
	Color(0.62, 0.41, 0.22),  # 3 — tan
	Color(0.37, 0.22, 0.10),  # 4 — deep
]

# Hair color palette (0-5)
const HAIR_COLORS: Array = [
	Color(0.10, 0.07, 0.05),  # 0 — black
	Color(0.35, 0.20, 0.08),  # 1 — dark brown
	Color(0.60, 0.38, 0.14),  # 2 — brown
	Color(0.84, 0.65, 0.22),  # 3 — blonde
	Color(0.80, 0.30, 0.10),  # 4 — auburn
	Color(0.75, 0.75, 0.78),  # 5 — silver
]

const ALL_OUTFITS: Array = [
	{"id": "work_casual",    "name": "Work Casual",     "locked": false},
	{"id": "formal",         "name": "Formal",           "locked": false},
	{"id": "creative",       "name": "Creative",         "locked": false},
	{"id": "initiate_class", "name": "Initiate Class",   "locked": false},
	{"id": "game_dev",       "name": "Game Dev Kit",     "locked": true, "req": "First Campaign"},
	{"id": "dragon_slayer",  "name": "Dragon Slayer",    "locked": true, "req": "Dragon Slayer Achievement"},
	{"id": "legend_tier",    "name": "Legend Tier",      "locked": true, "req": "Hall of Legends"},
]

# Accessory catalogue — id, display name, slot
const ALL_ACCESSORIES: Array = [
	{"id": "glasses_round",   "name": "Round Glasses",  "slot": "glasses", "locked": false},
	{"id": "glasses_square",  "name": "Square Glasses", "slot": "glasses", "locked": false},
	{"id": "hat_cap",         "name": "Baseball Cap",   "slot": "hat",     "locked": false},
	{"id": "hat_beanie",      "name": "Beanie",         "slot": "hat",     "locked": false},
	{"id": "earring_simple",  "name": "Simple Earring", "slot": "earring", "locked": false},
	{"id": "badge_star",      "name": "Star Badge",     "slot": "badge",   "locked": true,  "req": "Top Performer"},
	{"id": "halo_angel",      "name": "Angel Halo",     "slot": "halo",    "locked": true,  "req": "1 Year ZPS"},
]

func _ready() -> void:
	_build_ui()
	AIAgent.response_ready.connect(_on_ai_test_response)

# ────────────────────────────────────────────────────────────
# UI Builder
# ────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Root panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "Avatar Customizer"
	header.add_theme_font_size_override("font_size", 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(0.6, 0.9, 1.0)
	vbox.add_child(header)

	# Live preview strip
	_preview_container = _build_preview_strip()
	vbox.add_child(_preview_container)

	# Tab container
	_tab_bar = TabContainer.new()
	_tab_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_bar)

	_build_appearance_tab()
	_build_outfit_tab()
	_build_accessories_tab()
	_build_ai_agent_tab()

	# Footer buttons
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)

	_save_btn = Button.new()
	_save_btn.text = "Luu Avatar"
	_save_btn.pressed.connect(_on_save)
	footer.add_child(_save_btn)

	_close_btn = Button.new()
	_close_btn.text = "Dong"
	_close_btn.pressed.connect(_on_close)
	footer.add_child(_close_btn)

# ── Live preview strip ───────────────────────────────────────
func _build_preview_strip() -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 80)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14)
	style.set_corner_radius_all(6)
	container.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(hbox)

	_preview_sprite = ColorRect.new()
	_preview_sprite.name = "AvatarPreview"
	_preview_sprite.custom_minimum_size = Vector2(40, 60)
	_preview_sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_preview_sprite)

	return container

func _refresh_preview() -> void:
	if _preview_sprite == null:
		return
	# Update preview ColorRect color from skin tone
	var skin_idx: int = pending_config.get("skin_tone", 1)
	if skin_idx >= 0 and skin_idx < SKIN_COLORS.size():
		_preview_sprite.color = SKIN_COLORS[skin_idx]

# ── Appearance tab ───────────────────────────────────────────
func _build_appearance_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Appearance"
	_tab_bar.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Body type
	vbox.add_child(_section_label("Body Type"))
	_body_type_btn = OptionButton.new()
	_body_type_btn.add_item("Slim",   0)
	_body_type_btn.add_item("Medium", 1)
	_body_type_btn.add_item("Broad",  2)
	_body_type_btn.item_selected.connect(func(idx: int):
		pending_config["body_type"] = idx
		is_dirty = true
		_refresh_preview()
	)
	vbox.add_child(_body_type_btn)

	# Skin tone
	vbox.add_child(_section_label("Skin Tone"))
	var skin_row := HBoxContainer.new()
	_skin_tone_btns.clear()
	for i in SKIN_COLORS.size():
		var btn := ColorPickerButton.new()
		btn.color = SKIN_COLORS[i]
		btn.custom_minimum_size = Vector2(36, 36)
		btn.toggle_mode = true
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		var capture_i := i
		btn.pressed.connect(func():
			pending_config["skin_tone"] = capture_i
			is_dirty = true
			_refresh_preview()
			# Visually indicate selection
			for j in _skin_tone_btns.size():
				_skin_tone_btns[j].button_pressed = (j == capture_i)
		)
		skin_row.add_child(btn)
		_skin_tone_btns.append(btn)
	vbox.add_child(skin_row)

	# Hair style
	vbox.add_child(_section_label("Hair Style"))
	_hair_style_btn = OptionButton.new()
	var hair_styles := ["Short Crop", "Medium Waves", "Long Straight", "Curly Afro",
						"Side Part", "Bun", "Mohawk", "Buzz Cut"]
	for i in hair_styles.size():
		_hair_style_btn.add_item(hair_styles[i], i)
	_hair_style_btn.item_selected.connect(func(idx: int):
		pending_config["hair_style"] = idx
		is_dirty = true
	)
	vbox.add_child(_hair_style_btn)

	# Hair color
	vbox.add_child(_section_label("Hair Color"))
	var hair_row := HBoxContainer.new()
	_hair_color_btns.clear()
	for i in HAIR_COLORS.size():
		var btn := ColorPickerButton.new()
		btn.color = HAIR_COLORS[i]
		btn.custom_minimum_size = Vector2(36, 36)
		btn.toggle_mode = true
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		var capture_i := i
		btn.pressed.connect(func():
			pending_config["hair_color"] = capture_i
			is_dirty = true
			for j in _hair_color_btns.size():
				_hair_color_btns[j].button_pressed = (j == capture_i)
		)
		hair_row.add_child(btn)
		_hair_color_btns.append(btn)
	vbox.add_child(hair_row)

	# Eye color
	vbox.add_child(_section_label("Eye Color"))
	_eye_color_btn = OptionButton.new()
	var eye_colors := ["Dark Brown", "Brown", "Hazel", "Green", "Blue"]
	for i in eye_colors.size():
		_eye_color_btn.add_item(eye_colors[i], i)
	_eye_color_btn.item_selected.connect(func(idx: int):
		pending_config["eye_color"] = idx
		is_dirty = true
	)
	vbox.add_child(_eye_color_btn)

# ── Outfit tab ───────────────────────────────────────────────
func _build_outfit_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Outfit"
	_tab_bar.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_today_outfit_label = Label.new()
	_today_outfit_label.add_theme_font_size_override("font_size", 11)
	_today_outfit_label.modulate = Color(0.7, 1.0, 0.7)
	vbox.add_child(_today_outfit_label)

	_outfit_grid = GridContainer.new()
	_outfit_grid.columns = 3
	vbox.add_child(_outfit_grid)

# ── Accessories tab ──────────────────────────────────────────
func _build_accessories_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Accessories"
	_tab_bar.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var info := Label.new()
	info.text = "Click to equip / unequip. Locked items require achievements."
	info.add_theme_font_size_override("font_size", 10)
	info.modulate = Color(0.7, 0.7, 0.7)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)

	_accessory_grid = GridContainer.new()
	_accessory_grid.columns = 3
	vbox.add_child(_accessory_grid)

# ── AI Agent tab ─────────────────────────────────────────────
func _build_ai_agent_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "AI Agent"
	_tab_bar.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	vbox.add_child(_section_label("AI Agent khi offline"))

	_ai_enable_toggle = CheckButton.new()
	_ai_enable_toggle.text = "Bat AI Agent khi offline"
	vbox.add_child(_ai_enable_toggle)

	vbox.add_child(_section_label("AI Context (AI biet gi ve ban?)"))

	_ai_context_input = TextEdit.new()
	_ai_context_input.custom_minimum_size = Vector2(0, 100)
	_ai_context_input.placeholder_text = "Vi du: Toi la designer, chuyen product UI, hien dang lam Sprint 4..."
	vbox.add_child(_ai_context_input)

	var test_btn := Button.new()
	test_btn.text = "Test AI Agent"
	test_btn.pressed.connect(_on_test_ai_agent)
	vbox.add_child(test_btn)

	_ai_test_result = Label.new()
	_ai_test_result.add_theme_font_size_override("font_size", 10)
	_ai_test_result.modulate = Color(0.8, 0.9, 0.8)
	_ai_test_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_ai_test_result)

# ── Shared helper ────────────────────────────────────────────
func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.6, 0.8, 1.0)
	return lbl

# ────────────────────────────────────────────────────────────
# Refresh (called when panel opens)
# ────────────────────────────────────────────────────────────
func refresh() -> void:
	pending_config = PlayerData.avatar_config.duplicate(true)
	is_dirty = false
	_sync_controls_to_config()
	_populate_outfit_grid()
	_populate_accessories_grid()
	_update_today_label()
	if is_instance_valid(_ai_enable_toggle):
		_ai_enable_toggle.button_pressed = PlayerData.ai_agent_enabled
	if is_instance_valid(_ai_context_input):
		_ai_context_input.text = PlayerData.ai_agent_context
	_refresh_preview()

func _sync_controls_to_config() -> void:
	if is_instance_valid(_body_type_btn):
		_body_type_btn.selected = pending_config.get("body_type", 0)
	if is_instance_valid(_hair_style_btn):
		_hair_style_btn.selected = pending_config.get("hair_style", 0)
	if is_instance_valid(_eye_color_btn):
		_eye_color_btn.selected = pending_config.get("eye_color", 0)
	var skin_idx: int = pending_config.get("skin_tone", 1)
	for i in _skin_tone_btns.size():
		_skin_tone_btns[i].button_pressed = (i == skin_idx)
	var hair_color_idx: int = pending_config.get("hair_color", 0)
	for i in _hair_color_btns.size():
		_hair_color_btns[i].button_pressed = (i == hair_color_idx)

# ── Outfit grid population ────────────────────────────────────
func _populate_outfit_grid() -> void:
	if _outfit_grid == null:
		return
	for child in _outfit_grid.get_children():
		child.queue_free()
	for outfit in ALL_OUTFITS:
		var card := _create_outfit_card(outfit)
		_outfit_grid.add_child(card)

func _create_outfit_card(outfit: Dictionary) -> PanelContainer:
	var is_current := outfit["id"] == PlayerData.current_outfit
	var is_locked := outfit.get("locked", false) and outfit["id"] not in PlayerData.unlocked_outfits

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_current:
		style.bg_color = Color(0.20, 0.38, 0.20)
		style.border_color = Color(0.4, 0.85, 0.4)
		style.set_border_width_all(2)
	elif is_locked:
		style.bg_color = Color(0.10, 0.10, 0.12)
	else:
		style.bg_color = Color(0.16, 0.18, 0.22)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(100, 80)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = outfit["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.modulate = Color(0.5, 0.5, 0.5) if is_locked else Color.WHITE
	vbox.add_child(name_lbl)

	if is_locked:
		var lock_lbl := Label.new()
		lock_lbl.text = "[Khoa]\n" + outfit.get("req", "???")
		lock_lbl.add_theme_font_size_override("font_size", 8)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.modulate = Color(0.5, 0.5, 0.5)
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(lock_lbl)
	else:
		var equip_btn := Button.new()
		equip_btn.text = "Dang mac" if is_current else "Mac hom nay"
		equip_btn.disabled = is_current
		equip_btn.pressed.connect(func(): _equip_outfit(outfit["id"]))
		vbox.add_child(equip_btn)

	return panel

func _equip_outfit(outfit_id: String) -> void:
	PlayerData.set_outfit_for_today(outfit_id)
	_populate_outfit_grid()
	_update_today_label()
	is_dirty = false

func _update_today_label() -> void:
	if is_instance_valid(_today_outfit_label):
		_today_outfit_label.text = "Hom nay: %s" % PlayerData.current_outfit.replace("_", " ").capitalize()

# ── Accessories grid ──────────────────────────────────────────
func _populate_accessories_grid() -> void:
	if _accessory_grid == null:
		return
	for child in _accessory_grid.get_children():
		child.queue_free()
	var equipped: Array = pending_config.get("accessories", [])
	for acc in ALL_ACCESSORIES:
		var card := _create_accessory_card(acc, equipped)
		_accessory_grid.add_child(card)

func _create_accessory_card(acc: Dictionary, equipped: Array) -> PanelContainer:
	var is_equipped := acc["id"] in equipped
	var earned_cosmetics: Dictionary = PlayerData.earned_cosmetics
	var earned_list: Array = earned_cosmetics.get("accessories", [])
	var is_locked := acc.get("locked", false) and acc["id"] not in earned_list

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.18, 0.30, 0.38)
		style.border_color = Color(0.4, 0.75, 1.0)
		style.set_border_width_all(2)
	elif is_locked:
		style.bg_color = Color(0.10, 0.10, 0.12)
	else:
		style.bg_color = Color(0.16, 0.18, 0.22)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(100, 70)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = acc["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.modulate = Color(0.5, 0.5, 0.5) if is_locked else Color.WHITE
	vbox.add_child(name_lbl)

	if is_locked:
		var lock_lbl := Label.new()
		lock_lbl.text = "[Khoa]: " + acc.get("req", "???")
		lock_lbl.add_theme_font_size_override("font_size", 8)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.modulate = Color(0.5, 0.5, 0.5)
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(lock_lbl)
	else:
		var toggle_btn := Button.new()
		toggle_btn.text = "Go bo" if is_equipped else "Trang bi"
		toggle_btn.pressed.connect(func(): _toggle_accessory(acc["id"]))
		vbox.add_child(toggle_btn)

	return panel

func _toggle_accessory(acc_id: String) -> void:
	var equipped: Array = pending_config.get("accessories", []).duplicate()
	if acc_id in equipped:
		equipped.erase(acc_id)
	else:
		equipped.append(acc_id)
	pending_config["accessories"] = equipped
	is_dirty = true
	_populate_accessories_grid()

# ────────────────────────────────────────────────────────────
# AI Agent handlers
# ────────────────────────────────────────────────────────────
func _on_test_ai_agent() -> void:
	if not is_instance_valid(_ai_test_result):
		return
	_ai_test_result.text = "Dang test..."
	AIAgent.ask_self_agent("Ban dang lam gi vay?")

func _on_ai_test_response(response: String, context_id: String) -> void:
	if not context_id.begins_with("self_"):
		return
	if is_instance_valid(_ai_test_result):
		_ai_test_result.text = "AI se tra loi: \"%s\"" % response

# ────────────────────────────────────────────────────────────
# Save / Close
# ────────────────────────────────────────────────────────────
func _on_save() -> void:
	PlayerData.update_avatar(pending_config)
	if is_instance_valid(_ai_enable_toggle):
		PlayerData.ai_agent_enabled = _ai_enable_toggle.button_pressed
	if is_instance_valid(_ai_context_input):
		PlayerData.set_ai_context(_ai_context_input.text)
	# Broadcast updated avatar to server
	NetworkManager.send_status("online", "")
	GameManager.notify("Avatar da luu!", "success")
	is_dirty = false

func _on_close() -> void:
	if is_dirty:
		GameManager.notify("Co thay doi chua luu — da huy.", "warning")
		pending_config = PlayerData.avatar_config.duplicate(true)
		is_dirty = false
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_toggle_avatar_customizer"):
		hud._toggle_avatar_customizer()
	else:
		hide()
```

---

### Task 4 — ProfileCard.gd (new file)

**File:** `scripts/ui/ProfileCard.gd`

```gdscript
## ProfileCard.gd
## Floating profile popup shown when clicking a RemotePlayer or Employee avatar.
## Displays name, title, department, achievement badges, online status.
## Quick actions: Send DM, View Desk.

class_name ProfileCard
extends PanelContainer

# ── Data ──
var target_player_id: String = ""
var target_display_name: String = ""
var target_title: String = ""
var target_department: String = ""
var target_status: String = "online"
var target_status_msg: String = ""
var target_achievements: Array[String] = []
var target_is_npc: bool = false

# ── Node refs ──
var _name_label: Label = null
var _title_label: Label = null
var _dept_label: Label = null
var _status_dot: ColorRect = null
var _status_label: Label = null
var _status_msg_label: Label = null
var _badge_row: HBoxContainer = null
var _npc_badge: Label = null
var _dm_btn: Button = null
var _desk_btn: Button = null

# ── Signals ──
signal dm_requested(player_id: String)
signal view_desk_requested(player_id: String)

func _ready() -> void:
	_build_ui()
	# Auto-close after 8 seconds if not interacted with
	var timer := Timer.new()
	timer.wait_time = 8.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	style.set_corner_radius_all(10)
	style.border_color = Color(0.3, 0.45, 0.65)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(220, 160)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	# ── Header row: status dot + name ──
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	_status_dot = ColorRect.new()
	_status_dot.custom_minimum_size = Vector2(10, 10)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot.color = Color(0.2, 0.9, 0.2)
	header_row.add_child(_status_dot)

	_name_label = Label.new()
	_name_label.text = "Unknown"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.modulate = Color(0.9, 0.95, 1.0)
	header_row.add_child(_name_label)

	_npc_badge = Label.new()
	_npc_badge.text = " [AI]"
	_npc_badge.add_theme_font_size_override("font_size", 10)
	_npc_badge.modulate = Color(1.0, 0.75, 0.1)
	_npc_badge.visible = false
	header_row.add_child(_npc_badge)

	# ── Title + department ──
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.modulate = Color(0.7, 0.8, 0.9)
	vbox.add_child(_title_label)

	_dept_label = Label.new()
	_dept_label.add_theme_font_size_override("font_size", 10)
	_dept_label.modulate = Color(0.6, 0.7, 0.8)
	vbox.add_child(_dept_label)

	# ── Status message ──
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_status_label)

	_status_msg_label = Label.new()
	_status_msg_label.add_theme_font_size_override("font_size", 10)
	_status_msg_label.modulate = Color(0.75, 0.75, 0.75)
	_status_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_msg_label)

	# ── Achievement badges (top 3) ──
	var badge_section := Label.new()
	badge_section.text = "Achievements:"
	badge_section.add_theme_font_size_override("font_size", 9)
	badge_section.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(badge_section)

	_badge_row = HBoxContainer.new()
	vbox.add_child(_badge_row)

	# ── Separator ──
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ── Quick actions ──
	var actions_row := HBoxContainer.new()
	vbox.add_child(actions_row)

	_dm_btn = Button.new()
	_dm_btn.text = "DM"
	_dm_btn.custom_minimum_size = Vector2(70, 28)
	_dm_btn.pressed.connect(func(): dm_requested.emit(target_player_id))
	actions_row.add_child(_dm_btn)

	_desk_btn = Button.new()
	_desk_btn.text = "View Desk"
	_desk_btn.custom_minimum_size = Vector2(90, 28)
	_desk_btn.pressed.connect(func(): view_desk_requested.emit(target_player_id))
	actions_row.add_child(_desk_btn)

# ── Public API ───────────────────────────────────────────────

# Populate the card with data and position it near the avatar.
func populate(data: Dictionary) -> void:
	target_player_id  = data.get("player_id", "")
	target_display_name = data.get("display_name", "Unknown")
	target_title      = data.get("title", "")
	target_department = data.get("department", "")
	target_status     = data.get("status", "online")
	target_status_msg = data.get("status_msg", "")
	target_achievements = data.get("achievements", [])
	target_is_npc     = data.get("is_npc", false)

	_name_label.text = target_display_name
	_title_label.text = target_title
	_dept_label.text  = target_department

	# Status dot color
	match target_status:
		"online":
			_status_dot.color = Color(0.2, 0.9, 0.2)
			_status_label.text = "Online"
			_status_label.modulate = Color(0.3, 0.9, 0.3)
		"away":
			_status_dot.color = Color(1.0, 0.75, 0.0)
			_status_label.text = "Away"
			_status_label.modulate = Color(1.0, 0.75, 0.0)
		"busy":
			_status_dot.color = Color(0.9, 0.25, 0.25)
			_status_label.text = "Busy"
			_status_label.modulate = Color(0.9, 0.3, 0.3)
		_:
			_status_dot.color = Color(0.5, 0.5, 0.5)
			_status_label.text = "Offline"
			_status_label.modulate = Color(0.6, 0.6, 0.6)

	_status_msg_label.text = target_status_msg if target_status_msg != "" else ""
	_status_msg_label.visible = target_status_msg != ""

	_npc_badge.visible = target_is_npc

	# Render top-3 achievement badges
	for child in _badge_row.get_children():
		child.queue_free()
	var shown := 0
	for ach_id in target_achievements:
		if shown >= 3:
			break
		var badge := Label.new()
		badge.text = _achievement_icon(ach_id) + " " + ach_id.replace("_", " ").capitalize()
		badge.add_theme_font_size_override("font_size", 9)
		badge.modulate = Color(1.0, 0.85, 0.3)
		_badge_row.add_child(badge)
		shown += 1
	if shown == 0:
		var none_lbl := Label.new()
		none_lbl.text = "No achievements yet"
		none_lbl.add_theme_font_size_override("font_size", 9)
		none_lbl.modulate = Color(0.5, 0.5, 0.5)
		_badge_row.add_child(none_lbl)

func _achievement_icon(ach_id: String) -> String:
	match ach_id:
		"onboarding_complete": return "[*]"
		"first_year":          return "[1yr]"
		"top_performer":       return "[TOP]"
		_:                     return "[+]"

# Position the card near a world node, clamped to viewport.
func position_near(world_node: Node2D, camera: Camera2D) -> void:
	if camera == null:
		global_position = Vector2(100, 100)
		return
	var screen_pos := camera.unproject_position(world_node.global_position)
	# Offset above the avatar
	var desired := screen_pos + Vector2(-custom_minimum_size.x * 0.5, -custom_minimum_size.y - 24.0)
	# Clamp to viewport
	var vp_size := get_viewport_rect().size
	desired.x = clamp(desired.x, 4.0, vp_size.x - custom_minimum_size.x - 4.0)
	desired.y = clamp(desired.y, 4.0, vp_size.y - custom_minimum_size.y - 4.0)
	position = desired
```

---

### Task 5 — EmoteMenu.gd (new file)

**File:** `scripts/ui/EmoteMenu.gd`

```gdscript
## EmoteMenu.gd
## Radial emote selector — 6 emotes arranged in a circle.
## Press Q to open/close. Click or press 1-6 to fire.
## Sends NetworkManager.send_emote(emote_key).

class_name EmoteMenu
extends Control

# Emote catalogue — key, display label, broadcast string
const EMOTES: Array = [
	{"key": "wave",      "label": "Wave",     "emoji": "[Wave]"},
	{"key": "thumbsup",  "label": "Thumbs up","emoji": "[+1]"},
	{"key": "clap",      "label": "Clap",     "emoji": "[Clap]"},
	{"key": "question",  "label": "Question", "emoji": "[?]"},
	{"key": "think",     "label": "Think",    "emoji": "[...]"},
	{"key": "party",     "label": "Party",    "emoji": "[Party]"},
]

const RADIUS: float = 68.0
const BTN_SIZE: Vector2 = Vector2(52, 52)

var _emote_btns: Array[Button] = []

# Signal emitted when an emote is selected
signal emote_selected(emote_key: String)

func _ready() -> void:
	# Anchor to center of screen
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background circle
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)   # transparent; buttons are self-styled
	bg.size = Vector2(200, 200)
	bg.position = Vector2(-100, -100)
	add_child(bg)

	# Spawn 6 buttons in a circle
	_emote_btns.clear()
	for i in EMOTES.size():
		var angle := (TAU / EMOTES.size()) * i - PI * 0.5  # start from top
		var offset := Vector2(cos(angle), sin(angle)) * RADIUS
		var btn := _make_emote_button(i, offset)
		add_child(btn)
		_emote_btns.append(btn)

func _make_emote_button(index: int, offset: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.position = offset - BTN_SIZE * 0.5
	btn.text = EMOTES[index]["emoji"] + "\n" + EMOTES[index]["label"]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 0.92)
	style.set_corner_radius_all(26)
	style.border_color = Color(0.4, 0.55, 0.75)
	style.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.22, 0.28, 0.42, 0.95)
	style_hover.border_color = Color(0.6, 0.8, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	btn.add_theme_constant_override("separation", 2)

	var capture_i := index
	btn.pressed.connect(func(): _fire_emote(capture_i))
	return btn

func _fire_emote(index: int) -> void:
	var emote_key: String = EMOTES[index]["key"]
	NetworkManager.send_emote(emote_key)
	emote_selected.emit(emote_key)
	queue_free()  # close menu after selection

# Handle number keys 1-6 for keyboard shortcut
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _fire_emote(0)
			KEY_2: _fire_emote(1)
			KEY_3: _fire_emote(2)
			KEY_4: _fire_emote(3)
			KEY_5: _fire_emote(4)
			KEY_6: _fire_emote(5)
			KEY_ESCAPE: queue_free()
```

---

### Task 6 — DeskEditor.gd (new file)

**File:** `scripts/ui/DeskEditor.gd`

```gdscript
## DeskEditor.gd
## Desk decoration editor — 4 columns × 3 rows = 12 slots.
## Press D while near own desk to open.
## Shows earned desk_items from PlayerData.earned_cosmetics["desk_items"].

class_name DeskEditor
extends PanelContainer

# 12-slot grid (4 col × 3 row)
const GRID_COLS: int = 4
const GRID_ROWS: int = 3
const SLOT_COUNT: int = 12

# Default available items for all players
const DEFAULT_ITEMS: Array = [
	{"id": "plant",       "name": "Plant"},
	{"id": "mug",         "name": "Coffee Mug"},
	{"id": "photo_frame", "name": "Photo Frame"},
	{"id": "sticky_note", "name": "Sticky Note"},
	{"id": "lamp",        "name": "Desk Lamp"},
	{"id": "cactus",      "name": "Cactus"},
]

var _layout: Array[String] = []   # 12 items, "" = empty
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

	# Title
	var title := Label.new()
	title.text = "Desk Decorator"
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.75, 0.9, 1.0)
	vbox.add_child(title)

	# Instructions
	var hint := Label.new()
	hint.text = "Chon item tu palette, sau do nhan o trong o de dat."
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.6, 0.6, 0.6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	# Desk grid (4×3)
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

	# Separator
	vbox.add_child(HSeparator.new())

	# Item palette label
	var palette_label := Label.new()
	palette_label.text = "Item Palette:"
	palette_label.add_theme_font_size_override("font_size", 11)
	palette_label.modulate = Color(0.7, 0.85, 1.0)
	vbox.add_child(palette_label)

	# Palette scroll
	var palette_scroll := ScrollContainer.new()
	palette_scroll.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(palette_scroll)

	var palette_flow := HBoxContainer.new()
	palette_scroll.add_child(palette_flow)

	_available_items = _get_available_items()
	_item_palette_btns.clear()

	# "Eraser" button
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
		var item := _available_items[i]
		var btn := Button.new()
		btn.text = item["name"]
		btn.custom_minimum_size = Vector2(80, 40)
		btn.toggle_mode = true
		var capture_i := i
		btn.pressed.connect(func():
			_selected_item_id = _available_items[capture_i]["id"]
			_update_palette_selection(capture_i + 1)  # +1 for eraser
		)
		palette_flow.add_child(btn)
		_item_palette_btns.append(btn)

	# Footer buttons
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
			var display_name := item_id.replace("_", " ").capitalize()
			btn.text = display_name
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
```

---

### Task 7 — RemotePlayer.gd: Emote Display + Profile Card Click

**File:** `scripts/world/RemotePlayer.gd`

Replace the entire file:

```gdscript
## RemotePlayer.gd
## Represents another player controlled by network input.
## Sprint 4: adds emote floating display + profile card click handling.

class_name RemotePlayer
extends CharacterBody2D

# ── Config — set before add_child ──
var player_id: String = ""
var display_name: String = "Unknown"
var avatar_config: Dictionary = {}
var is_npc_mode: bool = false

# ── Player metadata (filled by Campus from GameManager.employees) ──
var hr_title: String = ""
var department: String = ""
var status: String = "online"
var status_msg: String = ""

# ── Visual nodes ──
var _nameplate: Label = null
var _status_dot: ColorRect = null
var _body_rect: ColorRect = null
var _npc_badge: Label = null

# ── Emote display ──
var _emote_label: Label = null
var _emote_timer: float = 0.0
const EMOTE_DISPLAY_DURATION: float = 2.0

# ── Input area for click detection ──
var _click_area: Area2D = null

# ── Network position lerp ──
var _target_pos: Vector2 = Vector2.ZERO
const LERP_SPEED: float = 12.0

func _ready() -> void:
	add_to_group("remote_players")
	collision_layer = 4
	collision_mask = 0
	_build_visuals()
	_build_click_area()
	_target_pos = global_position
	# Connect to global emote signal
	NetworkManager.emote_received.connect(_on_emote_received)

func _build_visuals() -> void:
	_body_rect = ColorRect.new()
	_body_rect.size = Vector2(12, 16)
	_body_rect.position = Vector2(-6, -16)
	_body_rect.color = Color(0.4, 0.8, 0.4)
	add_child(_body_rect)

	_nameplate = Label.new()
	_nameplate.text = display_name
	_nameplate.position = Vector2(-30, -28)
	_nameplate.add_theme_font_size_override("font_size", 9)
	add_child(_nameplate)

	_status_dot = ColorRect.new()
	_status_dot.size = Vector2(6, 6)
	_status_dot.position = Vector2(6, -20)
	_status_dot.color = Color(0.2, 0.9, 0.2)
	add_child(_status_dot)

	_npc_badge = Label.new()
	_npc_badge.text = "[AI]"
	_npc_badge.position = Vector2(-12, -38)
	_npc_badge.add_theme_font_size_override("font_size", 8)
	_npc_badge.modulate = Color(1.0, 0.8, 0.0)
	_npc_badge.visible = false
	add_child(_npc_badge)

	# Emote label (starts hidden above avatar)
	_emote_label = Label.new()
	_emote_label.text = ""
	_emote_label.position = Vector2(-20, -50)
	_emote_label.add_theme_font_size_override("font_size", 14)
	_emote_label.modulate = Color(1.0, 1.0, 1.0, 0.0)  # invisible until triggered
	add_child(_emote_label)

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.collision_layer = 0
	_click_area.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 28)
	col.shape = shape
	col.position = Vector2(0, -14)
	_click_area.add_child(col)
	add_child(_click_area)
	_click_area.input_event.connect(_on_area_input_event)
	_click_area.input_pickable = true

func set_name_and_avatar(p_name: String, p_avatar: Dictionary) -> void:
	display_name = p_name
	avatar_config = p_avatar
	if _nameplate:
		_nameplate.text = p_name

func set_metadata(p_title: String, p_dept: String, p_status: String, p_msg: String) -> void:
	hr_title    = p_title
	department  = p_dept
	status      = p_status
	status_msg  = p_msg

func set_target_position(x: float, y: float) -> void:
	_target_pos = Vector2(x, y)

func _physics_process(delta: float) -> void:
	if not is_npc_mode:
		global_position = global_position.lerp(_target_pos, LERP_SPEED * delta)

	# Tick emote display timer
	if _emote_timer > 0.0:
		_emote_timer -= delta
		var alpha: float = clamp(_emote_timer / EMOTE_DISPLAY_DURATION, 0.0, 1.0)
		_emote_label.modulate.a = alpha
		if _emote_timer <= 0.0:
			_emote_label.text = ""
			_emote_label.modulate.a = 0.0

func enter_npc_mode() -> void:
	is_npc_mode = true
	status = "offline"
	if _status_dot:
		_status_dot.color = Color(0.5, 0.5, 0.5)
	if _npc_badge:
		_npc_badge.visible = true

func exit_npc_mode() -> void:
	is_npc_mode = false
	status = "online"
	if _status_dot:
		_status_dot.color = Color(0.2, 0.9, 0.2)
	if _npc_badge:
		_npc_badge.visible = false

# ── Emote handler ──────────────────────────────────────────
func _on_emote_received(from_id: String, emote: String) -> void:
	if from_id != player_id:
		return
	_show_emote(emote)

func _show_emote(emote_key: String) -> void:
	var display_text := _emote_key_to_text(emote_key)
	_emote_label.text = display_text
	_emote_label.modulate.a = 1.0
	_emote_timer = EMOTE_DISPLAY_DURATION

func _emote_key_to_text(key: String) -> String:
	match key:
		"wave":     return "[Wave]"
		"thumbsup": return "[+1]"
		"clap":     return "[Clap!]"
		"question": return "[?]"
		"think":    return "[...]"
		"party":    return "[Party!]"
		_:          return "[" + key + "]"

# ── Profile card click ─────────────────────────────────────
func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_open_profile_card()

func _open_profile_card() -> void:
	# Remove any existing card
	var existing := get_tree().get_first_node_in_group("profile_card")
	if existing:
		existing.queue_free()

	var card := load("res://scripts/ui/ProfileCard.gd").new()
	card.add_to_group("profile_card")
	get_tree().root.add_child(card)

	var data := {
		"player_id":    player_id,
		"display_name": display_name,
		"title":        hr_title,
		"department":   department,
		"status":       status,
		"status_msg":   status_msg,
		"achievements": [],  # fetched async below
		"is_npc":       is_npc_mode,
	}
	# Fill in achievements if this player is in employees dict
	var emp_data: Dictionary = GameManager.employees.get(player_id, {})
	data["achievements"] = emp_data.get("achievements", [])
	card.populate(data)

	# Position near this node
	var cam: Camera2D = get_viewport().get_camera_2d()
	card.position_near(self, cam)

	# Wire DM button → open ChatLog in DM mode
	card.dm_requested.connect(func(pid: String):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_dm"):
			hud.open_dm(pid)
	)
	# Wire View Desk button
	card.view_desk_requested.connect(func(pid: String):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_remote_desk"):
			hud.open_remote_desk(pid)
	)
```

---

### Task 8 — Campus.gd: Desk Proximity Trigger

**File:** `scripts/world/Campus.gd`

Add three things to the existing Campus.gd:
1. A desk zone dictionary (matching the engineering/design zone rects)
2. `_process()` to check if player is near their desk
3. A method to open the DeskEditor

Append to the end of `Campus.gd` (do NOT replace existing content — add after line 338):

```gdscript
# ── Desk proximity (Sprint 4) ─────────────────────────────────────────────────
# "Own desk" is a 60×40 px zone inside the player's department zone.
# We derive it from the department of PlayerData at runtime.

const _DESK_ZONE_MARGIN: float = 60.0  # how close before D key works
var _near_own_desk: bool = false
var _desk_editor_open: bool = false

func _process(_delta: float) -> void:
	if player_node == null:
		return
	_update_desk_proximity()
	# Handle D key
	if Input.is_action_just_pressed("ui_desk_editor") and _near_own_desk:
		_toggle_desk_editor()

func _update_desk_proximity() -> void:
	var dept: String = PlayerData.department.to_lower()
	var zone_key: String = _dept_to_zone_key(dept)
	if not _zones.has(zone_key):
		_near_own_desk = false
		return
	var zone_rect: Rect2 = _zones[zone_key]["rect"]
	# "Desk" is a small rect at the center of the zone
	var desk_center := zone_rect.get_center()
	var dist := player_node.global_position.distance_to(desk_center)
	_near_own_desk = dist < _DESK_ZONE_MARGIN
	# Show hint in HUD when near
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
	var editor := load("res://scripts/ui/DeskEditor.gd").new()
	editor.add_to_group("desk_editor")
	# Add to HUD layer so it draws above world
	var hud_layer := get_node_or_null("HUDLayer")
	if hud_layer:
		hud_layer.add_child(editor)
	else:
		add_child(editor)
	editor.closed.connect(func():
		_desk_editor_open = false
	)
	_desk_editor_open = true
```

Also add to `project.godot` input map — `ui_desk_editor` mapped to key D:
```ini
[input]
ui_desk_editor={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)]
}
```

---

### Task 9 — HUD.gd: Wire Emote Menu + Desk Editor Key + Emote Toast + DM/Desk helpers

**File:** `scripts/ui/HUD.gd`

Add the following to `HUD.gd`. These are additive changes — insert at the indicated positions.

#### 9.1 — Add vars (after existing vars block, before `func _ready`)

```gdscript
# ── Sprint 4 additions ──
var _emote_menu: Control = null
var _emote_toast_stack: VBoxContainer = null
```

#### 9.2 — In `_ready()`, add after `GameManager.room_booked.connect(...)`:

```gdscript
	NetworkManager.emote_received.connect(_on_emote_toast)
```

#### 9.3 — In `_build_ui()` or end of `_ready()`, create toast stack:

```gdscript
func _build_emote_toast_area() -> void:
	_emote_toast_stack = VBoxContainer.new()
	_emote_toast_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_emote_toast_stack.position = Vector2(-180, 60)
	_emote_toast_stack.custom_minimum_size = Vector2(160, 0)
	add_child(_emote_toast_stack)
```

Call `_build_emote_toast_area()` from `_build_ui()`.

#### 9.4 — Add `_unhandled_key_input` or extend existing one:

```gdscript
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_toggle_emote_menu()
```

#### 9.5 — Add emote menu toggle:

```gdscript
func _toggle_emote_menu() -> void:
	if is_instance_valid(_emote_menu):
		_emote_menu.queue_free()
		_emote_menu = null
		return
	_emote_menu = load("res://scripts/ui/EmoteMenu.gd").new()
	_emote_menu.set_anchors_preset(Control.PRESET_CENTER)
	_emote_menu.emote_selected.connect(func(_key: String): _emote_menu = null)
	add_child(_emote_menu)
```

#### 9.6 — Add emote toast handler:

```gdscript
func _on_emote_toast(from_id: String, emote: String) -> void:
	if _emote_toast_stack == null:
		return
	# Look up display name
	var name: String = from_id
	var emp_data: Dictionary = GameManager.employees.get(from_id, {})
	if emp_data.has("name"):
		name = emp_data["name"]
	var label := Label.new()
	label.text = name + ": " + _emote_to_text(emote)
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1.0, 0.9, 0.5)
	_emote_toast_stack.add_child(label)
	# Auto-remove after 3 seconds
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func _emote_to_text(key: String) -> String:
	match key:
		"wave":     return "[Wave]"
		"thumbsup": return "[+1]"
		"clap":     return "[Clap!]"
		"question": return "[?]"
		"think":    return "[...]"
		"party":    return "[Party!]"
		_:          return "[" + key + "]"
```

#### 9.7 — Add DM and Desk helpers:

```gdscript
# Open ChatLog pointing to a specific player DM thread
func open_dm(player_id: String) -> void:
	var chat := get_tree().get_first_node_in_group("chat_log")
	if chat and chat.has_method("open_dm_with"):
		chat.open_dm_with(player_id)
	# Make workspace panel visible on chat tab
	if workspace_panel:
		workspace_panel.visible = true

# Open a read-only view of another player's desk
func open_remote_desk(player_id: String) -> void:
	if not HttpManager.is_available():
		GameManager.notify("Khong the tai desk cua " + player_id, "error")
		return
	HttpManager.get_request(
		"/players/" + player_id + "/desk",
		{},
		func(status: int, body: Dictionary):
			if status != 200:
				GameManager.notify("Khong tim thay desk", "warning")
				return
			_show_remote_desk_view(player_id, body.get("desk_layout", []))
	)

func _show_remote_desk_view(player_id: String, layout: Array) -> void:
	# Display a simple read-only panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320, 240)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Desk of " + player_id
	title.add_theme_font_size_override("font_size", 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	for i in 12:
		var lbl := Label.new()
		var item_id: String = layout[i] if i < layout.size() else ""
		lbl.text = item_id.replace("_", " ").capitalize() if item_id != "" else "[  ]"
		lbl.custom_minimum_size = Vector2(64, 48)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		grid.add_child(lbl)
	vbox.add_child(grid)

	var close_btn := Button.new()
	close_btn.text = "Dong"
	close_btn.pressed.connect(panel.queue_free)
	vbox.add_child(close_btn)

func set_zone_hint(hint_key: String) -> void:
	# Extend existing zone label to show desk hint
	if not is_instance_valid(_zone_label):
		return
	match hint_key:
		"near_own_desk":
			if not _zone_label.text.contains("[D]"):
				_zone_label.text = _zone_label.text + "  [D] Desk Editor"
		_:
			# Strip hint if present
			var base := _zone_label.text.split("  [D]")[0]
			_zone_label.text = base
```

---

## Execution Order

Run tasks in this order (each is independently testable):

| # | Task | Test |
|---|------|------|
| 1 | Backend achievements module | `cd server && npm test` |
| 2 | PlayerData.gd polling + desk | Godot: check `[PlayerData]` print, call `PlayerData.poll_achievements()` from console |
| 3 | AvatarCustomizer.gd full rebuild | Shift+A in-game — see all tabs, live preview updates |
| 4 | ProfileCard.gd | Click any RemotePlayer — see card float near avatar |
| 5 | EmoteMenu.gd | Press Q — radial menu appears; press 1-6 or click |
| 6 | DeskEditor.gd | Press D near own desk — 4×3 grid editor opens |
| 7 | RemotePlayer.gd update | Emote fires → floating text appears over remote avatar |
| 8 | Campus.gd desk proximity | Walk to own department zone → zone label shows `[D] Desk Editor` |
| 9 | HUD.gd wiring | Q opens EmoteMenu; emote toast appears top-right when self fires emote |

---

## Self-Review

### 1. Spec Coverage Check

| Spec Item | Covered | Where |
|-----------|---------|-------|
| 4A — Live avatar preview | Yes | Task 3, `_refresh_preview()`, `_build_preview_strip()` |
| 4A — Body type / skin / hair / eye sliders | Yes | Task 3, `_build_appearance_tab()` |
| 4A — Outfit selector (only unlocked) | Yes | Task 3, `_create_outfit_card()` checks `PlayerData.unlocked_outfits` |
| 4A — Accessory slot with locked padlock display | Yes | Task 3, `_build_accessories_tab()`, `_create_accessory_card()` |
| 4A — Save → `PlayerData.update_avatar()` + broadcast | Yes | Task 3, `_on_save()` calls `PlayerData.update_avatar()` + `NetworkManager.send_status()` |
| 4A — `GET /achievements/my` backend endpoint | Yes | Task 1, `achievements.js` route + tests |
| 4B — `/achievements/sync` polling every 60 min | Yes | Task 2, `_process()` + `poll_achievements()` + `_on_achievements_sync_response()` |
| 4B — New achievements → `unlock_achievement()` + toast | Yes | Task 2, calls `GameManager.notify(...)` for each new achievement |
| 4B — One-way pull (read-only) | Yes | Task 2, never POSTs to achievements |
| 4C — Profile card popup on avatar click | Yes | Task 4 (ProfileCard.gd) + Task 7 (RemotePlayer click area) |
| 4C — Name, title, department | Yes | Task 4, `populate()` |
| 4C — Status + status message | Yes | Task 4, status dot + `_status_msg_label` |
| 4C — Top 3 achievement badges | Yes | Task 4, `_badge_row` with 3-item loop |
| 4C — Online/Offline + "AI-assisted" NPC badge | Yes | Task 4, `_npc_badge` + status dot color |
| 4C — Quick action: Send DM | Yes | Task 4, `dm_requested` signal → Task 9 `open_dm()` |
| 4C — Quick action: View Desk | Yes | Task 4, `view_desk_requested` signal → Task 9 `open_remote_desk()` |
| 4D — D key at own desk triggers editor | Yes | Task 8 (Campus proximity) + Task 9 (`ui_desk_editor` input action) |
| 4D — 4×3 item grid | Yes | Task 6, `GRID_COLS=4`, `GRID_ROWS=3` |
| 4D — Items from `PlayerData.earned_cosmetics["desk_items"]` | Yes | Task 6, `_get_available_items()` |
| 4D — Save → `PlayerData.desk_decorations` + `POST /players/me/desk` | Yes | Task 2 (`update_desk_layout`) + Task 1 (POST route) |
| 4D — Other players see your desk (GET /players/:id/desk) | Yes | Task 1 (GET route) + Task 9 (`open_remote_desk`) |
| 4E — Q key radial menu | Yes | Task 5 (EmoteMenu.gd) + Task 9 (`_toggle_emote_menu`) |
| 4E — 6 emotes with labels | Yes | Task 5, `EMOTES` array with 6 entries |
| 4E — Click or 1-6 keyboard | Yes | Task 5, `_unhandled_key_input` + button press |
| 4E — `NetworkManager.send_emote(key)` | Yes | Task 5, `_fire_emote()` |
| 4E — Floating emoji over avatar 2 seconds | Yes | Task 7, `_show_emote()` + `_emote_timer` fade |
| 4E — HUD emote toast | Yes | Task 9, `_on_emote_toast()` + `_emote_toast_stack` |

**All 26 spec items covered.**

### 2. Placeholder Scan

- No "TODO", "TBD", "similar to above", or stub functions found.
- All functions have complete bodies.
- All constants are concrete values.

### 3. Type Consistency

| Check | Status |
|-------|--------|
| `_layout: Array[String]` in DeskEditor | Typed array, uses `.fill("")` |
| `target_achievements: Array[String]` in ProfileCard | Typed array |
| `_emote_btns: Array[Button]` in EmoteMenu | Typed array |
| `skin_tone` / `hair_color` / `body_type` / `eye_color` / `hair_style` — all `int` | Consistent with `PlayerData.avatar_config` |
| `EMOTE_DISPLAY_DURATION: float` | Matches `_emote_timer: float` |
| `NetworkManager.send_emote(String)` | Matches existing NetworkManager signature in Sprint 3 |
| Backend `desk_layout` — Array of 12 strings | Matches GDScript `Array[String]` length 12 |
| `HttpManager.get_request(url, headers, callback)` | Consistent with Sprint 3 HttpManager signature |
