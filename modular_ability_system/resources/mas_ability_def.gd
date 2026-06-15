extends Resource
class_name MASAbilityDef

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var cooldown: float = 1.0
@export var energy_cost: float = 0.0
@export var cast_time: float = 0.0
@export var duration: float = 0.0
@export var behavior: MASAbilityBehavior
@export var target_filter: MASTargetFilterDef
@export var hit_rule: MASHitRuleDef
@export var effects: Array[Resource] = []
@export var visual_def: Resource
@export var animation_key: StringName
@export var cue_tags: Array[StringName] = []

# 创建技能运行时数值。
# 原始 AbilityDef 是模板，不能被 Rogue 加成或临时 Buff 直接修改。
func create_runtime_stats(modifiers: Array[Resource] = []) -> MASRuntimeStats:
	var stats := MASRuntimeStats.new()
	stats.cooldown = get_safe_cooldown()
	stats.duration = get_safe_duration()
	for modifier in modifiers:
		if modifier != null and modifier.has_method("apply_to_runtime_stats"):
			modifier.apply_to_runtime_stats(stats)
	return stats

# 返回安全冷却时间。
# Godot Timer 和冷却字典都不应该处理负数冷却，因此统一钳制为非负数。
func get_safe_cooldown() -> float:
	return maxf(cooldown, 0.0)

# 返回安全持续时间。
# `0` 表示瞬时技能，由 Behavior 或 Runtime 立即完成。
func get_safe_duration() -> float:
	return maxf(duration, 0.0)

# 返回完整效果列表。
# 运行时词条可能追加额外效果，所以这里把基础效果和 runtime extra effects 合并。
func get_effects_for_runtime(stats: MASRuntimeStats = null) -> Array[Resource]:
	var result: Array[Resource] = []
	for effect in effects:
		if effect != null:
			result.append(effect)
	if stats != null:
		for effect in stats.extra_effects:
			if effect != null:
				result.append(effect)
	return result
