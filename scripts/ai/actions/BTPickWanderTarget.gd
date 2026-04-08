## BTPickWanderTarget.gd
## Chọn random point trong zone_rect của NPC.
## 12% cơ hội chọn điểm ngoài zone (cross-zone wander).
## Trả SUCCESS ngay lập tức sau khi set wander_target.
class_name BTPickWanderTarget
extends BTAction

const MARGIN           := 12.0   # padding khỏi edge của zone
const CROSS_ZONE_CHANCE := 0.25   # xác suất đi sang zone khác
# Map bounds (matches Campus.gd MAP_W / MAP_H)
const MAP_MIN := Vector2(20.0, 20.0)
const MAP_MAX := Vector2(1173.0, 876.0)

func _tick(_delta: float) -> Status:
	var zone: Rect2 = blackboard.get_var("zone_rect", Rect2())

	# Cross-zone: grow zone boundary by 100px then clamp to map
	if zone.has_area() and randf() < CROSS_ZONE_CHANCE:
		var wide := zone.grow(100.0)
		wide.position = wide.position.clamp(MAP_MIN, MAP_MAX)
		wide = wide.intersection(Rect2(MAP_MIN, MAP_MAX - MAP_MIN))
		if wide.has_area():
			blackboard.set_var("wander_target", Vector2(
				randf_range(wide.position.x, wide.end.x),
				randf_range(wide.position.y, wide.end.y)
			))
			return SUCCESS

	if not zone.has_area():
		# Không có zone → wander quanh vị trí hiện tại
		var angle := randf() * TAU
		var dist  := randf_range(20.0, 50.0)
		blackboard.set_var("wander_target",
			(agent as Node2D).position + Vector2(cos(angle), sin(angle)) * dist)
		return SUCCESS

	var target := Vector2(
		randf_range(zone.position.x + MARGIN, zone.end.x - MARGIN),
		randf_range(zone.position.y + MARGIN, zone.end.y - MARGIN)
	)
	blackboard.set_var("wander_target", target)
	return SUCCESS
