extends Node2D
class_name MASAbilityRuntime

signal finished(runtime: MASAbilityRuntime)
signal effect_applied(effect: Resource, context: MASEffectContext)

var ability_def: MASAbilityDef
var caster: Node
var target_data: Dictionary = {}
var adapter: MASGameAdapter
var runtime_stats: MASRuntimeStats
var hit_tracker := MASHitTracker.new()
var elapsed: float = 0.0
var is_active: bool = false
var custom_data: Dictionary = {}

# 初始化 Runtime。
# AbilityComponent 创建 Runtime 后调用该方法注入技能配置、释放者、目标数据和适配器。
func setup(new_ability_def: MASAbilityDef, new_caster: Node, new_target_data: Dictionary, new_adapter: MASGameAdapter, modifiers: Array[Resource] = []) -> void:
	ability_def = new_ability_def
	caster = new_caster
	target_data = new_target_data
	adapter = new_adapter
	if ability_def != null:
		runtime_stats = ability_def.create_runtime_stats(modifiers)
	else:
		runtime_stats = MASRuntimeStats.new()

# 启动技能运行时。
# 这里统一调用 Behavior.start，让弹道、范围、近战等行为从同一个入口开始。
func start() -> void:
	if ability_def == null:
		finish()
		return
	is_active = true
	var behavior := _get_behavior()
	if behavior != null:
		behavior.start(self)
	elif target_data.has("target"):
		apply_effects_to_target(target_data["target"])
	elif target_data.has("targets"):
		apply_effects_to_targets(target_data["targets"])
	_spawn_cast_and_active_visuals()
	if runtime_stats.get_final_duration() <= 0.0 and behavior == null:
		finish()

# 每帧推进技能运行时。
# Godot 自动调用 `_process(delta)`，Runtime 再把更新分发给 Behavior，并检查持续时间。
func _process(delta: float) -> void:
	if not is_active:
		return
	elapsed += delta
	var behavior := _get_behavior()
	if behavior != null:
		behavior.tick(self, delta)
	var final_duration := runtime_stats.get_final_duration()
	if final_duration > 0.0 and elapsed >= final_duration:
		finish()

# 对单个目标执行技能效果。
# 命中限制、上下文创建和效果执行都集中在这里，避免每个 Behavior 重复写命中结算。
func apply_effects_to_target(target: Node, hit_position: Vector2 = Vector2.ZERO) -> void:
	if target == null or ability_def == null:
		return
	if ability_def.target_filter != null and not ability_def.target_filter.allows_target(caster, target, adapter):
		return
	if not hit_tracker.can_hit(target, elapsed, ability_def.hit_rule):
		return
	hit_tracker.record_hit(target, elapsed)
	var base_context := _build_context(target, hit_position)
	for effect in ability_def.get_effects_for_runtime(runtime_stats):
		if effect == null or not effect.has_method("apply"):
			continue
		base_context.effect_id = effect.get_effect_id() if effect.has_method("get_effect_id") else &"effect"
		effect.apply(base_context, adapter)
		_spawn_hit_visual(base_context)
		effect_applied.emit(effect, base_context)

# 对多个目标执行技能效果。
# 范围技能和多段技能可以传入候选目标列表，由该方法逐个复用单目标结算。
func apply_effects_to_targets(targets: Array, hit_position: Vector2 = Vector2.ZERO) -> void:
	for target in targets:
		if target is Node:
			apply_effects_to_target(target, hit_position)

# 结束技能运行时。
# 结束时通知 Behavior 清理，并用 queue_free 让 Godot 在安全时机移除节点。
func finish() -> void:
	if not is_active:
		return
	is_active = false
	var behavior := _get_behavior()
	if behavior != null:
		behavior.stop(self)
	_spawn_end_visual()
	finished.emit(self)
	queue_free()

# 取消技能运行时。
# 外部控制、死亡、切场景时可以调用；当前和 finish 共用清理逻辑。
func cancel() -> void:
	finish()

# 获取当前技能行为。
# RuntimeStats 可以替换行为，用于 Rogue 词条把普通火球替换成分裂火球等效果。
func _get_behavior() -> MASAbilityBehavior:
	if runtime_stats != null and runtime_stats.replace_behavior is MASAbilityBehavior:
		return runtime_stats.replace_behavior
	if ability_def != null:
		return ability_def.behavior
	return null

# 生成起手和主体视觉。
# Behavior.start 之后 Runtime 位置已经被弹道或范围行为修正，此时生成视觉能拿到正确位置。
func _spawn_cast_and_active_visuals() -> void:
	var visual_def := _get_visual_def()
	if visual_def == null:
		return
	visual_def.spawn_cast(self)
	visual_def.spawn_active(self)

# 生成命中特效。
# 命中特效使用效果上下文定位，确保多目标技能能在每个目标处生成独立反馈。
func _spawn_hit_visual(context: MASEffectContext) -> void:
	var visual_def := _get_visual_def()
	if visual_def == null:
		return
	visual_def.spawn_hit(context)

# 生成结束特效。
# 结束特效在 Runtime queue_free 前创建，并挂到当前场景，保证消散动画不被立即删除。
func _spawn_end_visual() -> void:
	var visual_def := _get_visual_def()
	if visual_def == null:
		return
	visual_def.spawn_end(self)

# 读取视觉配置。
# 使用 Resource + 方法检查，避免 headless 检查时新 class_name 尚未进入类型表导致解析失败。
func _get_visual_def() -> Resource:
	if ability_def == null:
		return null
	var visual_def = ability_def.get("visual_def")
	if visual_def is Resource and visual_def.has_method("spawn_active"):
		return visual_def
	return null

# 构建效果上下文。
# 这里集中填入释放者、技能 ID、阵营、命中点和方向，方便效果层和适配层统一读取。
func _build_context(target: Node, hit_position: Vector2) -> MASEffectContext:
	var direction := Vector2.ZERO
	if caster is Node2D and target is Node2D:
		direction = (target.global_position - caster.global_position).normalized()
	return MASEffectContext.new().setup({
		"source_actor": caster,
		"instigator": self,
		"target_actor": target,
		"ability_id": ability_def.id,
		"faction": adapter.get_faction(caster) if adapter != null else &"neutral",
		"hit_position": hit_position,
		"direction": direction,
		"runtime_stats": runtime_stats,
		"tags": ability_def.cue_tags,
	})
