## BTIsPlayerNearby.gd
## SUCCESS nếu player trong vòng DETECT_RANGE pixels.
## NPC sẽ quay mặt nhìn player khi condition này true.
class_name BTIsPlayerNearby
extends BTCondition

const DETECT_RANGE := 60.0

func _tick(_delta: float) -> Status:
	var player := agent.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return FAILURE
	var dist: float = (agent as Node2D).global_position.distance_to(player.global_position)
	return SUCCESS if dist <= DETECT_RANGE else FAILURE
