## GameManager.gd
## Global game state manager — Autoload singleton
## Handles scene transitions, game state, event bus

extends Node

# ── Signals (Event Bus) ──
@warning_ignore("unused_signal")
signal employee_interacted(employee_id: String)
@warning_ignore("unused_signal")
signal desk_interacted(desk_id: String)
@warning_ignore("unused_signal")
signal meeting_room_interacted(room_id: String)
@warning_ignore("unused_signal")
signal chat_message_sent(from_id: String, message: String)
signal room_booked(room_id: String, time_slot: String, booker_id: String)
signal leave_requested(employee_id: String, leave_data: Dictionary)
@warning_ignore("unused_signal")
signal avatar_updated(employee_id: String, avatar_config: Dictionary)
signal notification_received(message: String, type: String)
@warning_ignore("unused_signal")
signal remote_player_joined(id: String)
@warning_ignore("unused_signal")
signal remote_player_left(id: String)

# ── State ──
enum GameState { LOADING, EXPLORING, CHATTING, CUSTOMIZING, WORKSPACE_PANEL }
var current_state: GameState = GameState.LOADING

# ── World data ──
var office_data: Dictionary = {}
var employees: Dictionary = {}     # employee_id -> EmployeeData dict
var meeting_rooms: Dictionary = {} # room_id -> RoomData dict
var desks: Dictionary = {}         # desk_id -> DeskData dict
var remote_players: Dictionary = {}  # id -> RemotePlayer node

# ── Sprint / project data (fetched from Task Manager mock) ──
var active_sprints: Array[Dictionary] = []
var active_quests: Array[Dictionary] = []

func _ready() -> void:
	_load_mock_data()
	print("[GameManager] Ready — ZPS World v0.1 Prototype")

func _load_mock_data() -> void:
	# ── Procedurally generated employee data (seed 12345 for reproducibility) ──
	seed(12345)

	# Name pools
	var last_names: Array[String] = [
		"Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan",
		"Vũ", "Đặng", "Bùi", "Đỗ", "Hồ", "Ngô", "Dương", "Lý",
		"Đinh", "Tô", "Võ", "Cao", "Tăng",
	]
	var male_first_names: Array[String] = [
		"Minh", "Hùng", "Tuấn", "Dũng", "Khoa", "Đức", "Phúc", "Long",
		"Hưng", "Bảo", "Thắng", "Nam", "Quân", "Hoàng", "Tùng", "Nghĩa",
		"Trọng", "Tiến", "Lâm", "Thành", "Cường", "Trung", "Đạt", "Hải",
		"Phong", "Sơn", "Tú", "Hiếu", "Anh", "Vũ", "Quốc", "Kiên",
		"Duy", "Khôi",
	]
	var female_first_names: Array[String] = [
		"Linh", "Hương", "Lan", "Ngọc", "Hoa", "Mai", "Trang", "Thảo",
		"Phương", "Vy", "Chi", "Thu", "Yến", "Hạnh", "Nhi", "Như",
		"Thanh", "Bích", "Hằng", "Diễm", "Ngân", "Quỳnh", "Khánh", "Trúc",
		"Ly", "Nhung", "Thư", "Hà", "Giang", "Xuân", "Châu", "Dung",
		"Hiền", "Tiên",
	]

	# Department pools
	var departments: Array[String] = [
		"Engineering", "Design", "Product", "HR", "Data", "Marketing",
	]

	# Titles per department [junior/mid, senior, lead]
	var dept_titles: Dictionary = {
		"Engineering": ["Engineer", "Senior Engineer", "Lead Engineer"],
		"Design":      ["Designer", "Senior Designer", "Art Lead"],
		"Product":     ["Product Manager", "PM", "CPO"],
		"HR":          ["HR Specialist", "Recruiter", "HR Lead"],
		"Data":        ["Data Analyst", "Data Engineer", "Data Lead"],
		"Marketing":   ["Marketing Manager", "Content Creator", "Marketing Lead"],
	}

	# Class names per department (for avatar)
	var dept_class: Dictionary = {
		"Engineering": "engineer",
		"Design":      "artisan",
		"Product":     "strategist",
		"HR":          "analyst",
		"Data":        "analyst",
		"Marketing":   "creator",
	}

	# Outfit per department
	var dept_outfit: Dictionary = {
		"Engineering": "work_casual",
		"Design":      "creative",
		"Product":     "formal",
		"HR":          "work_casual",
		"Data":        "work_casual",
		"Marketing":   "creative",
	}

	# Feature/module/screen name pool used in task templates
	var features: Array[String] = [
		"Quest Engine", "Inventory System", "Avatar Creator", "Social Hub",
		"Leaderboard", "Live Events", "Payment Gateway", "Analytics Dashboard",
	]

	# Task templates per department — use %s for feature slot
	var dept_tasks: Dictionary = {
		"Engineering": [
			"Building %s — Sprint 4",
			"Reviewing PR for %s",
			"Debugging %s",
		],
		"Design": [
			"Designing UI for %s",
			"Creating assets for %s",
			"Prototyping %s",
		],
		"Product": [
			"Planning Q2 roadmap",
			"Writing PRD for %s",
			"Analyzing user feedback",
		],
		"HR": [
			"Conducting interviews for %s",
			"Onboarding new members",
			"Planning team building",
		],
		"Data": [
			"Analyzing %s dashboard",
			"Building data pipeline for %s",
			"A/B test analysis",
		],
		"Marketing": [
			"Creating campaign for %s",
			"Writing blog post",
			"Planning social media",
		],
	}

	# Seed the employees dict with the mandatory player entry + named NPCs
	employees = {
		"player": {
			"id": "player",
			"name": PlayerData.display_name,
			"department": PlayerData.department,
			"title": "Master of the Watch",
			"current_task": "Designing ZPS World prototype",
			"is_online": true,
			"avatar": PlayerData.avatar_config,
		},
		"hieupt": {
			"id":           "hieupt",
			"name":         "Hiếu PT",
			"gender":       "male",
			"department":   "Product",
			"title":        "CPO — Chief Product Officer",
			"current_task": "Reviewing Q2 roadmap & ZPS World Vision",
			"is_online":    true,
			"char_id":      61,
			"avatar": {
				"body_type":  0,
				"skin":       1,
				"hair":       2,
				"outfit":     "formal",
				"class_name": "strategist",
			},
			"workspace": {
				"fake_chat": [
					{"sender": "Hiếu PT", "msg": "Hey! Bạn đã chơi thử ZPS World chưa? 😄"},
					{"sender": "Hiếu PT", "msg": "Mình đang cần review lại luồng onboarding — bạn có thể help không?"},
					{"sender": "Hiếu PT", "msg": "Deadline Q2 roadmap là 15/4, nhớ update Jira nhé!"},
					{"sender": "Hiếu PT", "msg": "Idea mới: thêm daily quest system vào ZPS World, align với OKR Q2."},
				],
			},
		},
	}

	# Generate emp_001 … emp_300
	for i: int in range(1, 301):
		var emp_id: String = "emp_%03d" % i

		# Gender: ~40 % male, ~60 % female
		var is_male: bool = (randi() % 10) < 4
		var gender: String = "male" if is_male else "female"

		# Name
		var last_name: String  = last_names[randi() % last_names.size()]
		var first_name: String
		if is_male:
			first_name = male_first_names[randi() % male_first_names.size()]
		else:
			first_name = female_first_names[randi() % female_first_names.size()]
		var full_name: String = last_name + " " + first_name

		# Department & derived fields
		var dept: String         = departments[randi() % departments.size()]
		var title_pool: Array    = dept_titles[dept]
		var title: String        = title_pool[randi() % title_pool.size()]
		var outfit: String       = dept_outfit[dept]
		var class_name_val: String = dept_class[dept]

		# Task
		var task_pool: Array = dept_tasks[dept]
		var task_template: String = task_pool[randi() % task_pool.size()]
		var feature: String  = features[randi() % features.size()]
		var current_task: String
		if "%s" in task_template:
			current_task = task_template % feature
		else:
			current_task = task_template

		# Online: ~70 % true
		var is_online: bool = (randi() % 10) < 7

		# Avatar
		var body_type: int = randi() % 2
		var skin: int      = randi() % 5
		var hair: int      = randi() % 8
		var char_id: int   = (randi() % 60) + 1

		employees[emp_id] = {
			"id":           emp_id,
			"name":         full_name,
			"gender":       gender,
			"department":   dept,
			"title":        title,
			"current_task": current_task,
			"is_online":    is_online,
			"avatar": {
				"body_type":  body_type,
				"skin":       skin,
				"hair":       hair,
				"outfit":     outfit,
				"class_name": class_name_val,
			},
			"char_id": char_id,
		}

	meeting_rooms = {
		"room_alpha": {
			"id": "room_alpha", "name": "Room Alpha",
			"capacity": 8, "equipment": ["Projector", "Whiteboard"],
			"schedule": [],
		},
		"room_beta": {
			"id": "room_beta", "name": "Room Beta",
			"capacity": 4, "equipment": ["TV Screen"],
			"schedule": [],
		},
		"room_dragon": {
			"id": "room_dragon", "name": "Dragon's Den",
			"capacity": 20, "equipment": ["Full AV", "Streaming Setup"],
			"schedule": [],
		},
		"room_gamma": {
			"id": "room_gamma", "name": "Room Gamma",
			"capacity": 10, "equipment": ["Whiteboard", "TV Screen"],
			"schedule": [],
		},
		"room_delta": {
			"id": "room_delta", "name": "Room Delta",
			"capacity": 10, "equipment": ["Projector", "Whiteboard"],
			"schedule": [],
		},
	}

	active_sprints = [
		{
			"id": "sprint_4", "name": "Sprint 4 — Quest Engine",
			"team": "Engineering", "progress": 0.65,
			"deadline": "April 8, 2026", "tasks_done": 13, "tasks_total": 20,
		},
		{
			"id": "sprint_art_q2", "name": "Q2 Art Sprint",
			"team": "Art", "progress": 0.40,
			"deadline": "April 15, 2026", "tasks_done": 8, "tasks_total": 20,
		},
		{
			"id": "sprint_design_q2", "name": "Q2 Design Sprint",
			"team": "Design", "progress": 0.30,
			"deadline": "April 22, 2026", "tasks_done": 6, "tasks_total": 20,
		},
		{
			"id": "sprint_data_q1", "name": "Q1 Data Audit",
			"team": "Data", "progress": 0.80,
			"deadline": "April 5, 2026", "tasks_done": 16, "tasks_total": 20,
		},
	]

# ── State machine ──
func set_state(new_state: GameState) -> void:
	current_state = new_state

func is_state(state: GameState) -> bool:
	return current_state == state

# ── Employee helpers ──
func get_employee(id: String) -> Dictionary:
	return employees.get(id, {})

func get_online_employees() -> Array:
	return employees.values().filter(func(e): return e.get("is_online", false))

func get_employees_by_department(dept: String) -> Array:
	return employees.values().filter(func(e): return e.get("department", "") == dept)

# ── Meeting room helpers ──
func book_room(room_id: String, time_slot: String, booker_id: String) -> bool:
	if not meeting_rooms.has(room_id):
		return false
	var room = meeting_rooms[room_id]
	# Check conflict
	for slot in room["schedule"]:
		if slot["time"] == time_slot:
			return false
	room["schedule"].append({"time": time_slot, "booker": booker_id})
	room_booked.emit(room_id, time_slot, booker_id)
	notification_received.emit(
		"Room %s booked for %s!" % [room["name"], time_slot],
		"success"
	)
	return true

# ── Leave request ──
func request_leave(leave_data: Dictionary) -> void:
	leave_requested.emit(PlayerData.player_id, leave_data)
	notification_received.emit(
		"Leave request submitted for %s" % leave_data.get("dates", ""),
		"info"
	)

# ── Notification helper ──
func notify(message: String, type: String = "info") -> void:
	notification_received.emit(message, type)
