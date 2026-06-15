extends MASTargetQuery
class_name MASArea2DTargetQuery

@export var radius: float = 96.0
@export var collision_mask: int = 0

# 查询范围内的 Area2D。
# 使用 Godot 物理空间的圆形 Shape 查询，适合范围技能在某个点附近找 hurtbox。
func query(source: Node, target_data: Dictionary = {}, adapter: MASGameAdapter = null) -> Array[Node]:
	var world_source := _get_world_source(source)
	if world_source == null:
		return []
	var center := _get_center(source, target_data)
	var shape := CircleShape2D.new()
	shape.radius = maxf(float(target_data.get("radius", radius)), 0.0)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	if collision_mask != 0:
		params.collision_mask = collision_mask
	var results := world_source.get_world_2d().direct_space_state.intersect_shape(params)
	var targets: Array[Node] = []
	for result in results:
		var collider = result.get("collider")
		if collider is Node:
			var target: Node = collider
			if adapter != null:
				target = adapter.resolve_target_actor(collider)
			if target != null and not targets.has(target):
				targets.append(target)
	return targets

# 获取可访问 2D 世界的节点。
# 物理查询必须从已经在场景树中的 CanvasItem 取得 World2D。
func _get_world_source(source: Node) -> CanvasItem:
	if source is CanvasItem:
		return source
	return null

# 获取查询中心点。
# 范围技能可以传入 point；未传时使用释放者当前位置。
func _get_center(source: Node, target_data: Dictionary) -> Vector2:
	if target_data.has("point"):
		return target_data["point"]
	if source is Node2D:
		return source.global_position
	return Vector2.ZERO
