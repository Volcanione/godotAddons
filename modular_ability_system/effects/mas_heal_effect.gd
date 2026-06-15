extends MASEffectDef
class_name MASHealEffect

# 初始化治疗效果默认类型。
# 这样在编辑器中新建 Resource 时，它会自动按治疗效果工作。
func _init() -> void:
	effect_type = EffectType.HEAL

# 执行治疗效果。
# 具体治疗如何影响血量由 adapter 或项目 HealthComponent 决定。
func apply(context: MASEffectContext, adapter: MASGameAdapter) -> void:
	if adapter == null:
		return
	adapter.apply_heal(context, value)
