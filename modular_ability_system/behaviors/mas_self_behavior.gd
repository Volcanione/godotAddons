extends MASAbilityBehavior
class_name MASSelfBehavior

# 自身技能开始时调用。
# 如果没有显式目标，默认把释放者作为目标，用于回血、护盾和自身 Buff。
func start(runtime: MASAbilityRuntime) -> void:
	if runtime == null:
		return
	runtime.apply_effects_to_target(runtime.caster)
