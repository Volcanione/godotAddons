extends RefCounted
class_name MASEffectContext

var source_actor: Node
var instigator: Node
var target_actor: Node
var ability_id: StringName
var effect_id: StringName
var faction: StringName
var hit_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var runtime_stats: MASRuntimeStats
var tags: Array[StringName] = []
var custom_data: Dictionary = {}

# 初始化效果上下文。
# 技能、投射物、范围区域都通过这个上下文把来源、目标和命中信息传给效果层。
func setup(data: Dictionary) -> MASEffectContext:
	source_actor = data.get("source_actor")
	instigator = data.get("instigator")
	target_actor = data.get("target_actor")
	ability_id = data.get("ability_id", &"")
	effect_id = data.get("effect_id", &"")
	faction = data.get("faction", &"")
	hit_position = data.get("hit_position", Vector2.ZERO)
	direction = data.get("direction", Vector2.ZERO)
	runtime_stats = data.get("runtime_stats")
	tags.clear()
	for tag in data.get("tags", []):
		tags.append(StringName(tag))
	custom_data = data.get("custom_data", {}).duplicate(true)
	return self

# 复制一份上下文并替换目标。
# 同一个范围技能会命中多个目标，用复制方式可以避免目标数据互相覆盖。
func duplicate_for_target(target: Node, position: Vector2 = Vector2.ZERO) -> MASEffectContext:
	var context := MASEffectContext.new()
	context.source_actor = source_actor
	context.instigator = instigator
	context.target_actor = target
	context.ability_id = ability_id
	context.effect_id = effect_id
	context.faction = faction
	context.hit_position = position
	context.direction = direction
	context.runtime_stats = runtime_stats
	context.tags = tags.duplicate()
	context.custom_data = custom_data.duplicate(true)
	return context
