extends Resource
class_name MASHitRuleDef

@export var max_hit_count: int = 0
@export var max_hit_count_per_target: int = 1
@export var rehit_interval: float = 0.0
@export var tick_interval: float = 0.0
@export var pierce_count: int = 0
@export var hit_once_per_cast: bool = true

# 判断整体命中次数是否还没有超过上限。
# `0` 表示不限制总次数，适合持续范围技能或光环技能。
func allows_total_hit(total_hit_count: int) -> bool:
	if max_hit_count <= 0:
		return true
	return total_hit_count < max_hit_count

# 判断单个目标是否还可以被同一次技能再次命中。
# `0` 表示不限制单目标次数，通常配合 `rehit_interval` 使用。
func allows_target_hit(target_hit_count: int) -> bool:
	if max_hit_count_per_target <= 0:
		return true
	return target_hit_count < max_hit_count_per_target

# 返回安全的 tick 间隔。
# Godot 的 `_process(delta)` 每帧都会调用，持续范围技能需要用 tick 间隔避免每帧扫目标。
func get_safe_tick_interval() -> float:
	return maxf(tick_interval, 0.0)
