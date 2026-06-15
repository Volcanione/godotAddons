extends Resource
class_name MASModifierDef

@export var id: StringName
@export var display_name: String = ""
@export var damage_add: float = 0.0
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var radius_add: float = 0.0
@export var duration_add: float = 0.0
@export var projectile_count_add: int = 0
@export var status_duration_multiplier: float = 1.0
@export var extra_effects: Array[Resource] = []
@export var replace_behavior: Resource

# 把词条修改应用到运行时数值上。
# 这里不修改原始 AbilityDef，保证 Rogue 加成只影响本次运行时。
func apply_to_runtime_stats(stats: MASRuntimeStats) -> void:
	if stats == null:
		return
	stats.damage_add += damage_add
	stats.damage_multiplier *= damage_multiplier
	stats.cooldown_multiplier *= cooldown_multiplier
	stats.radius_add += radius_add
	stats.duration_add += duration_add
	stats.projectile_count_add += projectile_count_add
	stats.status_duration_multiplier *= status_duration_multiplier
	for effect in extra_effects:
		stats.extra_effects.append(effect)
	if replace_behavior != null:
		stats.replace_behavior = replace_behavior
