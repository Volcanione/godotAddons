extends RefCounted
class_name MASHitTracker

var total_hit_count: int = 0
var target_hits: Dictionary = {}

# 判断指定目标当前是否可以被命中。
# 持续范围技能需要用这个方法避免同一帧或过短间隔内重复结算伤害。
func can_hit(target: Node, current_time: float, hit_rule: MASHitRuleDef = null) -> bool:
	if target == null:
		return false
	if hit_rule == null:
		return true
	if not hit_rule.allows_total_hit(total_hit_count):
		return false
	var data := _get_target_data(target)
	if hit_rule.hit_once_per_cast and int(data.get("count", 0)) > 0:
		return false
	if not hit_rule.allows_target_hit(data.get("count", 0)):
		return false
	var last_hit_time: float = data.get("last_time", -INF)
	if data.get("count", 0) > 0 and current_time - last_hit_time < hit_rule.rehit_interval:
		return false
	return true

# 记录一次命中。
# Godot 节点可能被释放，所以字典只记录 instance_id，避免直接持有目标引用造成清理困难。
func record_hit(target: Node, current_time: float) -> void:
	if target == null:
		return
	var key := target.get_instance_id()
	var data: Dictionary = target_hits.get(key, {"count": 0, "last_time": -INF})
	data["count"] = int(data.get("count", 0)) + 1
	data["last_time"] = current_time
	target_hits[key] = data
	total_hit_count += 1

# 清空命中记录。
# Runtime 结束或复用 tracker 时调用，保证新一轮释放不继承旧命中数据。
func clear() -> void:
	total_hit_count = 0
	target_hits.clear()

# 读取目标命中数据。
# 如果目标从未被命中过，返回默认计数和时间。
func _get_target_data(target: Node) -> Dictionary:
	return target_hits.get(target.get_instance_id(), {"count": 0, "last_time": -INF})
