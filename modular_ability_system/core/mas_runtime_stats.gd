extends RefCounted
class_name MASRuntimeStats

var cooldown: float = 0.0
var duration: float = 0.0
var damage_add: float = 0.0
var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var radius_add: float = 0.0
var duration_add: float = 0.0
var projectile_count_add: int = 0
var status_duration_multiplier: float = 1.0
var extra_effects: Array[Resource] = []
var replace_behavior: Resource

# 返回最终冷却时间。
# 冷却倍率可能来自装备或 Rogue 词条，这里统一计算，避免修改原始 AbilityDef。
func get_final_cooldown() -> float:
	return maxf(cooldown * cooldown_multiplier, 0.0)

# 返回最终持续时间。
# 范围技能和状态技能会读取这个值来决定 Runtime 何时自动清理。
func get_final_duration() -> float:
	return maxf(duration + duration_add, 0.0)

# 返回最终伤害数值。
# 伤害加成和倍率在运行时合成，保证 Resource 模板可以被多个角色复用。
func get_final_damage(base_damage: float) -> float:
	return maxf((base_damage + damage_add) * damage_multiplier, 0.0)
