@tool
extends RefCounted
class_name MASEditorTemplateFactory

const AbilityDef := preload("res://addons/modular_ability_system/resources/mas_ability_def.gd")
const VisualDef := preload("res://addons/modular_ability_system/resources/mas_ability_visual_def.gd")
const HitRuleDef := preload("res://addons/modular_ability_system/resources/mas_hit_rule_def.gd")
const TargetFilterDef := preload("res://addons/modular_ability_system/resources/mas_target_filter_def.gd")
const DamageEffect := preload("res://addons/modular_ability_system/effects/mas_damage_effect.gd")
const HealEffect := preload("res://addons/modular_ability_system/effects/mas_heal_effect.gd")
const ProjectileBehavior := preload("res://addons/modular_ability_system/behaviors/mas_projectile_behavior.gd")
const AreaBehavior := preload("res://addons/modular_ability_system/behaviors/mas_area_behavior.gd")
const MeleeBehavior := preload("res://addons/modular_ability_system/behaviors/mas_melee_behavior.gd")
const SelfBehavior := preload("res://addons/modular_ability_system/behaviors/mas_self_behavior.gd")
const AreaQuery := preload("res://addons/modular_ability_system/targeting/mas_area_2d_target_query.gd")

const TEMPLATE_PROJECTILE := "projectile"
const TEMPLATE_AREA := "area"
const TEMPLATE_SELF := "self"
const TEMPLATE_MELEE := "melee"

# 构建技能模板资源。
# Editor Dock 调用该方法先生成内存对象，便于后续保存或直接交给 Inspector 查看。
func build_template(options: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var ability_id := _read_ability_id(options, errors)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var template := String(options.get("template", TEMPLATE_PROJECTILE)).strip_edges().to_lower()
	var ability := AbilityDef.new()
	ability.id = StringName(ability_id)
	ability.display_name = String(options.get("display_name", ability_id))
	ability.cooldown = maxf(float(options.get("cooldown", _default_cooldown(template))), 0.0)
	ability.duration = maxf(float(options.get("duration", _default_duration(template))), 0.0)
	ability.target_filter = _create_target_filter(template)
	ability.hit_rule = _create_hit_rule(template, options)
	var effect := _create_primary_effect(template, options)
	var behavior := _create_behavior(template, options)
	var visual_def := _create_visual_def(template, options)
	if behavior == null:
		errors.append("Unknown template: %s" % template)
	if effect == null:
		errors.append("Template did not create an effect: %s" % template)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	ability.behavior = behavior
	ability.visual_def = visual_def
	ability.effects.append(effect)
	return {
		"ok": true,
		"ability": ability,
		"behavior": behavior,
		"effect": effect,
		"visual_def": visual_def,
		"hit_rule": ability.hit_rule,
		"target_filter": ability.target_filter,
	}

# 保存技能模板资源。
# 该方法会把 Ability、Behavior、Effect、HitRule、TargetFilter 拆成独立 .tres，方便后续单独编辑和复用。
func save_template(options: Dictionary) -> Dictionary:
	var result := build_template(options)
	if not result.get("ok", false):
		return result
	var errors: Array[String] = []
	var base_dir := String(options.get("base_dir", "res://resources")).strip_edges()
	if base_dir == "":
		base_dir = "res://resources"
	var ability_id := String(result["ability"].id)
	var files := {
		"ability": _join_path(_join_path(base_dir, "ability_defs"), "%s.tres" % ability_id),
		"behavior": _join_path(_join_path(base_dir, "ability_behaviors"), "%s_behavior.tres" % ability_id),
		"effect_0": _join_path(_join_path(base_dir, "effect_defs"), "%s_effect.tres" % ability_id),
		"hit_rule": _join_path(_join_path(base_dir, "hit_rules"), "%s_hit_rule.tres" % ability_id),
		"target_filter": _join_path(_join_path(base_dir, "target_filters"), "%s_target_filter.tres" % ability_id),
		"visual": _join_path(_join_path(base_dir, "visual_defs"), "%s_visual.tres" % ability_id),
	}
	_save_resource(result["behavior"], files["behavior"], errors)
	_save_resource(result["effect"], files["effect_0"], errors)
	_save_resource(result["hit_rule"], files["hit_rule"], errors)
	_save_resource(result["target_filter"], files["target_filter"], errors)
	_save_resource(result["visual_def"], files["visual"], errors)
	_save_resource(result["ability"], files["ability"], errors)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "files": files}
	result["files"] = files
	return result

# 查找技能配置资源。
# 面板刷新技能列表时使用该方法递归扫描目录，只返回能加载为 MASAbilityDef 的资源路径。
func find_ability_paths(search_dir: String) -> Array[String]:
	var result: Array[String] = []
	_scan_ability_paths(search_dir, result)
	result.sort()
	return result

# 校验技能资源。
# 保存后或选中已有技能时调用，帮助策划及时看到缺少行为、效果或 ID 的问题。
func validate_ability(ability: MASAbilityDef) -> Array[String]:
	var errors: Array[String] = []
	if ability == null:
		return ["Ability is empty."]
	if ability.id == &"":
		errors.append("Ability id is empty.")
	if ability.behavior == null:
		errors.append("Ability behavior is empty.")
	if ability.effects.is_empty():
		errors.append("Ability has no effects.")
	if ability.target_filter == null:
		errors.append("Ability target filter is empty.")
	if ability.hit_rule == null:
		errors.append("Ability hit rule is empty.")
	return errors

# 读取并校验技能 ID。
# 资源文件名、AbilityDef.id 和后续搜索都依赖稳定英文 ID，因此这里只允许字母开头的 snake/camel 标识符。
func _read_ability_id(options: Dictionary, errors: Array[String]) -> String:
	var ability_id := String(options.get("ability_id", "")).strip_edges()
	if ability_id == "":
		errors.append("Ability id is required.")
		return ""
	var regex := RegEx.new()
	regex.compile("^[A-Za-z][A-Za-z0-9_]*$")
	if regex.search(ability_id) == null:
		errors.append("Ability id must start with a letter and only contain letters, numbers, or underscore.")
	return ability_id

# 创建行为资源。
# 不同模板只替换 Behavior，AbilityDef 和效果流水线保持同一套 MAS 架构。
func _create_behavior(template: String, options: Dictionary) -> Resource:
	match template:
		TEMPLATE_PROJECTILE:
			var behavior := ProjectileBehavior.new()
			behavior.speed = maxf(float(options.get("speed", 320.0)), 0.0)
			behavior.max_lifetime = maxf(float(options.get("max_lifetime", 2.0)), 0.05)
			behavior.spawn_distance = maxf(float(options.get("spawn_distance", 18.0)), 0.0)
			behavior.target_query = _create_area_query(options, 12.0)
			return behavior
		TEMPLATE_AREA:
			var behavior := AreaBehavior.new()
			behavior.radius = maxf(float(options.get("radius", 96.0)), 0.0)
			behavior.tick_interval = maxf(float(options.get("tick_interval", 0.25)), 0.0)
			behavior.follow_caster = bool(options.get("follow_caster", false))
			behavior.target_query = _create_area_query(options, behavior.radius)
			return behavior
		TEMPLATE_SELF:
			return SelfBehavior.new()
		TEMPLATE_MELEE:
			var behavior := MeleeBehavior.new()
			behavior.active_time = maxf(float(options.get("active_time", 0.1)), 0.01)
			return behavior
	return null

# 创建目标查询资源。
# 弹道和范围模板都用 MASArea2DTargetQuery 作为第一版通用命中检测入口。
func _create_area_query(options: Dictionary, default_radius: float) -> MASArea2DTargetQuery:
	var query := AreaQuery.new()
	query.radius = maxf(float(options.get("query_radius", default_radius)), 0.0)
	query.collision_mask = int(options.get("collision_mask", 0))
	return query

# 创建主要效果资源。
# 第一版模板只生成一个主效果，复杂组合可以在创建后继续通过 Inspector 增加。
func _create_primary_effect(template: String, options: Dictionary) -> Resource:
	if template == TEMPLATE_SELF:
		var heal := HealEffect.new()
		heal.value = maxf(float(options.get("heal", options.get("damage", 1.0))), 0.0)
		return heal
	var damage := DamageEffect.new()
	damage.value = maxf(float(options.get("damage", 1.0)), 0.0)
	damage.damage_type = StringName(options.get("damage_type", &"physical"))
	return damage

# 创建视觉配置资源。
# 模板只创建引用入口，不强制绑定具体美术场景；项目可以后续在 Inspector 里拖入特效场景。
func _create_visual_def(template: String, options: Dictionary) -> Resource:
	var visual := VisualDef.new()
	visual.attach_mode = VisualDef.AttachMode.RUNTIME
	visual.face_direction = template == TEMPLATE_PROJECTILE or template == TEMPLATE_MELEE
	visual.follow_caster = bool(options.get("follow_caster", false))
	visual.scale = Vector2.ONE
	visual.z_index = int(options.get("z_index", 0))
	visual.auto_free_time = maxf(float(options.get("visual_auto_free_time", 0.0)), 0.0)
	return visual

# 创建目标筛选资源。
# 自身模板默认只选 SELF，其余攻击模板默认选 ENEMY，避免新技能误伤自己。
func _create_target_filter(template: String) -> MASTargetFilterDef:
	var filter := TargetFilterDef.new()
	if template == TEMPLATE_SELF:
		filter.target_side = TargetFilterDef.TargetSide.SELF
	else:
		filter.target_side = TargetFilterDef.TargetSide.ENEMY
	return filter

# 创建命中规则资源。
# 不同模板按当前 MAS 行为填入合理默认值，后续可以在 Inspector 里继续调整。
func _create_hit_rule(template: String, options: Dictionary) -> MASHitRuleDef:
	var rule := HitRuleDef.new()
	match template:
		TEMPLATE_AREA:
			rule.max_hit_count_per_target = 0
			rule.hit_once_per_cast = false
			rule.rehit_interval = maxf(float(options.get("tick_interval", 0.25)), 0.0)
			rule.tick_interval = rule.rehit_interval
		TEMPLATE_PROJECTILE:
			rule.max_hit_count_per_target = 1
			rule.hit_once_per_cast = true
			rule.pierce_count = max(0, int(options.get("pierce_count", 0)))
		_:
			rule.max_hit_count_per_target = 1
			rule.hit_once_per_cast = true
	return rule

# 返回模板默认冷却。
# 面板没有显式输入时使用这些值，保证一键创建的技能能直接测试。
func _default_cooldown(template: String) -> float:
	match template:
		TEMPLATE_PROJECTILE:
			return 0.25
		TEMPLATE_AREA:
			return 3.0
		TEMPLATE_SELF:
			return 2.0
		TEMPLATE_MELEE:
			return 0.5
	return 1.0

# 返回模板默认持续时间。
# 弹道由自身 lifetime 控制，范围技能由 AbilityRuntime duration 控制。
func _default_duration(template: String) -> float:
	match template:
		TEMPLATE_AREA:
			return 4.0
		TEMPLATE_MELEE:
			return 0.15
	return 0.0

# 保存单个 Resource。
# ResourceSaver 是 Godot 的资源落盘入口，保存前先确保父目录存在。
func _save_resource(resource: Resource, path: String, errors: Array[String]) -> void:
	var dir_error := _ensure_dir(path.get_base_dir())
	if dir_error != OK:
		errors.append("Failed to create directory for %s, error=%s" % [path, dir_error])
		return
	var save_error := ResourceSaver.save(resource, path)
	if save_error != OK:
		errors.append("Failed to save %s, error=%s" % [path, save_error])

# 确保目录存在。
# Godot 的 res:// 和 user:// 都需要先转换为绝对路径再递归创建。
func _ensure_dir(path: String) -> int:
	var absolute_path := ProjectSettings.globalize_path(path)
	return DirAccess.make_dir_recursive_absolute(absolute_path)

# 递归扫描技能资源路径。
# 为了避免强制项目按固定目录组织，这里允许从 base_dir 下递归查找全部 .tres/.res。
func _scan_ability_paths(dir_path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path := _join_path(dir_path, file_name)
		if dir.current_is_dir():
			_scan_ability_paths(child_path, result)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := ResourceLoader.load(child_path)
			if resource is MASAbilityDef:
				result.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()

# 拼接资源路径。
# 统一处理末尾斜杠，避免保存时出现重复 `/`。
func _join_path(base: String, child: String) -> String:
	if base.ends_with("/"):
		return base + child
	return base + "/" + child
