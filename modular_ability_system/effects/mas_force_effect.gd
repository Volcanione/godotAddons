extends MASEffectDef
class_name MASForceEffect

# 初始化外力效果默认类型。
# 击退和牵引都属于外力请求，具体移动由项目 MovementComponent 决定。
func _init() -> void:
	effect_type = EffectType.FORCE

# 执行外力效果。
# 插件只传递模式和强度，避免直接修改目标坐标造成物理和 AI 状态混乱。
func apply(context: MASEffectContext, adapter: MASGameAdapter) -> void:
	if adapter == null:
		return
	adapter.apply_force(context, {"mode": force_mode, "strength": force_strength})
