extends Resource
class_name MASStatusEffectDef

enum StackRule {
	REFRESH_DURATION,
	STACK_INTENSITY,
	STACK_DURATION,
	REPLACE_IF_STRONGER,
	IGNORE_IF_ACTIVE,
	INDEPENDENT_INSTANCES,
}

@export var status_id: StringName
@export var display_name: String = ""
@export var duration: float = 1.0
@export var tick_interval: float = 0.0
@export var stack_rule: StackRule = StackRule.REFRESH_DURATION
@export var max_stacks: int = 1
@export var stat_modifiers: Dictionary = {}
@export var periodic_effects: Array[Resource] = []
@export var control_flags: Array[StringName] = []
@export var immunity_tags: Array[StringName] = []
@export var dispel_tags: Array[StringName] = []

# 返回状态持续时间的安全值。
# 负数持续时间容易造成状态立即移除或永不清理，因此这里统一钳制为非负数。
func get_safe_duration() -> float:
	return maxf(duration, 0.0)

# 返回状态 tick 间隔的安全值。
# `0` 表示没有周期 tick，只作为属性修改或控制状态存在。
func get_safe_tick_interval() -> float:
	return maxf(tick_interval, 0.0)
