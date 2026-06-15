extends MASEffectDef
class_name MASApplyStatusEffect

# 初始化状态效果默认类型。
# 状态本身放在 status_def 中，效果只负责把状态交给目标接收器。
func _init() -> void:
	effect_type = EffectType.APPLY_STATUS

# 执行状态添加效果。
# 减速、灼烧、眩晕等通用 Debuff 都通过这个入口复用。
func apply(context: MASEffectContext, adapter: MASGameAdapter) -> void:
	if adapter == null or status_def == null:
		return
	adapter.apply_status(context, status_def)
