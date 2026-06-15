extends MASAbilityBehavior
class_name MASAreaBehavior

@export var radius: float = 96.0
@export var tick_interval: float = 0.25
@export var follow_caster: bool = false
@export var target_query: MASTargetQuery
@export var show_default_visual: bool = true
@export var visual_color: Color = Color(0.25, 0.75, 1.0, 0.28)
@export var visual_outline_color: Color = Color(0.4, 0.9, 1.0, 0.85)

# 范围技能开始时调用。
# 如果传入 point 则把 Runtime 放到目标点，否则默认放在释放者当前位置。
func start(runtime: MASAbilityRuntime) -> void:
	if runtime == null:
		return
	if runtime.target_data.has("point"):
		runtime.global_position = runtime.target_data["point"]
	elif runtime.caster is Node2D:
		runtime.global_position = runtime.caster.global_position
	runtime.custom_data["area_tick_elapsed"] = _get_tick_interval(runtime)
	_create_visual(runtime)

# 范围技能每帧更新。
# 通过 tick_interval 控制结算频率，避免范围技能每帧重复扫描和结算。
func tick(runtime: MASAbilityRuntime, delta: float) -> void:
	if runtime == null:
		return
	if follow_caster and runtime.caster is Node2D:
		runtime.global_position = runtime.caster.global_position
	runtime.custom_data["area_tick_elapsed"] = float(runtime.custom_data.get("area_tick_elapsed", 0.0)) + delta
	var final_tick_interval := _get_tick_interval(runtime)
	if final_tick_interval > 0.0 and float(runtime.custom_data["area_tick_elapsed"]) < final_tick_interval:
		return
	runtime.custom_data["area_tick_elapsed"] = 0.0
	var targets := _query_targets(runtime)
	runtime.apply_effects_to_targets(targets, runtime.global_position)

# 范围技能结束时调用。
# 第一版没有创建额外查询节点，因此只保留扩展入口。
func stop(runtime: MASAbilityRuntime) -> void:
	pass

# 创建默认法阵视觉。
# 插件创建的范围技能如果没有额外配置特效，也能在 Demo 中看到命中范围和持续时间。
func _create_visual(runtime: MASAbilityRuntime) -> void:
	if runtime == null or not show_default_visual:
		return
	if _has_active_visual_config(runtime):
		return
	var final_radius := _get_final_radius(runtime)
	if final_radius <= 0.0:
		return
	var visual := Node2D.new()
	visual.name = "MASAreaVisual"
	runtime.add_child(visual)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = visual_color
	fill.polygon = _build_circle_points(final_radius, 40)
	visual.add_child(fill)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.default_color = visual_outline_color
	outline.width = 2.0
	outline.closed = true
	outline.points = _build_circle_points(final_radius, 40)
	visual.add_child(outline)
	var tween := runtime.create_tween()
	tween.set_loops()
	tween.tween_property(visual, "scale", Vector2(1.08, 1.08), 0.35)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.35)

# 生成圆形点集。
# Polygon2D 和 Line2D 共用这一组点，避免填充范围和描边范围不一致。
func _build_circle_points(circle_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments := max(segments, 12)
	for index in safe_segments:
		var angle := TAU * float(index) / float(safe_segments)
		points.append(Vector2.RIGHT.rotated(angle) * circle_radius)
	return points

# 查询范围目标。
# 优先使用配置的 TargetQuery；未配置时创建默认 2D 圆形查询，支持只给 point/radius 的法阵技能。
func _query_targets(runtime: MASAbilityRuntime) -> Array:
	if runtime.target_data.has("targets") and target_query == null:
		return runtime.target_data.get("targets", [])
	var query := target_query
	if query == null:
		query = MASArea2DTargetQuery.new()
	if query is MASArea2DTargetQuery:
		query.radius = _get_final_radius(runtime)
	var query_data := runtime.target_data.duplicate(true)
	query_data["point"] = runtime.global_position
	query_data["radius"] = _get_final_radius(runtime)
	return query.query(runtime.caster, query_data, runtime.adapter)

# 计算最终半径。
# Rogue 词条的 radius_add 只影响运行时，不修改 Behavior Resource 原始半径。
func _get_final_radius(runtime: MASAbilityRuntime) -> float:
	var final_radius := radius
	if runtime.runtime_stats != null:
		final_radius += runtime.runtime_stats.radius_add
	return maxf(final_radius, 0.0)

# 判断技能是否已经配置主体视觉。
# 如果 AbilityDef.visual_def.active_scene 已配置，就不再叠加默认圆形法阵。
func _has_active_visual_config(runtime: MASAbilityRuntime) -> bool:
	if runtime == null or runtime.ability_def == null:
		return false
	var visual_def = runtime.ability_def.get("visual_def")
	return visual_def is Resource and visual_def.get("active_scene") is PackedScene

# 读取最终 tick 间隔。
# 命中规则上的 tick_interval 优先级更高，方便同一 Behavior 被不同技能复用。
func _get_tick_interval(runtime: MASAbilityRuntime) -> float:
	if runtime.ability_def != null and runtime.ability_def.hit_rule != null:
		var rule_interval := runtime.ability_def.hit_rule.get_safe_tick_interval()
		if rule_interval > 0.0:
			return rule_interval
	return maxf(tick_interval, 0.0)
