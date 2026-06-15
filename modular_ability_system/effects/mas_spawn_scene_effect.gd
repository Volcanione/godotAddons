extends MASEffectDef
class_name MASSpawnSceneEffect

@export var scene: PackedScene
@export var attach_to_target: bool = false

# 初始化生成场景效果默认类型。
# 该效果可用于爆炸、召唤物、残留区域或纯视觉节点。
func _init() -> void:
	effect_type = EffectType.SPAWN_SCENE

# 执行场景生成效果。
# 生成节点默认挂到当前场景，避免跟随技能 Runtime 被立即释放。
func apply(context: MASEffectContext, adapter: MASGameAdapter) -> void:
	if context == null or scene == null:
		return
	var instance := scene.instantiate()
	var parent := _get_parent_for_spawn(context)
	if parent == null:
		instance.free()
		return
	parent.add_child(instance)
	if instance is Node2D:
		instance.global_position = context.hit_position
	if adapter != null:
		adapter.emit_cue(&"scene_spawned", context)

# 选择生成节点父级。
# 如果配置 attach_to_target，则挂到目标身上；否则挂到当前主场景，适合爆炸和范围残留。
func _get_parent_for_spawn(context: MASEffectContext) -> Node:
	if attach_to_target and context.target_actor != null:
		return context.target_actor
	if context.source_actor != null and context.source_actor.is_inside_tree():
		var tree := context.source_actor.get_tree()
		if tree.current_scene != null:
			return tree.current_scene
		return tree.root
	if context.source_actor != null and context.source_actor.get_parent() != null:
		return context.source_actor.get_parent()
	return null
