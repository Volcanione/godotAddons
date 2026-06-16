# Modular Ability System 通用示例

相关文档：

- [架构分析](architecture.md)
- [项目接入指南](integration_guide.md)

## 使用方式

插件创建出的技能是 `MASAbilityDef` Resource。项目侧需要在角色、武器或技能控制节点上添加 `MASAbilityComponent`，并把技能资源加入 `starting_abilities`。

典型接入结构：

```text
Actor
  MASAbilityComponent
	starting_abilities = [res://resources/ability_defs/your_ability.tres]
```

项目输入层负责调用：

```gdscript
ability_component.try_activate_ability(&"your_ability", {
	"direction": Vector2.RIGHT,
	"point": target_world_position,
})
```

弹道技能通常读取：

```text
target_data.direction
```

范围技能通常读取：

```text
target_data.point
```

插件不会绑定项目的玩家、敌人、场景名或输入动作。阵营、伤害、状态和反馈都通过 `MASGameAdapter` 或目标组件接入项目。

## 技能视觉配置

`MASAbilityVisualDef` 负责技能表现资源。每个 `MASAbilityDef` 可以通过 `visual_def` 引用一份视觉配置。

常用字段：

```text
cast_scene    施法起手特效
active_scene  技能主体视觉，例如弹道、法阵或持续区域
hit_scene     命中特效
end_scene     技能结束特效
attach_mode   挂到 Runtime、释放者或当前场景
face_direction 是否按释放方向旋转
z_index       2D 绘制层级
```

使用方式：

1. 准备一个视觉场景，例如项目自己的弹道、范围或命中特效场景。
2. 创建或打开 `MASAbilityVisualDef` 资源。
3. 把视觉场景拖到 `active_scene`、`hit_scene` 等对应字段。
4. 打开技能的 `MASAbilityDef`，把 `visual_def` 指向这份视觉资源。
5. Runtime 会在对应阶段自动生成视觉节点。

注意：

- 如果 `visual_def.active_scene` 已配置，`MASAreaBehavior` 和 `MASProjectileBehavior` 不再叠加默认主体视觉。
- 命中特效和结束特效会挂到当前场景或 root fallback，避免 Runtime 销毁时一起被删。
- 视觉场景只负责表现，不应该直接写伤害、状态或目标筛选逻辑。

## 弹道技能模板

建议 Resource 组合：

```text
MASAbilityDef
  id: projectile_ability
  display_name: 弹道技能
  cooldown: 0.25
  duration: 0.0
  behavior: MASProjectileBehavior
  hit_rule: MASHitRuleDef
  target_filter: MASTargetFilterDef
  effects:
	- MASDamageEffect(value = 1, damage_type = physical)
```

释放时传入：

```text
target_data:
  direction: Vector2.RIGHT
```

说明：

- `MASProjectileBehavior` 负责移动 Runtime。
- `MASDamageEffect` 负责把伤害请求交给 `MASGameAdapter`。
- 具体碰撞层、Hurtbox 或 actor 解析由项目配置 `MASTargetQuery` 和 adapter。

## 范围技能模板

建议 Resource 组合：

```text
MASAbilityDef
  id: area_ability
  display_name: 范围技能
  cooldown: 3.0
  duration: 4.0
  behavior: MASAreaBehavior
  hit_rule: MASHitRuleDef(rehit_interval = 0.25, max_hit_count_per_target = 0)
  target_filter: MASTargetFilterDef(target_side = ENEMY)
  effects:
	- MASDamageEffect(value = 5, damage_type = magic)
```

释放时传入：

```text
target_data:
  point: target_world_position
```

说明：

- `MASAreaBehavior` 按 tick 间隔结算，不每帧结算。
- 目标筛选交给 `MASTargetFilterDef` 和 `MASGameAdapter`。
- 状态交给 `MASStatusReceiver`，不直接改目标脚本变量。
- 外力交给 `MASForceReceiver` 或项目移动组件，不直接改目标坐标。
