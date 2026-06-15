extends Resource
class_name MASTargetFilterDef

enum TargetSide {
	ANY,
	SELF,
	ALLY,
	ENEMY,
	NEUTRAL,
}

@export var target_side: TargetSide = TargetSide.ENEMY
@export var required_tags: Array[StringName] = []
@export var blocked_tags: Array[StringName] = []
@export var max_targets: int = 0
@export var include_dead: bool = false
@export var include_invincible: bool = false

# 判断目标是否通过筛选。
# 技能插件不直接认识具体玩家或敌人，阵营判断交给 adapter，标签判断使用 group 或 TagComponent。
func allows_target(source: Node, target: Node, adapter: MASGameAdapter = null) -> bool:
	if target == null:
		return false
	if adapter != null:
		target = adapter.resolve_target_actor(target)
	if not include_dead and _has_tag(target, &"dead", adapter):
		return false
	if not include_invincible and _has_tag(target, &"invincible", adapter):
		return false
	if not _passes_side(source, target, adapter):
		return false
	if not _has_required_tags(target, adapter):
		return false
	if _has_blocked_tags(target, adapter):
		return false
	return true

# 从候选目标中过滤出可命中的目标。
# `max_targets` 大于 0 时会截断列表，避免范围技能一次命中过多对象。
func filter_targets(source: Node, candidates: Array, adapter: MASGameAdapter = null) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in candidates:
		if candidate is Node and allows_target(source, candidate, adapter):
			result.append(candidate)
			if max_targets > 0 and result.size() >= max_targets:
				break
	return result

# 判断阵营关系。
# 这里把实际阵营规则委托给 adapter，保证插件不会写死 Demo 的分组名称。
func _passes_side(source: Node, target: Node, adapter: MASGameAdapter) -> bool:
	match target_side:
		TargetSide.ANY:
			return true
		TargetSide.SELF:
			return source == target
		TargetSide.ALLY:
			return adapter != null and adapter.are_allies(source, target)
		TargetSide.ENEMY:
			return adapter != null and adapter.are_enemies(source, target)
		TargetSide.NEUTRAL:
			return adapter != null and adapter.get_faction(target) == &"neutral"
		_:
			return false

# 检查目标是否拥有所有必需标签。
# 标签优先用 Godot group 承载，后续也可以扩展为 `MASTagComponent`。
func _has_required_tags(target: Node, adapter: MASGameAdapter) -> bool:
	for tag in required_tags:
		if not _has_tag(target, tag, adapter):
			return false
	return true

# 检查目标是否拥有任何禁止标签。
# 例如 `immune_stun`、`boss` 可以用于阻止某类技能效果。
func _has_blocked_tags(target: Node, adapter: MASGameAdapter) -> bool:
	for tag in blocked_tags:
		if _has_tag(target, tag, adapter):
			return true
	return false

# 读取目标标签。
# 支持 Godot group、目标自身方法、子节点 MASTagComponent，以及 adapter 的统一标签入口。
func _has_tag(target: Node, tag: StringName, adapter: MASGameAdapter = null) -> bool:
	if target == null:
		return false
	if adapter != null and adapter.has_tag(target, tag):
		return true
	if target.is_in_group(String(tag)):
		return true
	if target.has_method("has_tag") and target.has_tag(tag):
		return true
	for child in target.get_children():
		if child is MASTagComponent and child.has_tag(tag):
			return true
	return false
