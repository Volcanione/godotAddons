extends Node
class_name MASAbilityComponent

signal ability_granted(ability_id: StringName, ability_def: MASAbilityDef)
signal ability_activated(ability_id: StringName, runtime: MASAbilityRuntime)
signal cooldown_started(ability_id: StringName, duration: float)

@export var starting_abilities: Array[Resource] = []

var abilities: Dictionary = {}
var cooldowns: Dictionary = {}
var adapter: MASGameAdapter = MASGameAdapter.new()
var modifiers: Array[Resource] = []

# 节点进入场景树时调用。
# Godot 会在 `_ready()` 中保证子节点已可用，这里适合注册编辑器里配置的初始技能。
func _ready() -> void:
	for ability in starting_abilities:
		if ability is MASAbilityDef:
			grant_ability(ability)

# 每帧更新冷却。
# 冷却不依赖物理碰撞，因此使用 `_process(delta)` 即可。
func _process(delta: float) -> void:
	_update_cooldowns(delta)

# 设置游戏适配器。
# 具体项目可以传入自己的 adapter，把伤害、状态、音效接到项目系统。
func set_adapter(new_adapter: MASGameAdapter) -> void:
	if new_adapter != null:
		adapter = new_adapter

# 授予一个技能。
# 只保存 Resource 引用，不复制配置，确保多个角色可以共享同一份技能模板。
func grant_ability(ability_def: MASAbilityDef) -> void:
	if ability_def == null or ability_def.id == &"":
		return
	abilities[ability_def.id] = ability_def
	ability_granted.emit(ability_def.id, ability_def)

# 移除一个技能。
# 移除时同步清理冷却，避免重新获得技能后继承旧状态。
func remove_ability(ability_id: StringName) -> void:
	abilities.erase(ability_id)
	cooldowns.erase(ability_id)

# 判断技能是否可释放。
# 当前第一版只检查是否拥有技能和冷却，资源消耗、沉默、眩晕后续再接入。
func can_activate(ability_id: StringName) -> bool:
	if not abilities.has(ability_id):
		return false
	return get_cooldown_remaining(ability_id) <= 0.0

# 尝试释放技能。
# 成功时创建 MASAbilityRuntime 作为子节点，由 Runtime 自己推进生命周期。
func try_activate_ability(ability_id: StringName, target_data: Dictionary = {}) -> MASAbilityRuntime:
	if not can_activate(ability_id):
		return null
	var ability_def: MASAbilityDef = abilities[ability_id]
	var runtime := MASAbilityRuntime.new()
	runtime.setup(ability_def, get_parent(), target_data, adapter, modifiers)
	add_child(runtime)
	runtime.start()
	_start_cooldown(ability_id, runtime.runtime_stats.get_final_cooldown())
	ability_activated.emit(ability_id, runtime)
	return runtime

# 获取技能剩余冷却。
# UI 和输入层可以用它决定是否显示技能可用。
func get_cooldown_remaining(ability_id: StringName) -> float:
	return float(cooldowns.get(ability_id, 0.0))

# 添加运行时词条。
# Rogue 加成和装备加成通过词条影响后续释放，不直接改 AbilityDef。
func add_modifier(modifier: Resource) -> void:
	if modifier != null:
		modifiers.append(modifier)

# 清空运行时词条。
# 新一局游戏、重置角色或卸下装备时可以调用该方法。
func clear_modifiers() -> void:
	modifiers.clear()

# 启动冷却。
# 冷却统一存在 AbilityComponent 中，避免每个技能 Runtime 自己维护可释放状态。
func _start_cooldown(ability_id: StringName, duration: float) -> void:
	cooldowns[ability_id] = maxf(duration, 0.0)
	cooldown_started.emit(ability_id, cooldowns[ability_id])

# 更新所有冷却。
# 先复制 key 列表再修改字典，避免遍历时删除导致迭代问题。
func _update_cooldowns(delta: float) -> void:
	for ability_id in cooldowns.keys():
		cooldowns[ability_id] = maxf(float(cooldowns[ability_id]) - delta, 0.0)
