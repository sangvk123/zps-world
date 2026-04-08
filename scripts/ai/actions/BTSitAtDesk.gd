## BTSitAtDesk.gd
## NPC đi đến điểm ngẫu nhiên trong zone, ngồi làm việc một lúc rồi đứng dậy.
## Luôn trả SUCCESS (không fail).
class_name BTSitAtDesk
extends BTAction

const ARRIVE_DIST := 5.0
const SIT_MIN     := 15.0
const SIT_MAX     := 40.0
const MARGIN      := 20.0

var _sit_target:  Vector2
var _sit_duration: float = 0.0
var _sit_timer:   float  = 0.0
var _sitting:     bool   = false

func _enter() -> void:
	_sitting      = false
	_sit_timer    = 0.0
	_sit_duration = randf_range(SIT_MIN, SIT_MAX)

	var emp := agent as Employee
	if emp == null:
		return

	var zone: Rect2 = blackboard.get_var("zone_rect", Rect2())
	if zone.has_area():
		_sit_target = Vector2(
			randf_range(zone.position.x + MARGIN, zone.end.x - MARGIN),
			randf_range(zone.position.y + MARGIN, zone.end.y - MARGIN)
		)
	else:
		var angle := randf() * TAU
		_sit_target = emp.position + Vector2(cos(angle), sin(angle)) * randf_range(30.0, 60.0)

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	if not _sitting:
		# ── Phase 0: walk to desk (nav-aware) ──
		if emp.nav_move_toward(_sit_target, ARRIVE_DIST):
			_sitting = true
			emp.start_sit()
		return RUNNING

	# ── Phase 1: sit and work ──
	_sit_timer += delta
	if _sit_timer >= _sit_duration:
		emp.stop_sit()
		return SUCCESS
	return RUNNING

func _exit() -> void:
	var emp := agent as Employee
	if emp:
		emp.stop_sit()
	_sitting = false
