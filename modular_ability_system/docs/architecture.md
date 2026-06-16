# Modular Ability System 架构分析

MAS 是一个以 `Resource` 为配置核心、以 `Node` 为运行时承载的 Godot 4.x 技能插件。它不绑定具体项目的玩家、敌人、血量、输入或动画系统，而是通过配置资源、运行时节点和 `MASGameAdapter` 把通用技能流程接到项目侧。

## 核心调用链

```text
输入层
  -> MASAbilityComponent.try_activate_ability()
	-> 创建 MASAbilityRuntime
	  -> MASAbilityBehavior.start/tick/stop
		-> 查询目标
		-> MASAbilityRuntime.apply_effects_to_target()
		  -> MASEffectDef.apply()
			-> MASGameAdapter.apply_damage/apply_heal/apply_status/apply_force()
	  -> MASAbilityVisualDef.spawn_cast/spawn_active/spawn_hit/spawn_end()
```

## 主要模块职责

### `MASAbilityDef`

技能模板资源。它保存技能 ID、显示名、冷却、持续时间、行为、目标筛选、命中规则、效果列表、视觉配置、动画 key 和 cue tags。它不应该在运行时被直接改写；临时强化通过 `MASModifierDef` 写入 `MASRuntimeStats`。

### `MASAbilityComponent`

挂在角色、武器或技能控制节点上。它管理已授予技能、冷却、运行时词条，并在释放时创建 `MASAbilityRuntime`。项目输入层只需要调用 `try_activate_ability()`。

### `MASAbilityRuntime`

表示一次技能释放。它保存释放者、目标数据、适配器、运行时数值和命中记录。Runtime 负责分发 Behavior、统一执行效果、生成视觉，并在结束后 `queue_free()`。

### `MASAbilityBehavior`

技能行为资源，只负责“技能如何运行”。内置行为包括：

- `MASSelfBehavior`：立即对自身结算。
- `MASMeleeBehavior`：短时间近战窗口。
- `MASAreaBehavior`：按 tick 间隔扫描范围并结算。
- `MASProjectileBehavior`：移动 Runtime，自带方向、寿命、穿透判断和目标查询入口。

### `MASEffectDef`

效果资源负责描述“命中后发生什么”。内置效果包括伤害、治疗、施加状态、外力和生成场景。实际项目逻辑不写死在效果中，而是委托给 `MASGameAdapter`。

### `MASGameAdapter`

项目接入层。默认实现读取 `player` / `enemy` group 判断阵营，并尝试调用目标的 `apply_damage`、`take_damage`、`apply_heal`、`apply_status`、`apply_force`。正式项目通常应继承它，接入自己的血量、阵营、事件、音效或统计系统。

### `MASAbilityVisualDef`

技能表现资源。支持 `cast_scene`、`active_scene`、`hit_scene`、`end_scene`，并提供挂载方式、朝向、缩放、层级和自动释放时间。视觉资源只负责表现，不应该写伤害、状态或目标筛选逻辑。

## 数据边界

- `target_data.direction`：弹道和朝向常用。
- `target_data.point`：范围技能和手动选点常用。
- `target_data.target` / `targets`：手动传入目标时使用。
- `MASEffectContext`：效果执行时的统一上下文，包含释放者、目标、技能 ID、命中点、方向、运行时数值和 tags。

## 扩展建议

- 新技能类型：新增 `MASAbilityBehavior` 子类。
- 新效果：继承 `MASEffectDef` 并覆写 `apply()`。
- 新目标查询：继承 `MASTargetQuery`。
- 项目规则接入：继承 `MASGameAdapter`，不要在插件核心里硬写项目血量或阵营逻辑。
- 视觉/音效接入：优先走 `MASAbilityVisualDef` 或 adapter cue，不要把表现逻辑写进 damage/status effect。
