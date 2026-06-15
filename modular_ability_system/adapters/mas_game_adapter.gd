extends RefCounted
class_name MASGameAdapter

# 获取目标阵营。
# 第一版默认读取 Godot group，具体项目可以继承 adapter 后改成自己的阵营系统。
func get_faction(actor: Node) -> StringName:
	if actor == null:
		return &"neutral"
	if actor.is_in_group("player"):
		return &"player"
	if actor.is_in_group("enemy"):
		return &"enemy"
	return &"neutral"

# 判断两个对象是否是敌对关系。
# 技能筛选不直接写死玩家和敌人逻辑，而是通过 adapter 集中判断。
func are_enemies(source: Node, target: Node) -> bool:
	var source_faction := get_faction(source)
	var target_faction := get_faction(target)
	if source_faction == &"neutral" or target_faction == &"neutral":
		return false
	return source_faction != target_faction

# 判断两个对象是否是友方关系。
# 自身和同阵营都视为友方，治疗和 Buff 技能可以复用这个入口。
func are_allies(source: Node, target: Node) -> bool:
	var source_faction := get_faction(source)
	var target_faction := get_faction(target)
	return source_faction != &"neutral" and source_faction == target_faction

# 应用伤害。
# 默认优先调用目标自己的 `apply_damage` 或 `take_damage`，没有接口时只发 cue，避免插件绑定具体血量组件。
func apply_damage(context: MASEffectContext, amount: float, damage_type: StringName = &"physical") -> void:
	if context == null or context.target_actor == null:
		return
	context.target_actor = resolve_target_actor(context.target_actor)
	var final_amount := amount
	if context.runtime_stats != null:
		final_amount = context.runtime_stats.get_final_damage(amount)
	if context.target_actor.has_method("apply_damage"):
		context.target_actor.apply_damage(final_amount, context)
	elif context.target_actor.has_method("take_damage"):
		context.target_actor.take_damage(final_amount)
	emit_cue(&"damage_applied", context)

# 应用治疗。
# 具体项目可以在子类里接入 HealthComponent，这里只保留通用方法调用约定。
func apply_heal(context: MASEffectContext, amount: float) -> void:
	if context == null or context.target_actor == null:
		return
	context.target_actor = resolve_target_actor(context.target_actor)
	if context.target_actor.has_method("apply_heal"):
		context.target_actor.apply_heal(amount, context)
	emit_cue(&"heal_applied", context)

# 应用状态。
# 默认在目标子节点中寻找 MASStatusReceiver，也允许目标自身实现 `apply_status`。
func apply_status(context: MASEffectContext, status_def: MASStatusEffectDef) -> void:
	if context == null or context.target_actor == null or status_def == null:
		return
	context.target_actor = resolve_target_actor(context.target_actor)
	context.custom_data["adapter"] = self
	var receiver := _find_status_receiver(context.target_actor)
	if receiver != null:
		receiver.apply_status(status_def, context)
	elif context.target_actor.has_method("apply_status"):
		context.target_actor.apply_status(status_def, context)
	emit_cue(&"status_applied", context)

# 应用外力。
# 击退和牵引依赖具体移动系统，所以默认优先找组件，再调用目标暴露的方法。
func apply_force(context: MASEffectContext, force_data: Dictionary) -> void:
	if context == null or context.target_actor == null:
		return
	context.target_actor = resolve_target_actor(context.target_actor)
	var receiver := _find_force_receiver(context.target_actor)
	if receiver != null:
		receiver.apply_force(force_data, context)
	elif context.target_actor.has_method("apply_force"):
		context.target_actor.apply_force(force_data, context)
	emit_cue(&"force_applied", context)

# 解析实际技能目标主体。
# Hurtbox、Area2D 或碰撞子节点可以通过方法、metadata 或父节点映射回真正 actor。
func resolve_target_actor(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("get_ability_actor"):
		var actor = target.get_ability_actor()
		if actor is Node:
			return actor
	if target.has_meta("ability_actor"):
		var meta_actor = target.get_meta("ability_actor")
		if meta_actor is Node:
			return meta_actor
	if target.has_meta("ability_actor_path"):
		var actor_path = target.get_meta("ability_actor_path")
		if actor_path is NodePath and target.has_node(actor_path):
			return target.get_node(actor_path)
	if target is Area2D and target.get_parent() != null:
		return target.get_parent()
	return target

# 判断目标是否拥有标签。
# 标签同时支持 Godot group、目标自身方法和子节点 MASTagComponent。
func has_tag(actor: Node, tag: StringName) -> bool:
	if actor == null:
		return false
	if actor.is_in_group(String(tag)):
		return true
	if actor.has_method("has_tag") and actor.has_tag(tag):
		return true
	for child in actor.get_children():
		if child is MASTagComponent and child.has_tag(tag):
			return true
	return false

# 发出反馈事件。
# 插件核心不依赖 EventBus，项目可以继承 adapter 后把 cue 转给 UI、音效或特效系统。
func emit_cue(cue_id: StringName, context: MASEffectContext) -> void:
	pass

# 读取属性值。
# 第一版优先调用目标方法，后续可以接入 MASAttributeSet 或项目自己的 StatsComponent。
func get_attribute(actor: Node, attribute_id: StringName, default_value: float = 0.0) -> float:
	if actor != null and actor.has_method("get_attribute"):
		return actor.get_attribute(attribute_id, default_value)
	return default_value

# 查找状态接收组件。
# 这里遍历直接子节点，避免插件要求目标必须继承某个基类。
func _find_status_receiver(actor: Node) -> MASStatusReceiver:
	for child in actor.get_children():
		if child is MASStatusReceiver:
			return child
	return null

# 查找外力接收组件。
# MovementComponent 可以监听 MASForceReceiver 信号，从而接收击退、牵引等请求。
func _find_force_receiver(actor: Node) -> MASForceReceiver:
	for child in actor.get_children():
		if child is MASForceReceiver:
			return child
	return null
