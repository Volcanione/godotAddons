extends MASAbilityBehavior
class_name MASProjectileBehavior

@export var speed: float = 320.0
@export var max_lifetime: float = 2.0
@export var spawn_distance: float = 18.0
@export var projectile_scene: PackedScene
@export var target_query: MASTargetQuery

# 弹道技能开始时调用。
# 第一版把 Runtime 自身当作轻量弹道节点移动；如果配置了 projectile_scene，则生成视觉子节点。
func start(runtime: MASAbilityRuntime) -> void:
	if runtime == null:
		return
	var direction := _get_direction(runtime)
	runtime.custom_data["direction"] = direction
	runtime.custom_data["lifetime"] = max_lifetime
	if runtime.caster is Node2D:
		runtime.global_position = runtime.caster.global_position + direction * spawn_distance
	_create_visual(runtime)
	if runtime.target_data.has("target"):
		runtime.apply_effects_to_target(runtime.target_data["target"], runtime.global_position)

# 弹道技能每帧移动。
# 使用 `_process` 转发的 delta 计算位移，后续如果要物理碰撞可扩展为 Area2D 查询。
func tick(runtime: MASAbilityRuntime, delta: float) -> void:
	if runtime == null:
		return
	var direction: Vector2 = runtime.custom_data.get("direction", Vector2.RIGHT)
	runtime.global_position += direction * speed * delta
	_query_and_hit_targets(runtime)
	runtime.custom_data["lifetime"] = float(runtime.custom_data.get("lifetime", 0.0)) - delta
	if float(runtime.custom_data["lifetime"]) <= 0.0:
		runtime.finish()

# 弹道技能结束时调用。
# 当前视觉节点挂在 Runtime 下，Runtime queue_free 时会自动释放，所以这里不需要额外处理。
func stop(runtime: MASAbilityRuntime) -> void:
	pass

# 读取释放方向。
# 输入层可以传 `direction`，没有传时默认向右，避免技能因缺少方向直接报错。
func _get_direction(runtime: MASAbilityRuntime) -> Vector2:
	var direction: Vector2 = runtime.target_data.get("direction", Vector2.RIGHT)
	if direction == Vector2.ZERO:
		return Vector2.RIGHT
	return direction.normalized()

# 创建弹道视觉节点。
# 视觉场景只作为 Runtime 子节点，不参与插件核心逻辑，方便不同游戏替换表现资源。
func _create_visual(runtime: MASAbilityRuntime) -> void:
	if _has_active_visual_config(runtime):
		return
	if projectile_scene == null:
		return
	var visual := projectile_scene.instantiate()
	runtime.add_child(visual)

# 判断技能是否已经配置主体视觉。
# 如果 AbilityDef.visual_def.active_scene 已配置，就不再叠加 Behavior 自己的 projectile_scene。
func _has_active_visual_config(runtime: MASAbilityRuntime) -> bool:
	if runtime == null or runtime.ability_def == null:
		return false
	var visual_def = runtime.ability_def.get("visual_def")
	return visual_def is Resource and visual_def.get("active_scene") is PackedScene

# 查询并命中弹道目标。
# 配置 TargetQuery 后，弹道可以在飞行中主动找 hurtbox/actor，而不是依赖外部预塞 target。
func _query_and_hit_targets(runtime: MASAbilityRuntime) -> void:
	var targets := _get_targets(runtime)
	if targets.is_empty():
		return
	for target in targets:
		if not (target is Node):
			continue
		var before_hit_count := runtime.hit_tracker.total_hit_count
		runtime.apply_effects_to_target(target, runtime.global_position)
		if runtime.hit_tracker.total_hit_count > before_hit_count and _should_finish_after_hit(runtime):
			runtime.finish()
			return

# 读取弹道候选目标。
# 优先用配置的 TargetQuery；没有查询时仍兼容 target/targets 这类手动传入数据。
func _get_targets(runtime: MASAbilityRuntime) -> Array:
	if target_query != null:
		var query_data := runtime.target_data.duplicate(true)
		query_data["point"] = runtime.global_position
		return target_query.query(runtime, query_data, runtime.adapter)
	if runtime.target_data.has("targets"):
		return runtime.target_data.get("targets", [])
	if runtime.target_data.has("target"):
		return [runtime.target_data["target"]]
	return []

# 判断弹道命中后是否结束。
# pierce_count 表示允许穿透的额外目标数，0 表示首个有效命中后结束。
func _should_finish_after_hit(runtime: MASAbilityRuntime) -> bool:
	if runtime.ability_def == null or runtime.ability_def.hit_rule == null:
		return true
	var pierce_count := runtime.ability_def.hit_rule.pierce_count
	if pierce_count <= 0:
		return true
	return runtime.hit_tracker.total_hit_count > pierce_count
