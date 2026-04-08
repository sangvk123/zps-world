## BTWalkToTarget.gd
## Di chuyển NPC đến blackboard["wander_target"] dùng NavigationAgent2D.
## RUNNING khi đang đi, SUCCESS khi đến nơi hoặc hết timeout.
class_name BTWalkToTarget
extends BTAction

const MAX_WALK_TIME := 8.0
var _timer: float = 0.0

func _enter() -> void:
	_timer = 0.0

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE
	_timer += delta
	if _timer >= MAX_WALK_TIME:
		return SUCCESS   # give up — pick a new target next cycle
	var target: Vector2 = blackboard.get_var("wander_target", emp.position)
	return SUCCESS if emp.nav_move_toward(target) else RUNNING
