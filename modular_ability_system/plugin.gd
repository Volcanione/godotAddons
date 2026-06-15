@tool
extends EditorPlugin

const MASEditorDock := preload("res://addons/modular_ability_system/editor/mas_editor_dock.gd")

var editor_dock: Control

# 插件进入编辑器时调用。
# Godot 启用插件后会调用该方法，这里注册 MAS 编辑器 Dock 作为技能配置入口。
func _enter_tree() -> void:
	editor_dock = MASEditorDock.new()
	editor_dock.name = "MAS"
	editor_dock.setup(get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, editor_dock)

# 插件从编辑器卸载时调用。
# 关闭插件或重载项目时移除 Dock，避免编辑器里残留无效控件。
func _exit_tree() -> void:
	if editor_dock != null:
		remove_control_from_docks(editor_dock)
		editor_dock.queue_free()
		editor_dock = null
