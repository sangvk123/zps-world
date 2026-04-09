## PlayerData.gd
## Persistent player profile data — Autoload singleton
## Handles avatar config, outfit system, desk layout, preferences

extends Node

signal login_complete

# ── Auth state ──
var is_logged_in: bool = false
var jwt_token_cached: String = ""

# ── Core identity ──
var player_id: String = ""
var display_name: String = ""
var department: String = ""
var hr_title: String = ""
var nameplate_title: String = ""
var zps_callsign: String = ""
var zps_class: String = "artisan"

# ── Avatar config (matches AvatarData resource structure) ──
var avatar_config: Dictionary = {
	"body_type": 0,       # 0=slim, 1=medium, 2=broad
	"skin_tone": 1,       # 0-4
	"hair_style": 2,      # 0-7
	"hair_color": 0,      # 0-5
	"eye_color": 1,       # 0-4
	# Cosmetic slots (earn via achievements)
	"outfit_id": "work_casual",
	"accessories": [],
	"cape_id": "",
	"pet_id": "",
	"aura_feet": "",
	"aura_body": "",
	"animation_tier": 0,  # 0=static, 1=breathing, 2=shimmer, 3=entrance, 4=signature
}

# ── Outfit rotation system ──
# Each outfit is unlocked via achievements. Player can set "daily outfit" per day.
var unlocked_outfits: Array[String] = ["work_casual", "initiate_class"]
var outfit_schedule: Dictionary = {}  # "YYYY-MM-DD" -> outfit_id
var current_outfit: String = "work_casual"

# ── Desk data ──
var desk_id: String = ""
var desk_decorations: Array[String] = []  # decoration item ids placed on desk

# ── Achievements cache ──
var earned_achievements: Array[String] = []
var earned_cosmetics: Dictionary = {}  # slot -> Array[String]

# ── AI Portrait ──
var avatar_portrait_base64: String = ""   # PNG base64 từ avatar-maker API
var avatar_portrait_style: String = ""    # "chibi" | "anime" | "3d-pixar"

# ── Preferences ──
var show_callsign: bool = true
var show_ranking: bool = false
var show_current_quest: bool = true
var ai_agent_enabled: bool = true
var ai_agent_context: String = ""  # What the AI agent knows about you to answer for you

var _achievement_poll_timer: float = 0.0
const ACHIEVEMENT_POLL_INTERVAL: float = 3600.0  # 60 minutes
var _last_achievement_sync: String = "1970-01-01T00:00:00Z"

const SAVE_PATH = "user://player_data.cfg"

func _ready() -> void:
	load_data()
	_set_todays_outfit()
	set_process(true)
	if display_name != "":
		print("[PlayerData] Loaded — Player: %s (%s)" % [display_name, hr_title])

# ── Outfit rotation ──
func _set_todays_outfit() -> void:
	var today = Time.get_date_string_from_system()
	if outfit_schedule.has(today):
		current_outfit = outfit_schedule[today]
	elif not unlocked_outfits.is_empty():
		# Auto-cycle through unlocked outfits by day of year
		var dt = Time.get_datetime_dict_from_system()
		var day_of_year = dt["month"] * 30 + dt["day"]
		current_outfit = unlocked_outfits[day_of_year % unlocked_outfits.size()]
	avatar_config["outfit_id"] = current_outfit

func set_outfit_for_today(outfit_id: String) -> void:
	if outfit_id in unlocked_outfits:
		var today = Time.get_date_string_from_system()
		outfit_schedule[today] = outfit_id
		current_outfit = outfit_id
		avatar_config["outfit_id"] = outfit_id
		GameManager.avatar_updated.emit(player_id, avatar_config)
		save_data()

# ── Achievement unlock ──
func unlock_achievement(achievement_id: String, cosmetic_rewards: Dictionary = {}) -> void:
	if achievement_id not in earned_achievements:
		earned_achievements.append(achievement_id)
		# Grant cosmetics
		for slot in cosmetic_rewards:
			if not earned_cosmetics.has(slot):
				earned_cosmetics[slot] = []
			var item = cosmetic_rewards[slot]
			if item not in earned_cosmetics[slot]:
				earned_cosmetics[slot].append(item)
		save_data()
		GameManager.notify("Achievement unlocked: %s" % achievement_id, "achievement")

# ── Avatar update ──
func update_avatar(new_config: Dictionary) -> void:
	for key in new_config:
		avatar_config[key] = new_config[key]
	save_data()
	GameManager.avatar_updated.emit(player_id, avatar_config)

# ── AI Portrait ──
func set_portrait(base64: String, style: String) -> void:
	avatar_portrait_base64 = base64
	avatar_portrait_style = style
	save_data()
	GameManager.avatar_updated.emit(player_id, avatar_config)

# ── AI Agent context ──
func set_ai_context(context: String) -> void:
	ai_agent_context = context
	save_data()

func get_avatar_dict() -> Dictionary:
	return avatar_config.duplicate()

func get_ai_context_prompt() -> String:
	return """Bạn là AI đại diện cho nhân viên %s, %s tại phòng ban %s của ZPS Game Studio.
Bạn đang thay mặt họ khi họ không online.

Thông tin về họ:
- Callsign ZPS: %s
- Công việc hiện tại: %s
- Context thêm: %s

Hãy trả lời ngắn gọn, thân thiện, như chính người đó đang nói.
Nếu không biết thông tin cụ thể, hãy nói: "Mình không có thông tin cụ thể về điều đó, bạn có thể nhắn trực tiếp khi mình online nhé!"
""" % [
		display_name, hr_title, department,
		zps_callsign if zps_callsign != "" else "(chưa có callsign)",
		GameManager.employees.get(player_id, {}).get("current_task", "Đang bận"),
		ai_agent_context
	]

# ── Achievement polling ──
func _process(delta: float) -> void:
	_achievement_poll_timer += delta
	if _achievement_poll_timer >= ACHIEVEMENT_POLL_INTERVAL:
		_achievement_poll_timer = 0.0
		poll_achievements()

func poll_achievements() -> void:
	if HttpManager.jwt_token.is_empty():
		return
	var endpoint := "achievements/sync?last_synced=" + _last_achievement_sync
	HttpManager.get_request(endpoint)
	HttpManager.response_received.connect(_on_achievements_sync_response, CONNECT_ONE_SHOT)

func _on_achievements_sync_response(endpoint: String, data: Variant) -> void:
	if not endpoint.begins_with("achievements/sync"):
		return
	if not data is Dictionary:
		return
	var new_achievements: Array = (data as Dictionary).get("new_achievements", [])
	if new_achievements.is_empty():
		return
	for ach: Variant in new_achievements:
		if not ach is Dictionary:
			continue
		var ach_dict := ach as Dictionary
		var ach_id: String = ach_dict.get("id", "")
		if ach_id.is_empty() or ach_id in earned_achievements:
			continue
		var cosmetics: Dictionary = ach_dict.get("unlocks", {})
		unlock_achievement(ach_id, cosmetics)
		GameManager.notify("Achievement mo khoa: %s" % ach_dict.get("title", ach_id), "achievement")
	_last_achievement_sync = Time.get_datetime_string_from_system(true)

# ── Desk layout ──
func update_desk_layout(layout: Array) -> void:
	desk_decorations.clear()
	for item in layout:
		desk_decorations.append(str(item))
	save_data()
	if not HttpManager.jwt_token.is_empty():
		HttpManager.post("players/me/desk", {"desk_layout": desk_decorations})

## Xóa session hiện tại — gọi từ nút Đăng xuất trong Player Profile
func logout() -> void:
	is_logged_in = false
	jwt_token_cached = ""
	HttpManager.jwt_token = ""
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("auth", "jwt_token", "")
	config.save(SAVE_PATH)

# ── Persistence ──
func save_data() -> void:
	var config = ConfigFile.new()
	config.set_value("identity", "player_id", player_id)
	config.set_value("identity", "display_name", display_name)
	config.set_value("identity", "department", department)
	config.set_value("identity", "hr_title", hr_title)
	config.set_value("identity", "nameplate_title", nameplate_title)
	config.set_value("identity", "zps_callsign", zps_callsign)
	config.set_value("identity", "zps_class", zps_class)
	config.set_value("auth", "jwt_token", jwt_token_cached)
	config.set_value("avatar", "config", avatar_config)
	config.set_value("outfit", "unlocked", unlocked_outfits)
	config.set_value("outfit", "schedule", outfit_schedule)
	config.set_value("outfit", "current", current_outfit)
	config.set_value("achievements", "earned", earned_achievements)
	config.set_value("achievements", "cosmetics", earned_cosmetics)
	config.set_value("desk", "id", desk_id)
	config.set_value("desk", "decorations", desk_decorations)
	config.set_value("prefs", "show_callsign", show_callsign)
	config.set_value("prefs", "show_ranking", show_ranking)
	config.set_value("prefs", "show_current_quest", show_current_quest)
	config.set_value("prefs", "ai_agent_enabled", ai_agent_enabled)
	config.set_value("prefs", "ai_agent_context", ai_agent_context)
	config.set_value("portrait", "base64", avatar_portrait_base64)
	config.set_value("portrait", "style", avatar_portrait_style)
	config.save(SAVE_PATH)

func load_data() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		# First run — show setup dialog
		_first_run_setup()
		return
	player_id = config.get_value("identity", "player_id", player_id)
	display_name = config.get_value("identity", "display_name", display_name)
	department = config.get_value("identity", "department", department)
	hr_title = config.get_value("identity", "hr_title", hr_title)
	nameplate_title = config.get_value("identity", "nameplate_title", hr_title)
	zps_callsign = config.get_value("identity", "zps_callsign", zps_callsign)
	zps_class = config.get_value("identity", "zps_class", zps_class)
	jwt_token_cached = config.get_value("auth", "jwt_token", "")
	avatar_config = config.get_value("avatar", "config", avatar_config)
	unlocked_outfits = config.get_value("outfit", "unlocked", unlocked_outfits)
	outfit_schedule = config.get_value("outfit", "schedule", outfit_schedule)
	current_outfit = config.get_value("outfit", "current", current_outfit)
	earned_achievements = config.get_value("achievements", "earned", earned_achievements)
	earned_cosmetics = config.get_value("achievements", "cosmetics", earned_cosmetics)
	desk_id = config.get_value("desk", "id", desk_id)
	desk_decorations = config.get_value("desk", "decorations", desk_decorations)
	show_callsign = config.get_value("prefs", "show_callsign", show_callsign)
	show_ranking = config.get_value("prefs", "show_ranking", show_ranking)
	show_current_quest = config.get_value("prefs", "show_current_quest", show_current_quest)
	ai_agent_enabled = config.get_value("prefs", "ai_agent_enabled", ai_agent_enabled)
	ai_agent_context = config.get_value("prefs", "ai_agent_context", ai_agent_context)
	avatar_portrait_base64 = config.get_value("portrait", "base64", "")
	avatar_portrait_style = config.get_value("portrait", "style", "")
	# If we have a saved jwt, mark as logged in (session restore)
	if jwt_token_cached != "" and player_id != "":
		HttpManager.jwt_token = jwt_token_cached
		is_logged_in = true

func _first_run_setup() -> void:
	# No default identity — LoginDialog will call apply_login_data() after auth
	pass

## Called by LoginDialog after successful POST /auth/login
func apply_login_data(token: String, emp: Dictionary) -> void:
	jwt_token_cached = token
	HttpManager.jwt_token = token
	player_id    = emp.get("id",         "unknown")
	display_name = emp.get("name",        "")
	department   = emp.get("department",  "")
	hr_title         = emp.get("title",           "")
	nameplate_title  = emp.get("nameplate_title", hr_title)
	zps_class    = emp.get("zps_class",   "artisan")
	zps_callsign = emp.get("id",          player_id)
	var char_id: int = emp.get("char_id", 0)
	avatar_config["char_id"]   = char_id
	avatar_config["outfit_id"] = emp.get("avatar", {}).get("outfit_id", "work_casual")
	is_logged_in = true
	save_data()
	_set_todays_outfit()
	login_complete.emit()
