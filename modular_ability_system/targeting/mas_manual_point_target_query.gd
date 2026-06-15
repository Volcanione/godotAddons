extends MASTargetQuery
class_name MASManualPointTargetQuery

# 读取手动目标点。
# 这个查询不返回目标节点，只把 `point` 作为范围技能 Runtime 的位置数据使用。
func get_point(source: Node, target_data: Dictionary = {}) -> Vector2:
	if target_data.has("point"):
		return target_data["point"]
	if source is Node2D:
		return source.global_position
	return Vector2.ZERO
