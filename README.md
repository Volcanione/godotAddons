# Godot Addons

当前仓库包含一个 Godot 4.x 插件：

- `modular_ability_system/`：Resource 驱动的通用技能系统，覆盖技能定义、运行时、行为、效果、目标筛选、状态、词条、视觉配置和编辑器创建面板。

## Modular Ability System

MAS 的核心目标是把“技能配置”和“项目 gameplay 代码”分开：

- `MASAbilityDef` 描述技能模板。
- `MASAbilityComponent` 挂在角色、武器或技能控制节点上，负责授予技能、冷却和释放。
- `MASAbilityRuntime` 管理单次释放生命周期。
- `MASAbilityBehavior` 决定技能如何运行，例如弹道、范围、自身、近战。
- `MASEffectDef` 和子类描述效果，真正的伤害、治疗、状态、击退通过 `MASGameAdapter` 接到项目系统。
- `MASAbilityVisualDef` 管理施法、主体、命中、结束阶段的表现资源。

## 快速接入

1. 把本仓库作为 Godot 项目的 `res://addons` 内容。
2. 在 Godot 的 `Project > Project Settings > Plugins` 中启用 `Modular Ability System`。
3. 在角色或技能控制节点下添加 `MASAbilityComponent`。
4. 创建 `MASAbilityDef` 资源，配置 `behavior`、`effects`、`target_filter`、`hit_rule` 和可选 `visual_def`。
5. 在输入层调用：

```gdscript
ability_component.try_activate_ability(&"fireball", {
	"direction": Vector2.RIGHT,
	"point": target_world_position,
})
```

## 文档

- [架构分析](modular_ability_system/docs/architecture.md)
- [项目接入指南](modular_ability_system/docs/integration_guide.md)
- [技能配置示例](modular_ability_system/docs/example_abilities.md)
- [开发规则](modular_ability_system/docs/development_rules.md)

## 验证命令

在能访问 `res://addons/modular_ability_system` 的 Godot 项目中运行：

```powershell
godot --headless --check-only -s addons/modular_ability_system/core/mas_ability_component.gd
godot --headless --editor --quit
```
