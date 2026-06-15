extends MASEffectDef
class_name MASDamageEffect

# 初始化伤害效果默认类型。
# Resource 新建后自动标记为 DAMAGE，减少策划配置时漏选类型的概率。
func _init() -> void:
	effect_type = EffectType.DAMAGE

# 执行伤害效果。
# 伤害公式和目标血量系统交给 adapter，插件只传递上下文和基础数值。
func apply(context: MASEffectContext, adapter: MASGameAdapter) -> void:
	if adapter == null:
		return
	adapter.apply_damage(context, value, damage_type)
