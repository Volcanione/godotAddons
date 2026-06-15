extends Node
class_name MASAttributeSet

@export var attributes: Dictionary = {}

# 读取属性值。
# 技能系统通过统一入口取攻击力、移速、冷却缩减等属性，避免直接访问角色变量。
func get_attribute(attribute_id: StringName, default_value: float = 0.0) -> float:
	return float(attributes.get(attribute_id, default_value))

# 设置属性值。
# 具体游戏可以在初始化角色或装备变化时写入基础属性。
func set_attribute(attribute_id: StringName, value: float) -> void:
	attributes[attribute_id] = value

# 修改属性值。
# Buff 或拾取物可以调用这个入口做简单数值变化，复杂状态仍建议走 MASStatusReceiver。
func add_attribute(attribute_id: StringName, amount: float) -> void:
	set_attribute(attribute_id, get_attribute(attribute_id) + amount)
