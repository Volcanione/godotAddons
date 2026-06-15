extends Node
class_name MASTagComponent

@export var tags: Array[StringName] = []

# 判断是否拥有标签。
# 标签可用于阵营、免疫、Boss、飞行单位等技能筛选逻辑。
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

# 添加标签。
# 状态、装备或场景逻辑可以动态添加标签影响技能筛选。
func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)

# 移除标签。
# 临时免疫或临时控制状态结束时可以调用该方法。
func remove_tag(tag: StringName) -> void:
	tags.erase(tag)
