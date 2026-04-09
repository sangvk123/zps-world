## BTWalkToTarget.gd
## Di chuyển NPC đến blackboard["wander_target"] dùng NavigationAgent2D.
## RUNNING khi đang đi, SUCCESS khi đến nơi hoặc hết timeout.
## Stuck detection: theo dõi khoảng cách đến target — nếu không giảm → bỏ target.
class_name BTWalkToTarget
extends BTAction

const MAX_WALK_TIME    := 7.0    # hard timeout — give up after 7s
const STUCK_CHECK_INT  := 1.0    # kiểm tra mỗi 1 giây
const STUCK_SHRINK_MIN := 6.0    # khoảng cách đến target phải giảm ≥ 6px/giây

var _timer:          float   = 0.0
var _stuck_timer:    float   = 0.0
var _last_target_dist: float = INF   # khoảng cách đến target lần kiểm tra trước

func _enter() -> void:
	_timer           = 0.0
	_stuck_timer     = 0.0
	_last_target_dist = INF

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	_timer       += delta
	_stuck_timer += delta

	var target: Vector2 = blackboard.get_var("wander_target", emp.position)
	var dist_to_target := emp.global_position.distance_to(target)

	# Hard timeout
	if _timer >= MAX_WALK_TIME:
		emp.velocity = Vector2.ZERO
		emp.update_npc_facing(Vector2.ZERO)
		return SUCCESS

	# Stuck detection: kiểm tra xem khoảng cách đến target có giảm không
	if _stuck_timer >= STUCK_CHECK_INT:
		var shrink := _last_target_dist - dist_to_target
		_last_target_dist = dist_to_target
		_stuck_timer      = 0.0
		# Nếu khoảng cách không giảm đủ → bị kẹt (trượt dọc tường)
		if shrink < STUCK_SHRINK_MIN:
			emp.velocity = Vector2.ZERO
			emp.update_npc_facing(Vector2.ZERO)
			return SUCCESS   # pick a new wander target next cycle
	elif _last_target_dist == INF:
		# Khởi tạo lần đầu
		_last_target_dist = dist_to_target

	if emp.nav_move_toward(target):
		emp.update_npc_facing(Vector2.ZERO)
		return SUCCESS
	return RUNNING
