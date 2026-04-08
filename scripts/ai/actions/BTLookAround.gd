## BTLookAround.gd
## NPC đứng yên và quay nhìn vài hướng khác nhau trong vài giây.
## Tạo cảm giác NPC đang quan sát / suy nghĩ / chờ đợi.
class_name BTLookAround
extends BTAction

const LOOK_MIN      := 3.0   # tổng thời gian nhìn quanh (giây)
const LOOK_MAX      := 6.0
const TURN_INTERVAL := 0.9   # đổi hướng mỗi N giây

var _total_timer:  float = 0.0
var _turn_timer:   float = 0.0

func _enter() -> void:
	_total_timer = randf_range(LOOK_MIN, LOOK_MAX)
	_turn_timer  = 0.0
	var emp := agent as Employee
	if emp:
		emp.velocity = Vector2.ZERO

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	emp.velocity = Vector2.ZERO

	_total_timer -= delta
	if _total_timer <= 0.0:
		return SUCCESS

	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn_timer = TURN_INTERVAL
		# Quay mặt sang một hướng ngẫu nhiên (8 hướng chính) — dùng idle anim
		var angle := float(randi() % 8) * (TAU / 8.0)
		emp.face_direction(Vector2(cos(angle), sin(angle)))

	return RUNNING
