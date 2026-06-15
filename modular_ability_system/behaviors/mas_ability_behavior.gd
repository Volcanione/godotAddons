extends Resource
class_name MASAbilityBehavior

# 技能开始时调用。
# Runtime 创建完成后会先进入这里，子类可以生成弹道、播放启动 cue 或立即结算目标。
func start(runtime: MASAbilityRuntime) -> void:
	if runtime == null:
		return
	if runtime.target_data.has("target"):
		runtime.apply_effects_to_target(runtime.target_data["target"])
	elif runtime.target_data.has("targets"):
		runtime.apply_effects_to_targets(runtime.target_data["targets"])

# 技能每帧更新时调用。
# Godot 的 `_process(delta)` 由 Runtime 接收，再转发给 Behavior，方便不同技能自定义运行方式。
func tick(runtime: MASAbilityRuntime, delta: float) -> void:
	pass

# 技能取消或结束时调用。
# 子类如果创建了临时节点、特效或监听信号，可以在这里做清理。
func stop(runtime: MASAbilityRuntime) -> void:
	pass
