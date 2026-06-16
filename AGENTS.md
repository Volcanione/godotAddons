# 仓库指南

## 项目结构与模块组织

本仓库是一个 Godot 4.x 插件，主体位于 `modular_ability_system/`。插件声明文件是 `plugin.cfg`，编辑器入口是 `plugin.gd`。

- `core/`：技能运行时、上下文、命中记录和运行时属性。
- `resources/`：可复用的 `Resource` 配置，如技能、效果、状态、目标筛选、命中规则、词条和视觉配置。
- `effects/`：伤害、治疗、击退、状态施加、场景生成等 gameplay effect。
- `behaviors/`：自我、近战、范围、弹道等技能行为驱动。
- `targeting/`：目标查询策略。
- `components/`：挂到角色或对象上的组件。
- `editor/`：插件 Dock 和模板工厂。
- `docs/`：使用示例和贡献说明。

## 构建、测试与开发命令

当前没有独立构建步骤。修改后优先用 Godot 和定向文件检查验证：

```powershell
rg --files modular_ability_system
godot --headless --check-only -s addons/modular_ability_system/core/mas_ability_component.gd
godot --headless --editor --quit
```

Godot 命令需要在一个能以 `res://addons/modular_ability_system` 访问本目录的 Godot 项目中运行。如果 `godot` 不在 `PATH`，使用本机 Godot 可执行文件完整路径。

## 代码风格与命名约定

GDScript 使用 tab 缩进。尽量写类型标注，并给函数补明确返回类型。导出的配置放在 `Resource` 类中，运行时行为放在 `Node` 类中。公开类使用 `MAS` 前缀，文件名使用 snake_case，例如 `mas_ability_runtime.gd`。

标识符保持英文。解释 Godot 生命周期、信号回调或引擎 API 选择时，可以写简短中文方法注释。

## 测试指南

当前没有专门测试目录。每次行为变更都应运行最小可复现检查。至少对改过的 `.gd` 文件执行 `--check-only`；修改 `plugin.gd`、`editor/` 或导出资源时，还要手动确认插件能在编辑器中加载。

如果后续补测试，建议放在 `tests/mas/`，按被测单元命名，例如 `test_mas_ability_runtime.gd`。

## MAS 开发硬规则

- `Resource` 是模板，不在运行时直接改写。临时强化、Rogue 加成和 Buff 统一写入 `MASRuntimeStats` 或 `MASModifierDef`。
- 玩法逻辑和表现层分离。伤害、状态、目标筛选不能写进视觉场景；动画、特效、音效走 `MASAbilityVisualDef` 或 `MASGameAdapter.emit_cue()`。
- `MASAbilityBehavior` 只负责技能如何运行，例如移动、持续时间、tick 和目标查询时机；结算必须走 `MASAbilityRuntime.apply_effects_to_target()`。
- `MASEffectDef` 只描述效果请求，并通过 `MASGameAdapter` 接到项目系统。不要在 effect 中绑定具体项目的 `HealthComponent`、玩家或敌人脚本。
- 阵营、血量、事件总线、统计、音效等项目差异只进 adapter，不写进插件核心。
- 目标候选由 `MASTargetQuery` 查找，合法性由 `MASTargetFilterDef` 判断，不在技能脚本里重复写敌我、死亡、无敌、tag 判断。
- 命中次数、穿透、多段命中和重复命中间隔必须经过 `MASHitTracker` / `MASHitRuleDef`。
- 新技能类型优先新增 `MASAbilityBehavior`，新效果优先新增 `MASEffectDef` 子类，新目标方式优先新增 `MASTargetQuery`。现有抽象不够时再改核心。
- `editor/` 只负责创建、保存、扫描和校验资源，不放 gameplay 逻辑。
- 修改 `core/`、`resources/`、`effects/`、`behaviors/` 的对外行为时，同步更新 `docs/`。

## 提交与 Pull Request 规范

现有提交信息偏短祈使句，例如 `add modular ability system plugin`。提交应保持聚焦，说明变更的模块或用户可见行为。

PR 应包含简短摘要、涉及的插件区域、已运行的验证命令。编辑器 UI 或视觉行为变更需要附截图或短录屏。有关联 issue 时补链接，并说明是否需要项目侧额外配置。

## Agent 专用说明

改动保持小而准。除非任务明确要求，不要把玩法逻辑、表现层和编辑器 UI 混在一起改。保留 Resource 驱动架构；没有事先确认，不做大范围重构。详细规则见 `modular_ability_system/docs/development_rules.md`。
