## BTIsTalking.gd
## Trả về SUCCESS nếu NPC đang bị talk to, FAILURE nếu không.
## Dùng ở P1 của behavior tree để block toàn bộ movement.
class_name BTIsTalking
extends BTCondition

func _tick(_delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE
	return SUCCESS if emp.is_being_talked_to else FAILURE
