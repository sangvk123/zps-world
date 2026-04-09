## BTFacePlayer.gd
## NPC đứng yên, quay mặt về player, show interact hint.
## RUNNING khi player gần (BTIsPlayerNearby giữ branch này active).
## SUCCESS → không bao giờ trả, branch tự thoát khi condition fail.
class_name BTFacePlayer
extends BTAction

func _enter() -> void:
	var emp := agent as Employee
	if emp:
		emp.velocity = Vector2.ZERO
		emp.show_interact_hint()

func _exit() -> void:
	var emp := agent as Employee
	if emp:
		emp.hide_interact_hint()

func _tick(_delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	var player := agent.get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var dir := player.global_position - emp.global_position
		emp.face_direction(dir)

	emp.velocity = Vector2.ZERO
	return RUNNING
