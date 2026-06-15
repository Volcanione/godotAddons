extends Resource
class_name MASEffectDef

enum EffectType {
	CUSTOM,
	DAMAGE,
	HEAL,
	APPLY_STATUS,
	FORCE,
	SPAWN_SCENE,
}

@export var id: StringName
@export var effect_type: EffectType = EffectType.CUSTOM
@export var value: float = 0.0
@export var damage_type: StringName = &"physical"
@export var status_def: MASStatusEffectDef
@export var force_strength: float = 0.0
@export var force_mode: StringName = &"knockback"
@export var scaling_stat: StringName
@export var tags: Array[StringName] = []

# 执行效果。
# 基类只提供默认分发，特殊效果可以继承并覆写该方法。
func apply(context: MASEffectContext, adapter: MASGameAdapter) -> void:
	if adapter == null:
		return
	match effect_type:
		EffectType.DAMAGE:
			adapter.apply_damage(context, value, damage_type)
		EffectType.HEAL:
			adapter.apply_heal(context, value)
		EffectType.APPLY_STATUS:
			if status_def != null:
				adapter.apply_status(context, status_def)
		EffectType.FORCE:
			adapter.apply_force(context, {"mode": force_mode, "strength": force_strength})
		_:
			adapter.emit_cue(&"effect_custom", context)

# 返回效果 ID，未配置时用类型名兜底。
# EffectContext 需要稳定 ID，方便 UI、音效、统计和调试追踪来源。
func get_effect_id() -> StringName:
	if id != &"":
		return id
	return StringName(str(effect_type))
