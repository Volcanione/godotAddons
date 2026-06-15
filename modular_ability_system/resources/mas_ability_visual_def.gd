extends Resource
class_name MASAbilityVisualDef

enum AttachMode {
	RUNTIME,
	CASTER,
	CURRENT_SCENE,
}

@export var cast_scene: PackedScene
@export var active_scene: PackedScene
@export var hit_scene: PackedScene
@export var end_scene: PackedScene
@export var attach_mode: AttachMode = AttachMode.RUNTIME
@export var follow_caster: bool = false
@export var face_direction: bool = true
@export var scale: Vector2 = Vector2.ONE
@export var z_index: int = 0
@export var auto_free_time: float = 0.0
@export var cast_auto_free_time: float = 0.25
@export var active_auto_free_time: float = 0.0
@export var hit_auto_free_time: float = 0.35
@export var end_auto_free_time: float = 0.5

# 生成施法起手视觉。
# 起手视觉默认使用技能 Runtime 的位置，适合施法闪光、举手动作或释放提示。
func spawn_cast(runtime: MASAbilityRuntime) -> Node:
	return _spawn_for_runtime(cast_scene, runtime, attach_mode, cast_auto_free_time)

# 生成技能主体视觉。
# 弹道、法阵、持续区域等主体表现都走这个入口，由 Runtime 统一管理。
func spawn_active(runtime: MASAbilityRuntime) -> Node:
	return _spawn_for_runtime(active_scene, runtime, attach_mode, active_auto_free_time)

# 生成命中视觉。
# 命中特效必须脱离 Runtime 挂到当前场景，避免弹道结束时把命中特效一起销毁。
func spawn_hit(context: MASEffectContext) -> Node:
	if context == null:
		return null
	var anchor := context.instigator if context.instigator is Node else context.target_actor
	var visual := _instantiate_scene(hit_scene)
	if visual == null:
		return null
	var parent := _get_current_scene(anchor)
	if parent == null:
		parent = _get_current_scene(context.target_actor)
	if parent == null:
		return null
	parent.add_child(visual)
	_apply_transform(visual, _get_hit_position(context), context.direction)
	_configure_lifetime(visual, hit_auto_free_time)
	return visual

# 生成技能结束视觉。
# 结束视觉挂到当前场景，保证 Runtime queue_free 后消散动画仍能继续播放。
func spawn_end(runtime: MASAbilityRuntime) -> Node:
	return _spawn_for_runtime(end_scene, runtime, AttachMode.CURRENT_SCENE, end_auto_free_time)

# 根据 Runtime 生成视觉场景实例。
# attach_mode 控制视觉挂在 Runtime、释放者或当前场景，满足不同表现资源的生命周期需求。
func _spawn_for_runtime(scene: PackedScene, runtime: MASAbilityRuntime, mode: AttachMode, lifetime: float) -> Node:
	if runtime == null:
		return null
	var visual := _instantiate_scene(scene)
	if visual == null:
		return null
	var parent := _resolve_parent(runtime, mode)
	if parent == null:
		return null
	parent.add_child(visual)
	_apply_transform(visual, runtime.global_position, _get_runtime_direction(runtime))
	_configure_lifetime(visual, lifetime)
	return visual

# 实例化视觉场景。
# 这里统一检查 PackedScene，避免各个调用点重复处理空资源。
func _instantiate_scene(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var visual := scene.instantiate()
	return visual if visual is Node else null

# 解析视觉父节点。
# Runtime 模式跟随技能节点，Caster 模式跟随释放者，CurrentScene 模式用于不应被 Runtime 回收的特效。
func _resolve_parent(runtime: MASAbilityRuntime, mode: AttachMode) -> Node:
	match mode:
		AttachMode.RUNTIME:
			return runtime
		AttachMode.CASTER:
			return runtime.caster
		AttachMode.CURRENT_SCENE:
			return _get_current_scene(runtime)
		_:
			return runtime

# 获取当前场景。
# 测试和 headless 场景中 current_scene 可能为空，此时退回 root，保证视觉仍能落到节点树中。
func _get_current_scene(anchor: Node) -> Node:
	if anchor == null:
		return null
	if anchor.is_inside_tree():
		var tree := anchor.get_tree()
		if tree.current_scene != null:
			return tree.current_scene
		return tree.root
	return anchor.get_parent()

# 应用位置、方向、缩放和层级。
# 只有 Node2D/CanvasItem 才有这些表现属性，因此这里按类型安全设置。
func _apply_transform(visual: Node, position: Vector2, direction: Vector2) -> void:
	if visual is Node2D:
		visual.global_position = position
		visual.scale = scale
		if face_direction and direction != Vector2.ZERO:
			visual.rotation = direction.angle()
	if visual is CanvasItem:
		visual.z_index = z_index

# 设置自动释放。
# 短命中特效可以通过 auto_free_time 自动清理，持续主体特效通常跟随 Runtime 自动释放。
func _configure_lifetime(visual: Node, lifetime: float) -> void:
	var final_lifetime := lifetime if lifetime > 0.0 else auto_free_time
	if visual == null or final_lifetime <= 0.0 or not visual.is_inside_tree():
		return
	visual.get_tree().create_timer(final_lifetime).timeout.connect(func() -> void:
		if is_instance_valid(visual):
			visual.queue_free()
	)

# 获取 Runtime 释放方向。
# 输入层传入 direction 时视觉按方向旋转，没有方向则保持场景原始角度。
func _get_runtime_direction(runtime: MASAbilityRuntime) -> Vector2:
	if runtime == null:
		return Vector2.ZERO
	var direction: Vector2 = runtime.target_data.get("direction", Vector2.ZERO)
	return direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO

# 获取命中特效位置。
# 优先使用效果上下文的命中点，缺失时退回目标或来源节点位置。
func _get_hit_position(context: MASEffectContext) -> Vector2:
	if context.hit_position != Vector2.ZERO:
		return context.hit_position
	if context.target_actor is Node2D:
		return context.target_actor.global_position
	if context.source_actor is Node2D:
		return context.source_actor.global_position
	return Vector2.ZERO
