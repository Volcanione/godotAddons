@tool
extends VBoxContainer

const TemplateFactory := preload("res://addons/modular_ability_system/editor/mas_ability_template_factory.gd")

var editor_interface: Object
var factory := TemplateFactory.new()
var base_dir_edit: LineEdit
var ability_id_edit: LineEdit
var display_name_edit: LineEdit
var template_option: OptionButton
var damage_spin: SpinBox
var cooldown_spin: SpinBox
var duration_spin: SpinBox
var radius_spin: SpinBox
var ability_list: ItemList
var detail_label: Label
var status_label: Label
var selected_ability_path: String = ""

# 注入编辑器接口。
# plugin.gd 创建 Dock 后调用该方法，Dock 通过它打开 Inspector 和刷新编辑器资源系统。
func setup(new_editor_interface: EditorInterface) -> void:
	editor_interface = new_editor_interface

# Dock 进入编辑器场景树时调用。
# Godot 会在 add_control_to_dock 后触发 `_ready()`，这里构建全部控件。
func _ready() -> void:
	_build_ui()
	_refresh_ability_list()

# 构建 Dock UI。
# 第一版只做基础参数和创建向导，不做复杂节点图，避免插件 UI 过早膨胀。
func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 0)
	_add_title()
	_add_creator_panel()
	_add_list_panel()
	_add_detail_panel()

# 添加标题。
# 标题用于在 Godot 右侧 Dock 中快速识别当前插件面板。
func _add_title() -> void:
	var title := Label.new()
	title.text = "Modular Ability System"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

# 添加技能创建向导。
# 该区域把模板、ID、数值和保存目录转成 TemplateFactory 的保存参数。
func _add_creator_panel() -> void:
	var panel := VBoxContainer.new()
	panel.add_child(_make_label("创建技能"))
	template_option = OptionButton.new()
	template_option.add_item("弹道 Projectile")
	template_option.add_item("范围 Area")
	template_option.add_item("自身 Self")
	template_option.add_item("近战 Melee")
	template_option.item_selected.connect(_on_template_selected)
	panel.add_child(template_option)
	ability_id_edit = _make_line_edit("basic_projectile")
	panel.add_child(_with_label("Ability ID", ability_id_edit))
	display_name_edit = _make_line_edit("基础弹道")
	panel.add_child(_with_label("显示名", display_name_edit))
	base_dir_edit = _make_line_edit("res://resources")
	panel.add_child(_with_label("保存根目录", base_dir_edit))
	damage_spin = _make_spin(1.0, 0.0, 99999.0, 0.5)
	panel.add_child(_with_label("伤害/治疗值", damage_spin))
	cooldown_spin = _make_spin(0.25, 0.0, 999.0, 0.05)
	panel.add_child(_with_label("冷却", cooldown_spin))
	duration_spin = _make_spin(0.0, 0.0, 999.0, 0.1)
	panel.add_child(_with_label("持续时间", duration_spin))
	radius_spin = _make_spin(12.0, 0.0, 2048.0, 1.0)
	panel.add_child(_with_label("命中/范围半径", radius_spin))
	var create_button := Button.new()
	create_button.text = "创建并保存技能"
	create_button.pressed.connect(_on_create_pressed)
	panel.add_child(create_button)
	add_child(panel)
	add_child(HSeparator.new())

# 添加技能列表区域。
# 列表从保存根目录递归读取 MASAbilityDef，方便快速打开已有技能。
func _add_list_panel() -> void:
	var row := HBoxContainer.new()
	row.add_child(_make_label("技能列表"))
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_refresh_ability_list)
	row.add_child(refresh_button)
	add_child(row)
	ability_list = ItemList.new()
	ability_list.custom_minimum_size = Vector2(0, 180)
	ability_list.item_selected.connect(_on_ability_selected)
	add_child(ability_list)

# 添加详情区域。
# 详情只显示核心字段和校验结果，复杂编辑交给 Godot Inspector 保持和 Resource 完全适配。
func _add_detail_panel() -> void:
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = "未选择技能"
	add_child(detail_label)
	var button_row := HBoxContainer.new()
	var inspect_button := Button.new()
	inspect_button.text = "打开 Inspector"
	inspect_button.pressed.connect(_on_inspect_pressed)
	button_row.add_child(inspect_button)
	var validate_button := Button.new()
	validate_button.text = "校验"
	validate_button.pressed.connect(_on_validate_pressed)
	button_row.add_child(validate_button)
	add_child(button_row)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

# 创建标签。
# 多处 UI 需要普通 Label，集中创建便于统一最小尺寸和文本。
func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

# 创建文本输入框。
# 技能 ID、显示名和保存目录都使用 LineEdit，保持编辑器操作直接。
func _make_line_edit(default_text: String) -> LineEdit:
	var line_edit := LineEdit.new()
	line_edit.text = default_text
	return line_edit

# 创建数字输入框。
# 数值字段使用 SpinBox，避免手动输入无效数字。
func _make_spin(value: float, min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	return spin

# 给控件包一层标签。
# Godot 原生 Inspector 不参与这里的向导输入，所以用简单 HBox 保持字段可读。
func _with_label(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

# 模板切换回调。
# 选择不同技能模板时自动填入更适合的默认持续时间、冷却和半径。
func _on_template_selected(index: int) -> void:
	match index:
		0:
			ability_id_edit.text = "basic_projectile"
			display_name_edit.text = "基础弹道"
			cooldown_spin.value = 0.25
			duration_spin.value = 0.0
			radius_spin.value = 12.0
		1:
			ability_id_edit.text = "area_ability"
			display_name_edit.text = "范围技能"
			cooldown_spin.value = 3.0
			duration_spin.value = 4.0
			radius_spin.value = 96.0
		2:
			ability_id_edit.text = "self_heal"
			display_name_edit.text = "自我治疗"
			cooldown_spin.value = 2.0
			duration_spin.value = 0.0
			radius_spin.value = 0.0
		3:
			ability_id_edit.text = "melee_slash"
			display_name_edit.text = "近战挥砍"
			cooldown_spin.value = 0.5
			duration_spin.value = 0.15
			radius_spin.value = 32.0

# 创建按钮回调。
# 从 UI 收集参数，调用 TemplateFactory 保存 Resource，然后刷新列表并打开新技能。
func _on_create_pressed() -> void:
	var result: Dictionary = factory.save_template(_collect_template_options())
	if not result.get("ok", false):
		status_label.text = "创建失败：\n%s" % "\n".join(result.get("errors", []))
		return
	var files: Dictionary = result.get("files", {})
	selected_ability_path = files.get("ability", "")
	status_label.text = "已创建：%s" % selected_ability_path
	_refresh_editor_filesystem()
	_refresh_ability_list()
	_select_path_in_list(selected_ability_path)
	_inspect_selected_ability()

# 收集模板参数。
# 这个方法是 UI 到模板工厂的唯一数据转换入口，避免按钮回调里堆复杂逻辑。
func _collect_template_options() -> Dictionary:
	return {
		"template": _get_selected_template(),
		"ability_id": ability_id_edit.text,
		"display_name": display_name_edit.text,
		"base_dir": base_dir_edit.text,
		"damage": damage_spin.value,
		"heal": damage_spin.value,
		"cooldown": cooldown_spin.value,
		"duration": duration_spin.value,
		"radius": radius_spin.value,
		"query_radius": radius_spin.value,
	}

# 读取当前模板 ID。
# OptionButton 只保存显示文本，这里把索引映射成 TemplateFactory 使用的稳定英文 ID。
func _get_selected_template() -> String:
	match template_option.selected:
		0:
			return TemplateFactory.TEMPLATE_PROJECTILE
		1:
			return TemplateFactory.TEMPLATE_AREA
		2:
			return TemplateFactory.TEMPLATE_SELF
		3:
			return TemplateFactory.TEMPLATE_MELEE
	return TemplateFactory.TEMPLATE_PROJECTILE

# 刷新技能列表。
# 通过工厂递归查找 AbilityDef，列表 metadata 保存真实资源路径。
func _refresh_ability_list() -> void:
	if ability_list == null:
		return
	ability_list.clear()
	for path in factory.find_ability_paths(_get_scan_dir()):
		var index := ability_list.add_item(path.get_file().get_basename())
		ability_list.set_item_metadata(index, path)

# 获取扫描目录。
# 如果保存根目录为空，则回退到 res://resources，保证刷新按钮不会报错。
func _get_scan_dir() -> String:
	if base_dir_edit == null or base_dir_edit.text.strip_edges() == "":
		return "res://resources"
	return base_dir_edit.text.strip_edges()

# 技能列表选择回调。
# 选中后更新详情文本，不直接修改资源。
func _on_ability_selected(index: int) -> void:
	selected_ability_path = String(ability_list.get_item_metadata(index))
	_update_detail()

# 更新详情文本。
# 详情只读取 Resource 的关键字段，复杂内容继续通过 Inspector 编辑。
func _update_detail() -> void:
	var ability := _load_selected_ability()
	if ability == null:
		detail_label.text = "未选择技能"
		return
	detail_label.text = "路径：%s\nID：%s\n显示名：%s\n冷却：%s\n持续：%s\n效果数：%s\n行为：%s" % [
		selected_ability_path,
		ability.id,
		ability.display_name,
		ability.cooldown,
		ability.duration,
		ability.effects.size(),
		ability.behavior.get_class() if ability.behavior != null else "Empty",
	]

# Inspector 按钮回调。
# 使用 Godot 原生 Inspector 编辑 Resource，保证字段展示和插件 Resource 完全一致。
func _on_inspect_pressed() -> void:
	_inspect_selected_ability()

# 打开选中技能到 Inspector。
# EditorInterface 是 Godot 编辑器 API，这里优先调用 edit_resource，让 Resource 真正进入原生资源编辑入口。
func _inspect_selected_ability() -> bool:
	_sync_selected_path_from_list()
	var ability := _load_selected_ability()
	if ability == null:
		_set_status("请先在技能列表中选择一个技能，或先创建并保存技能。")
		return false
	if editor_interface == null:
		_set_status("编辑器接口不可用，请重新启用插件或重启 Godot。")
		return false
	if editor_interface.has_method("edit_resource"):
		editor_interface.call("edit_resource", ability)
		_set_status("已打开 Inspector：%s" % selected_ability_path)
		return true
	if editor_interface.has_method("inspect_object"):
		editor_interface.call("inspect_object", ability)
		_set_status("已打开 Inspector：%s" % selected_ability_path)
		return true
	_set_status("当前编辑器接口不支持打开 Resource。")
	return false

# 校验按钮回调。
# 直接调用 TemplateFactory 的校验逻辑，把结果显示在 Dock 底部。
func _on_validate_pressed() -> void:
	var ability := _load_selected_ability()
	var errors := factory.validate_ability(ability)
	if errors.is_empty():
		status_label.text = "校验通过"
	else:
		status_label.text = "校验失败：\n%s" % "\n".join(errors)

# 加载当前选中的技能。
# ResourceLoader 负责读取 .tres；类型不正确时返回 null，避免 Dock 报错。
func _load_selected_ability() -> MASAbilityDef:
	if selected_ability_path == "":
		return null
	var resource := ResourceLoader.load(selected_ability_path)
	if resource is MASAbilityDef:
		return resource
	return null

# 从列表同步当前选中路径。
# 用户可能只点了列表项目或刷新后还保留选择，这里在打开 Inspector 前再读一次 ItemList 状态。
func _sync_selected_path_from_list() -> void:
	if ability_list == null:
		return
	var selected_items := ability_list.get_selected_items()
	if selected_items.is_empty():
		return
	selected_ability_path = String(ability_list.get_item_metadata(selected_items[0]))

# 在列表里选中新创建的路径。
# 创建后自动定位到新技能，减少用户还要手动寻找的步骤。
func _select_path_in_list(path: String) -> void:
	for index in ability_list.item_count:
		if String(ability_list.get_item_metadata(index)) == path:
			ability_list.select(index)
			_update_detail()
			return

# 刷新编辑器资源系统。
# ResourceSaver 写入文件后通知 Godot 文件系统扫描，避免编辑器文件面板短时间看不到新资源。
func _refresh_editor_filesystem() -> void:
	if editor_interface == null:
		return
	if not editor_interface.has_method("get_resource_filesystem"):
		return
	var filesystem = editor_interface.call("get_resource_filesystem")
	if filesystem != null:
		filesystem.scan()

# 设置 Dock 状态文本。
# 所有用户可见反馈都走这个方法，避免按钮点击后静默无反应。
func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
