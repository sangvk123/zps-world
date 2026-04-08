## AIAgent.gd
## AI Agent system — Autoload singleton
## Powers: Employee offline replies, workspace queries, AI assistant
## API key is managed by AIConfig (never hardcoded here).
## Conversation history is managed by ConversationMemory (multi-turn support).

extends Node

# ── Signals ──
signal response_ready(response: String, context_id: String)
signal response_error(error: String, context_id: String)

func _ready() -> void:
	if AIConfig.use_mock:
		print("[AIAgent] Mock mode — add API key via AIConfig.save_api_key(key)")
	else:
		print("[AIAgent] Real API mode — %s" % AIConfig.MODEL)

# ═══════════════════════════════════════════════════════════════
# Public query interface
# ═══════════════════════════════════════════════════════════════

## Ask a question to an employee's AI agent (multi-turn aware).
## conv_id for history is the employee_id.
func ask_employee_agent(employee_id: String, question: String) -> void:
	var context_id := "emp_%s_%d" % [employee_id, Time.get_ticks_msec()]
	var employee   := GameManager.get_employee(employee_id)
	if employee.is_empty():
		response_error.emit("Employee not found", context_id)
		return
	ConversationMemory.add_user(employee_id, question)
	var system_prompt := _build_employee_prompt(employee)
	_send_query(system_prompt, ConversationMemory.get_messages(employee_id), context_id, employee_id)

## Ask the workspace assistant (room booking, HR info, etc.).
func ask_workspace_assistant(question: String, context: String = "") -> void:
	var context_id := "workspace_%d" % Time.get_ticks_msec()
	ConversationMemory.add_user("workspace", question)
	var system_prompt := _build_workspace_prompt(context)
	_send_query(system_prompt, ConversationMemory.get_messages("workspace"), context_id, "workspace")

## Ask about your own work status (AI answers AS you when offline).
func ask_self_agent(question: String) -> void:
	var context_id := "self_%d" % Time.get_ticks_msec()
	ConversationMemory.add_user("self", question)
	var system_prompt := PlayerData.get_ai_context_prompt()
	_send_query(system_prompt, ConversationMemory.get_messages("self"), context_id, "self")

# ═══════════════════════════════════════════════════════════════
# Prompt builders
# ═══════════════════════════════════════════════════════════════

func _build_employee_prompt(employee: Dictionary) -> String:
	return """Bạn là AI đại diện cho %s, %s tại phòng ban %s của ZPS Game Studio.
Bạn đang thay mặt họ khi họ không online.

Thông tin:
- Công việc hiện tại: %s
- Trạng thái: %s

Hãy trả lời như chính người đó, ngắn gọn (1-3 câu), thân thiện.
Nếu không biết thông tin cụ thể, hãy nói: "Bạn có thể nhắn trực tiếp khi mình online nhé!"
Nhớ lại ngữ cảnh cuộc trò chuyện trước đó nếu có.
""" % [
		employee.get("name", "?"),
		employee.get("title", "?"),
		employee.get("department", "?"),
		employee.get("current_task", "Đang bận"),
		"Online" if employee.get("is_online", false) else "Không online hiện tại",
	]

func _build_workspace_prompt(context: String) -> String:
	var rooms_info := ""
	for room_id: String in GameManager.meeting_rooms:
		var room: Dictionary = GameManager.meeting_rooms[room_id]
		rooms_info += "- %s: capacity %d, equipment: %s\n" % [
			room["name"], room["capacity"],
			", ".join(room["equipment"])
		]
	return """Bạn là workspace assistant của ZPS Game Studio (~300 người).
Bạn giúp nhân viên về:
- Đặt phòng họp
- Tìm thông tin đồng nghiệp
- Tra cứu quy trình HR
- Hỏi về các khoá học nội bộ

Phòng họp hiện có:
%s
Context thêm: %s

Trả lời ngắn gọn, hữu ích, bằng tiếng Việt.
Nhớ ngữ cảnh cuộc trò chuyện trước đó nếu có.
""" % [rooms_info, context]

# ═══════════════════════════════════════════════════════════════
# HTTP layer
# ═══════════════════════════════════════════════════════════════

func _send_query(
		system_prompt: String,
		messages: Array,
		context_id: String,
		conv_id: String) -> void:
	if AIConfig.use_mock:
		_mock_response(messages, context_id, conv_id)
		return

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result, code, _hdrs, resp_body):
		_on_request_completed(result, code, resp_body, context_id, conv_id, http)
	)

	var headers := [
		"Content-Type: application/json",
		"x-api-key: %s" % AIConfig.api_key,
		"anthropic-version: 2023-06-01",
	]

	# Ensure messages is non-empty (API requires at least one message)
	var send_messages: Array = messages if not messages.is_empty() else [{"role": "user", "content": ""}]

	var body := JSON.stringify({
		"model":      AIConfig.MODEL,
		"max_tokens": AIConfig.MAX_TOKENS,
		"system":     system_prompt,
		"messages":   send_messages,
	})

	var err := http.request(AIConfig.API_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		response_error.emit("Request failed (err=%d)" % err, context_id)

func _on_request_completed(
		result: int,
		code: int,
		body: PackedByteArray,
		context_id: String,
		conv_id: String,
		http_node: HTTPRequest) -> void:
	http_node.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var err_msg := "HTTP error %d" % code
		if code == 401:
			err_msg = "API key không hợp lệ (401)"
		elif code == 429:
			err_msg = "Quá nhiều request (429) — thử lại sau"
		response_error.emit(err_msg, context_id)
		return

	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		response_error.emit("JSON parse error", context_id)
		return

	var text: String = json.get("content", [{}])[0].get("text", "Xin lỗi, mình không hiểu câu hỏi của bạn.")
	ConversationMemory.add_assistant(conv_id, text)
	response_ready.emit(text, context_id)

# ═══════════════════════════════════════════════════════════════
# Mock responses (prototype / no-API-key mode)
# ═══════════════════════════════════════════════════════════════

func _mock_response(messages: Array, context_id: String, conv_id: String) -> void:
	await get_tree().create_timer(0.7).timeout

	# Use the last user message for context-aware response
	var question := ""
	for msg: Dictionary in messages:
		if msg.get("role", "") == "user":
			question = msg.get("content", "")

	var response := _pick_mock_response(question, conv_id)
	ConversationMemory.add_assistant(conv_id, response)
	response_ready.emit(response, context_id)

func _pick_mock_response(question: String, conv_id: String) -> String:
	var q := question.to_lower()

	# Workspace-specific responses
	if conv_id == "workspace" or context_id_is_workspace(conv_id):
		if "phòng" in q or "room" in q or "họp" in q:
			return "Bạn vào Workspace Panel (H) → Book Room để đặt phòng nhé! Phòng Alpha và Beta đang trống hôm nay."
		if "sprint" in q or "task" in q:
			return "Sprint 4 đang ở 65%% — Engineering team đang bứt phá cuối tuần!"
		return "Mình có thể giúp bạn đặt phòng hoặc xem sprint status. Bạn cần gì?"

	# Employee-specific responses
	if "đang làm" in q or "task" in q or "sprint" in q:
		return "Mình đang trong sprint này rồi, khoảng 2-3 ngày nữa sẽ xong!"
	if "khi nào" in q or "when" in q or "deadline" in q:
		return "Deadline tuần này! Mình đang push hết sức. Bạn cần gì gấp không?"
	if "giúp" in q or "help" in q:
		return "Được chứ! Để lại chi tiết đây, mình sẽ xem khi xong việc nhé!"

	var generic := [
		"Mình đang bận với task hiện tại, nhưng bạn có thể để lại tin nhắn nhé!",
		"Câu hỏi hay đấy! Mình sẽ confirm lại với team rồi phản hồi bạn sau.",
		"Mình đang focus vào delivery tuần này, chat lại sau 5pm nhé!",
		"Để mình check rồi update bạn — khoảng 1-2 tiếng nữa nhé!",
	]
	return generic[randi() % generic.size()]

func context_id_is_workspace(conv_id: String) -> bool:
	return conv_id == "workspace" or conv_id == "self"
