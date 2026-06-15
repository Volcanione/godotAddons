extends MASTargetQuery
class_name MASSelfTargetQuery

# 查询释放者自身。
# 自身 Buff、治疗、护盾等技能可以复用这个目标查询。
func query(source: Node, target_data: Dictionary = {}, adapter: MASGameAdapter = null) -> Array[Node]:
	if source == null:
		return []
	return [source]
