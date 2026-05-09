# Marble3D.gd（弹珠基类，挂在RigidBody3D上）
class_name Marble3D
extends RigidBody3D

# 导出配置，队友后续可以扩展
@export var color: MarbleConst.MarbleColor = MarbleConst.MarbleColor.WHITE
@export var camp: MarbleConst.Camp = MarbleConst.Camp.RED

var is_alive: bool = true
var remaining_steps: int = 0
var current_dir: int = 0

# 基础移动接口（队友后续实现具体逻辑）
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	remaining_steps = steps
	current_dir = direction
	print("弹珠移动指令：方向=", direction, " 步数=", steps)

# 死亡回调（出界/被撞时调用）
func on_death() -> void:
	is_alive = false
	set_process(false)
	print("弹珠已出界/被淘汰，阵营：", camp)
	queue_free()
