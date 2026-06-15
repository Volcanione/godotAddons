extends Resource
class_name MASTargetQuery

# 查询目标。
# 基类不做任何查找，具体游戏或子类可以实现自身、范围、射线、鼠标点等目标来源。
func query(source: Node, target_data: Dictionary = {}, adapter: MASGameAdapter = null) -> Array[Node]:
	return []
