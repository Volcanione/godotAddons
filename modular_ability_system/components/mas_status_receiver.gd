extends Node
class_name MASStatusReceiver

signal status_applied(status_id: StringName, status_def: MASStatusEffectDef, stack_count: int)
signal status_removed(status_id: StringName)
signal status_tick(status_id: StringName, status_def: MASStatusEffectDef)

var active_statuses: Dictionary = {}

# 每帧更新状态剩余时间。
# 使用 `_process(delta)` 是因为状态持续时间和周期 tick 不依赖物理碰撞，跟随普通帧更新即可。
func _process(delta: float) -> void:
	_update_statuses(delta)

# 添加或刷新一个状态。
# 技能效果只负责请求添加状态，具体叠加和刷新规则统一在接收组件里处理。
func apply_status(status_def: MASStatusEffectDef, context: MASEffectContext = null) -> void:
	if status_def == null or status_def.status_id == &"":
		return
	if _is_immune_to_status(status_def):
		return
	var status_id := status_def.status_id
	if not active_statuses.has(status_id):
		_add_new_status(status_def, context)
		return
	_apply_stack_rule(status_def, context)

# 移除指定状态。
# 驱散、死亡、场景切换时可以调用该方法清理状态。
func remove_status(status_id: StringName) -> void:
	if not active_statuses.has(status_id):
		return
	active_statuses.erase(status_id)
	status_removed.emit(status_id)

# 判断目标是否拥有某个状态。
# AI、UI、控制逻辑可以用它查询眩晕、减速、燃烧等状态是否存在。
func has_status(status_id: StringName) -> bool:
	return active_statuses.has(status_id)

# 获取状态叠层数量。
# 伤害、减速强度或 UI 层数显示都可以读取这个值。
func get_status_stack_count(status_id: StringName) -> int:
	if not active_statuses.has(status_id):
		return 0
	var data: Dictionary = active_statuses[status_id]
	if data.has("instances"):
		return int(data["instances"].size())
	return int(data.get("stacks", 0))

# 获取属性修正总和。
# 当前返回加法修正，后续如果需要乘法修正可以扩展数据结构。
func get_stat_modifier(stat_id: StringName) -> float:
	var total := 0.0
	for data in active_statuses.values():
		if data.has("instances"):
			for instance in data["instances"]:
				var instance_def: MASStatusEffectDef = instance.get("def")
				if instance_def != null and instance_def.stat_modifiers.has(stat_id):
					total += float(instance_def.stat_modifiers[stat_id])
		else:
			var status_def: MASStatusEffectDef = data.get("def")
			if status_def != null and status_def.stat_modifiers.has(stat_id):
				total += float(status_def.stat_modifiers[stat_id]) * int(data.get("stacks", 1))
	return total

# 新增状态记录。
# 这里保存剩余时间、tick 计时和来源上下文，方便后续周期效果使用。
func _add_new_status(status_def: MASStatusEffectDef, context: MASEffectContext) -> void:
	if status_def.stack_rule == MASStatusEffectDef.StackRule.INDEPENDENT_INSTANCES:
		active_statuses[status_def.status_id] = {
			"def": status_def,
			"instances": [_create_status_instance(status_def, context)],
		}
	else:
		active_statuses[status_def.status_id] = _create_status_instance(status_def, context)
		active_statuses[status_def.status_id]["stacks"] = 1
	status_applied.emit(status_def.status_id, status_def, 1)

# 根据状态配置处理叠加规则。
# 所有技能共用这一套规则，避免每个技能脚本各自处理减速、灼烧或眩晕叠加。
func _apply_stack_rule(status_def: MASStatusEffectDef, context: MASEffectContext) -> void:
	var data: Dictionary = active_statuses[status_def.status_id]
	match status_def.stack_rule:
		MASStatusEffectDef.StackRule.REFRESH_DURATION:
			data["remaining"] = _get_status_duration(status_def, context)
		MASStatusEffectDef.StackRule.STACK_INTENSITY:
			data["stacks"] = mini(int(data.get("stacks", 1)) + 1, max(status_def.max_stacks, 1))
			data["remaining"] = _get_status_duration(status_def, context)
		MASStatusEffectDef.StackRule.STACK_DURATION:
			data["remaining"] = float(data.get("remaining", 0.0)) + _get_status_duration(status_def, context)
		MASStatusEffectDef.StackRule.REPLACE_IF_STRONGER:
			if _is_stronger(status_def, data.get("def")):
				data["def"] = status_def
				data["remaining"] = _get_status_duration(status_def, context)
		MASStatusEffectDef.StackRule.IGNORE_IF_ACTIVE:
			return
		MASStatusEffectDef.StackRule.INDEPENDENT_INSTANCES:
			var instances: Array = data.get("instances", [])
			if instances.size() < max(status_def.max_stacks, 1):
				instances.append(_create_status_instance(status_def, context))
			data["instances"] = instances
	data["context"] = context
	active_statuses[status_def.status_id] = data
	status_applied.emit(status_def.status_id, status_def, get_status_stack_count(status_def.status_id))

# 更新所有状态时间和周期 tick。
# 这里先收集要移除的状态，避免遍历字典时直接删除导致迭代问题。
func _update_statuses(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for status_id in active_statuses.keys():
		var data: Dictionary = active_statuses[status_id]
		if data.has("instances"):
			_update_independent_instances(status_id, data, delta)
			if not active_statuses.has(status_id):
				continue
			data = active_statuses[status_id]
			if int(data.get("instances", []).size()) <= 0:
				to_remove.append(status_id)
			continue
		var status_def: MASStatusEffectDef = data.get("def")
		if status_def == null:
			to_remove.append(status_id)
			continue
		data["remaining"] = float(data.get("remaining", 0.0)) - delta
		_process_tick(status_id, data, status_def, delta)
		active_statuses[status_id] = data
		if float(data.get("remaining", 0.0)) <= 0.0:
			to_remove.append(status_id)
	for status_id in to_remove:
		remove_status(status_id)

# 处理状态周期 tick。
# 灼烧、中毒、持续治疗等状态可以通过 tick 触发 periodic_effects。
func _process_tick(status_id: StringName, data: Dictionary, status_def: MASStatusEffectDef, delta: float) -> void:
	var interval := status_def.get_safe_tick_interval()
	if interval <= 0.0:
		return
	data["tick_elapsed"] = float(data.get("tick_elapsed", 0.0)) + delta
	if float(data["tick_elapsed"]) < interval:
		return
	data["tick_elapsed"] = 0.0
	_execute_periodic_effects(status_def, data.get("context"))
	status_tick.emit(status_id, status_def)

# 判断目标是否免疫该状态。
# 读取父节点 group、has_tag 方法和 MASTagComponent，免疫规则无需写进敌人脚本。
func _is_immune_to_status(status_def: MASStatusEffectDef) -> bool:
	var owner := get_parent()
	if owner == null:
		return false
	for tag in status_def.immunity_tags:
		if _owner_has_tag(owner, tag):
			return true
	return false

# 创建状态实例数据。
# 普通状态和独立实例状态都复用这个结构，方便统一处理剩余时间和 tick。
func _create_status_instance(status_def: MASStatusEffectDef, context: MASEffectContext) -> Dictionary:
	return {
		"def": status_def,
		"remaining": _get_status_duration(status_def, context),
		"tick_elapsed": 0.0,
		"context": context,
	}

# 计算实际状态持续时间。
# Rogue 词条可以通过 RuntimeStats 调整状态时长，但不会修改原始 StatusEffectDef。
func _get_status_duration(status_def: MASStatusEffectDef, context: MASEffectContext) -> float:
	var duration := status_def.get_safe_duration()
	if context != null and context.runtime_stats != null:
		duration *= context.runtime_stats.status_duration_multiplier
	return maxf(duration, 0.0)

# 更新独立实例状态。
# 每个实例拥有自己的剩余时间和 tick 计时，先到期的实例会单独移除。
func _update_independent_instances(status_id: StringName, data: Dictionary, delta: float) -> void:
	var kept_instances: Array = []
	for instance in data.get("instances", []):
		var status_def: MASStatusEffectDef = instance.get("def")
		if status_def == null:
			continue
		instance["remaining"] = float(instance.get("remaining", 0.0)) - delta
		_process_tick(status_id, instance, status_def, delta)
		if float(instance.get("remaining", 0.0)) > 0.0:
			kept_instances.append(instance)
	if kept_instances.is_empty():
		active_statuses.erase(status_id)
		status_removed.emit(status_id)
	else:
		data["instances"] = kept_instances
		active_statuses[status_id] = data

# 执行状态周期效果。
# 周期伤害、周期治疗等通过 context 中的 adapter 回到统一效果流程。
func _execute_periodic_effects(status_def: MASStatusEffectDef, context: MASEffectContext) -> void:
	if context == null:
		return
	var adapter = context.custom_data.get("adapter")
	if not (adapter is MASGameAdapter):
		return
	for effect in status_def.periodic_effects:
		if effect == null or not effect.has_method("apply"):
			continue
		context.effect_id = effect.get_effect_id() if effect.has_method("get_effect_id") else &"periodic_effect"
		effect.apply(context, adapter)

# 判断拥有者是否带有标签。
# 免疫判断支持 group、自定义 has_tag 方法和子节点 MASTagComponent。
func _owner_has_tag(owner: Node, tag: StringName) -> bool:
	if owner.is_in_group(String(tag)):
		return true
	if owner.has_method("has_tag") and owner.has_tag(tag):
		return true
	for child in owner.get_children():
		if child is MASTagComponent and child.has_tag(tag):
			return true
	return false

# 判断新状态是否比旧状态更强。
# 第一版用 stat_modifiers 绝对值总和比较，后续可替换为更完整的强度评分。
func _is_stronger(new_status: MASStatusEffectDef, old_status: MASStatusEffectDef) -> bool:
	if old_status == null:
		return true
	return _modifier_score(new_status) > _modifier_score(old_status)

# 计算状态强度评分。
# 这个方法只用于 `REPLACE_IF_STRONGER`，避免每个状态自己写覆盖逻辑。
func _modifier_score(status_def: MASStatusEffectDef) -> float:
	var score := 0.0
	for value in status_def.stat_modifiers.values():
		score += absf(float(value))
	return score
