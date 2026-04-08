## BTIdleInPlace.gd
## RUNNING trong khi đếm ngược idle_remaining.
## wait_min / wait_max: khoảng thời gian random (giây).
## wait_min = wait_max = 0.0 → đợi vô hạn (dùng cho Talking branch).
class_name BTIdleInPlace
extends BTAction

@export var wait_min: float = 2.0
@export var wait_max: float = 5.0

func _enter() -> void:
	var emp := agent as Employee
	if emp:
		emp.velocity = Vector2.ZERO
		emp.update_npc_facing(Vector2.ZERO)   # switch run→idle anim, preserve last direction
	if wait_min <= 0.0 and wait_max <= 0.0:
		# Vô hạn — Talking branch tự thoát khi BTIsTalking trả FAILURE
		blackboard.set_var("idle_remaining", INF)
	else:
		var t := randf_range(wait_min, wait_max)
		blackboard.set_var("idle_remaining", t)

func _tick(delta: float) -> Status:
	var remaining: float = blackboard.get_var("idle_remaining", 0.0)
	if remaining == INF:
		return RUNNING  # Talking branch: đợi mãi
	remaining -= delta
	blackboard.set_var("idle_remaining", remaining)
	if remaining <= 0.0:
		return SUCCESS
	return RUNNING
