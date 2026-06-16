# Modular Ability System 项目接入指南

这份文档说明如何把 MAS 插件接到具体 Godot 项目中。

## 1. 启用插件

插件目录需要位于：

```text
res://addons/modular_ability_system
```

然后在 `Project > Project Settings > Plugins` 中启用 `Modular Ability System`。启用后右侧 Dock 会出现 `MAS` 面板。

## 2. 创建技能资源

可以用 MAS Dock 创建基础模板：

- `Projectile`：弹道伤害。
- `Area`：持续范围。
- `Self`：自身治疗。
- `Melee`：近战窗口。

默认保存结构：

```text
res://resources/ability_defs/
res://resources/ability_behaviors/
res://resources/effect_defs/
res://resources/hit_rules/
res://resources/target_filters/
res://resources/visual_defs/
```

创建后用 Godot Inspector 继续调整 `MASAbilityDef` 及其引用资源。

## 3. 挂载技能组件

在角色、武器或技能控制节点上添加 `MASAbilityComponent`，并把技能资源放入 `starting_abilities`。

```text
Player
  MASAbilityComponent
	starting_abilities = [
	  res://resources/ability_defs/fireball.tres
	]
```

输入层释放技能：

```gdscript
@onready var abilities: MASAbilityComponent = $MASAbilityComponent

func cast_fireball(direction: Vector2) -> void:
	abilities.try_activate_ability(&"fireball", {
		"direction": direction,
	})
```

范围技能通常传入 `point`：

```gdscript
abilities.try_activate_ability(&"ice_zone", {
	"point": get_global_mouse_position(),
})
```

## 4. 接入项目规则

默认 `MASGameAdapter` 只提供通用兜底逻辑。项目有自己的血量、阵营、事件系统时，应创建 adapter 子类：

```gdscript
extends MASGameAdapter
class_name GameAbilityAdapter

func get_faction(actor: Node) -> StringName:
	if actor != null and actor.has_method("get_team"):
		return actor.get_team()
	return &"neutral"

func apply_damage(context: MASEffectContext, amount: float, damage_type: StringName = &"physical") -> void:
	var target := resolve_target_actor(context.target_actor)
	if target != null and target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(amount, damage_type, context)
	emit_cue(&"damage_applied", context)
```

然后在初始化时注入：

```gdscript
abilities.set_adapter(GameAbilityAdapter.new())
```

## 5. 状态、标签与属性

- `MASStatusReceiver`：挂到目标下，用于接收 `MASStatusEffectDef`。
- `MASForceReceiver`：用于把击退、牵引等请求交给移动系统。
- `MASTagComponent`：补充标签；也可以直接用 Godot group。
- `MASAttributeSet`：保存通用属性字典，或由项目自己的属性系统替代。

`MASStatusEffectDef` 支持刷新持续时间、叠强度、叠时长、更强替换、已存在忽略、独立实例等规则。

## 6. 配置视觉

`MASAbilityVisualDef` 可以配置四个阶段：

```text
cast_scene    施法起手
active_scene  技能主体
hit_scene     命中特效
end_scene     结束特效
```

如果 `active_scene` 已配置，`MASAreaBehavior` 和 `MASProjectileBehavior` 不会再叠加默认主体视觉。视觉场景应只处理动画、粒子、音效等表现，不要直接写伤害或状态逻辑。

## 7. 常见检查

- 技能不释放：确认 `MASAbilityDef.id` 和调用的 ability id 一致，冷却已归零。
- 打不到目标：检查 `MASTargetFilterDef.target_side`、目标 group、adapter 阵营判断和 collision mask。
- 状态不生效：确认目标下有 `MASStatusReceiver`，或目标自身实现了 `apply_status`。
- 视觉不出现：确认 `visual_def` 已挂到 `MASAbilityDef`，PackedScene 能实例化，并且 Runtime 在场景树中。
