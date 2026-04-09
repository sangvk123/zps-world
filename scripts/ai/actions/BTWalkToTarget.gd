## BTWalkToTarget.gd
## Di chuyển NPC đến blackboard["wander_target"] dùng NavigationAgent2D.
## RUNNING khi đang đi, SUCCESS khi đến nơi hoặc hết timeout.
## Có stuck-detection: nếu NPC không di chuyển đủ trong 2 giây → bỏ qua target hiện tại.
class_name BTWalkToTarget
extends BTAction

const MAX_WALK_TIME    := 10.0   # hard timeout — give up after 10s
const STUCK_CHECK_INT  := 2.0    # check every 2 s if we moved enough
const STUCK_MIN_DIST   := 8.0    # must move ≥ 8 px in STUCK_CHECK_INT seconds

var _timer:         float = 0.0
var _stuck_timer:   float = 0.0
var _last_pos:      Vector2 = Vector2.ZERO

func _enter() -> void:
	_timer       = 0.0
	_stuck_timer = 0.0
	var emp := agent as Employee
	_last_pos = emp.global_position if emp else Vector2.ZERO

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	_timer       += delta
	_stuck_timer += delta

	# Hard timeout
	if _timer >= MAX_WALK_TIME:
		emp.velocity = Vector2.ZERO
		emp.update_npc_facing(Vector2.ZERO)
		return SUCCESS

	# Stuck detection — if barely moved in STUCK_CHECK_INT seconds, abandon target
	if _stuck_timer >= STUCK_CHECK_INT:
		var moved := emp.global_position.distance_to(_last_pos)
		_last_pos    = emp.global_position
		_stuck_timer = 0.0
		if moved < STUCK_MIN_DIST:
			emp.velocity = Vector2.ZERO
			emp.update_npc_facing(Vector2.ZERO)
			return SUCCESS   # pick a new wander target next cycle

	var target: Vector2 = blackboard.get_var("wander_target", emp.position)
	if emp.nav_move_toward(target):
		emp.update_npc_facing(Vector2.ZERO)
		return SUCCESS
	return RUNNING
