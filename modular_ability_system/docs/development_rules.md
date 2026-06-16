# Modular Ability System 开发规则

这份文档用于约束 MAS 后续开发，目标是避免插件核心和具体项目逻辑互相污染。

## 1. Resource 是模板，不是运行时状态

`MASAbilityDef`、`MASEffectDef`、`MASStatusEffectDef`、`MASHitRuleDef` 等资源应被视为可复用模板。运行时不要直接修改这些资源字段。

正确做法：

- 临时数值走 `MASRuntimeStats`。
- 词条、装备、Rogue 加成走 `MASModifierDef.apply_to_runtime_stats()`。
- 一次释放的数据放在 `MASAbilityRuntime.custom_data` 或 `MASEffectContext.custom_data`。

## 2. 玩法逻辑和表现层分离

技能逻辑只负责“发生了什么”，表现层负责“看起来和听起来怎样”。

- 伤害、治疗、状态、击退、目标筛选不能写进视觉场景。
- 视觉资源使用 `MASAbilityVisualDef`。
- 动画、音效、UI 反馈可以通过 `MASGameAdapter.emit_cue()` 接到项目系统。

不要在 `MASAbilityBehavior` 或 `MASEffectDef` 里直接调用项目角色的 `AnimationPlayer`、`AnimatedSprite2D`、VFX 节点或音频节点。

## 3. Behavior 只管运行方式

`MASAbilityBehavior` 负责技能如何推进，例如：

- 弹道移动。
- 范围技能 tick。
- 近战窗口持续时间。
- 目标查询时机。

Behavior 不直接扣血、不加状态、不改目标属性。命中后必须调用：

```gdscript
runtime.apply_effects_to_target(target, hit_position)
```

这样命中规则、目标筛选、效果执行和命中特效才会统一生效。

## 4. Effect 只描述效果请求

`MASEffectDef.apply()` 只负责把效果请求交给 `MASGameAdapter`：

- 伤害：`adapter.apply_damage()`
- 治疗：`adapter.apply_heal()`
- 状态：`adapter.apply_status()`
- 外力：`adapter.apply_force()`

不要在 effect 中绑定项目自己的血量组件、敌人脚本、玩家脚本或 UI 逻辑。项目差异放到 adapter 子类里。

## 5. 项目差异只进 Adapter

不同项目的阵营、血量、状态栏、事件总线、音效系统、统计系统都不应该写进插件核心。

项目接入时继承 `MASGameAdapter`：

```gdscript
extends MASGameAdapter
class_name GameAbilityAdapter

func get_faction(actor: Node) -> StringName:
	if actor != null and actor.has_method("get_team"):
		return actor.get_team()
	return &"neutral"
```

插件核心只保留通用兜底逻辑。

## 6. 目标查询和目标筛选分工明确

`MASTargetQuery` 只负责找候选目标。`MASTargetFilterDef` 负责判断目标是否合法。

不要在每个技能里重复写这些判断：

- 敌我关系。
- 死亡和无敌。
- 必需 tag 和禁止 tag。
- 最大目标数量。

需要新查询方式时新增 `MASTargetQuery` 子类；需要新筛选条件时扩展 `MASTargetFilterDef` 或 adapter 标签入口。

## 7. 命中限制必须走 Runtime

多段命中、穿透、重复命中间隔和每目标命中上限必须经过：

- `MASHitRuleDef`
- `MASHitTracker`
- `MASAbilityRuntime.apply_effects_to_target()`

不要绕过 Runtime 直接遍历目标并调用 effect。绕过 Runtime 会漏掉目标筛选、命中记录、运行时词条和命中特效。

## 8. 新能力优先扩展，不优先改核心

常见扩展路径：

- 新技能类型：新增 `MASAbilityBehavior` 子类。
- 新效果：新增 `MASEffectDef` 子类。
- 新目标方式：新增 `MASTargetQuery` 子类。
- 新项目规则：新增 `MASGameAdapter` 子类。
- 新视觉阶段或反馈：扩展 `MASAbilityVisualDef` 或 adapter cue。

只有现有边界确实表达不了需求时，才修改 `core/`。

## 9. Editor 只处理资源工作流

`editor/` 目录只负责：

- 创建模板资源。
- 保存 `.tres`。
- 扫描已有技能。
- 打开 Inspector。
- 校验资源完整性。

不要把战斗、伤害、状态、输入或项目运行时逻辑写进编辑器 Dock。

## 10. 公共行为变更必须更新文档

如果修改这些目录的对外行为，需要同步更新文档：

- `core/`
- `resources/`
- `effects/`
- `behaviors/`
- `targeting/`
- `adapters/`
- `components/`

优先更新：

- `docs/architecture.md`
- `docs/integration_guide.md`
- `docs/example_abilities.md`
- 本文件
