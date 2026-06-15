extends Node
class_name MASForceReceiver

signal force_requested(force_data: Dictionary, context: MASEffectContext)

# 接收外力请求。
# 插件不直接移动目标，只发出信号，让具体 MovementComponent 决定如何处理击退或牵引。
func apply_force(force_data: Dictionary, context: MASEffectContext = null) -> void:
	force_requested.emit(force_data, context)
