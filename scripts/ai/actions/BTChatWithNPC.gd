## BTChatWithNPC.gd
## Tìm đồng nghiệp gần nhất trong SCAN_RANGE, tiến lại gần, đứng nói chuyện.
## FAILURE nếu không tìm được partner hoặc không thể tiếp cận trong MAX_APPROACH giây.
## SUCCESS sau khi đã chat đủ CHAT_DURATION giây.
class_name BTChatWithNPC
extends BTAction

const SCAN_RANGE    := 80.0   # pixel radius to look for a partner
const APPROACH_STOP := 14.0   # stop this many px away from partner
const MAX_APPROACH  := 8.0    # give up approaching after this many seconds
const CHAT_MIN      := 4.0
const CHAT_MAX      := 10.0

var _partner:       Node2D = null
var _approach_timer: float = 0.0
var _chat_timer:    float  = 0.0
var _chat_duration: float  = 0.0
var _chatting:      bool   = false

func _enter() -> void:
	_partner        = null
	_approach_timer = 0.0
	_chat_timer     = 0.0
	_chatting       = false
	_chat_duration  = randf_range(CHAT_MIN, CHAT_MAX)

	var emp := agent as Employee
	if emp == null:
		return

	# Scan "employees" group for nearest non-busy NPC within range
	var nearest: Node2D = null
	var nearest_dist: float = SCAN_RANGE
	for body: Node in emp.get_tree().get_nodes_in_group("employees"):
		if body == emp:
			continue
		var other := body as Employee
		if other == null or other.is_being_talked_to:
			continue
		var d: float = emp.global_position.distance_to(other.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest      = other
	_partner = nearest

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null or _partner == null or not is_instance_valid(_partner):
		return FAILURE

	var to_partner: Vector2 = _partner.global_position - emp.global_position

	if not _chatting:
		# ── Phase 0: approach (nav-aware) ──
		_approach_timer += delta
		if _approach_timer > MAX_APPROACH:
			return FAILURE   # couldn't reach partner

		if emp.nav_move_toward(_partner.global_position, APPROACH_STOP):
			_chatting = true
			emp.update_npc_facing(to_partner.normalized() * 0.5)
		return RUNNING

	# ── Phase 1: chat ──
	emp.velocity = Vector2.ZERO
	emp.update_npc_facing(to_partner.normalized() * 0.5)  # keep facing partner
	_chat_timer += delta
	if _chat_timer >= _chat_duration:
		return SUCCESS
	return RUNNING

func _exit() -> void:
	_partner  = null
	_chatting = false
