extends MASAbilityBehavior
class_name MASMeleeBehavior

@export var active_time: float = 0.1

# 近战技能开始时调用。
# 第一版直接对传入目标结算，后续可以扩展扇形查询或 Hitbox 场景。
func start(runtime: MASAbilityRuntime) -> void:
	super.start(runtime)

# 近战技能每帧更新。
# 近战攻击通常持续很短，到达 active_time 后自动结束 Runtime。
func tick(runtime: MASAbilityRuntime, delta: float) -> void:
	if runtime != null and runtime.elapsed >= active_time:
		runtime.finish()
