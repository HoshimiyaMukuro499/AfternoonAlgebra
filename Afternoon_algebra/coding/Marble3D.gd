# Marble3D.gd
# 所有弹珠的基类，实现了通用的逐格移动、弹性碰撞、出界死亡、钩子机制。
# 子类通过重写钩子函数来实现各自特殊规则（如白球的步数加成、蓝球的随从生成等）。

class_name Marble2D
extends RigidBody2D

# ---------- 导出变量（可在编辑器中直接设置） ----------
# 弹珠颜色（默认为白色）
@export var color: MarbleConst.MarbleColor = MarbleConst.MarbleColor.WHITE
# 所属阵营（红方/蓝方）
@export var camp: MarbleConst.Camp = MarbleConst.Camp.RED

# ---------- 运行时状态 ----------
# 是否存活（出界或死亡后为 false）
var is_alive: bool = true
# 碰撞后被赋予的剩余步数（用于碰撞后继续移动）
var remaining_steps: int = 0
# 当前移动方向（与剩余步数配合使用）
var current_dir: int = 0

# 棋盘管理器引用（由 _ready() 自动查找）
var hex_grid: HexGrid3D = null
# 当前所在的六边形坐标（缓存，提高性能）
var hex_coord: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 自动查找场景中的 HexGrid3D 节点（兼容多种节点路径）
	hex_grid = get_node("/root/Game/HexGrid3D")
	if not hex_grid:
		var parent = get_parent()
		while parent:
			if parent is HexGrid3D:
				hex_grid = parent
				break
			parent = parent.get_parent()
	if hex_grid:
		# 从棋盘管理器中读取当前坐标（外部调用 place_marble 时会写入 meta 数据）
		hex_coord = hex_grid.get_marble_hex(self)


# ---------- 公共移动接口（供游戏流程调用） ----------
# 主动移动弹珠（玩家回合调用）
# direction: 0~5 方向索引，参考 MarbleConst.HexDirection
# steps: 1~5 移动步数
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	# 移动前钩子（子类可在此做准备工作，如蓝球生成随从）
	on_before_move(direction, steps)
	# 执行逐格移动，返回是否成功（未死亡）
	var success = _move_step_by_step(direction, steps)
	# 移动后钩子（子类可在此做清理工作，如蓝球移除随从）
	on_after_move(direction, steps, success)
	# 清除临时移动数据（防御）
	remaining_steps = 0
	current_dir = 0


# 碰撞后继续移动（由碰撞逻辑内部调用，外部一般不需要直接调用）
func continue_move(steps: int, direction: int) -> void:
	if not is_alive or steps <= 0:
		return
	_move_step_by_step(direction, steps)


# ---------- 核心逐格移动逻辑（私有） ----------
# 返回值：是否成功完成全部步数（未中途死亡）
func _move_step_by_step(direction: int, steps: int) -> bool:
	var remaining = steps
	var current = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
	
	while remaining > 0:
		# 计算下一步的邻居坐标
		var next = get_neighbor_hex(current, direction)
		
		# 1. 边界检查：超出棋盘半径则死亡
		if hex_grid.is_out_of_bounds(next.x, next.y):
			die()
			return false
		
		# 2. 检查目标格子是否有其他弹珠
		var other = hex_grid.get_marble_at(next.x, next.y)
		if other != null and other.is_alive:
			# 发生弹性碰撞
			# 当前弹珠停下，被撞弹珠获得当前剩余步数并继续移动
			var temp = remaining
			# 被撞弹珠有机会修改步数（例如白球被友方碰撞时步数+1）
			temp = other.on_collision_as_target(self, temp, direction)
			# 通知当前弹珠发生了碰撞（子类可重写做额外处理）
			on_collision_with(other, temp, direction)
			# 让被撞弹珠继续移动
			other.continue_move(temp, direction)
			# 当前弹珠停止移动（不再继续本次移动）
			break
		else:
			# 空位：直接移动
			hex_grid.move_marble(self, current, next)
			current = next
			remaining -= 1
			hex_coord = current   # 更新缓存坐标
			# 每移动一步后的钩子（例如绿球推挤可在此触发）
			on_step_moved(current)
	return true


# ---------- 钩子函数（子类可选择性重写） ----------
# 移动开始前调用（蓝球在此生成随从）
func on_before_move(direction: int, steps: int) -> void:
	pass

# 移动结束后调用（蓝球在此清理随从）
func on_after_move(direction: int, steps: int, success: bool) -> void:
	pass

# 每移动一步后调用（绿球推挤可用）
func on_step_moved(new_hex: Vector2) -> void:
	pass

# 当前弹珠主动碰撞其他弹珠时调用（可用于特殊碰撞效果）
func on_collision_with(other: Marble3D, remaining_steps: int, direction: int) -> void:
	pass

# 当前弹珠作为“被撞者”时，外部会调用此函数询问步数是否需要调整
# 返回值将作为实际传给 continue_move 的步数
# 默认实现是不修改（原样返回）
func on_collision_as_target(collider: Marble3D, incoming_steps: int, direction: int) -> int:
	return incoming_steps


# ---------- 死亡处理 ----------
# 弹珠死亡（出界或被碰撞致死）
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	on_death()   # 触发子类死亡钩子
	hex_grid.remove_marble_by_node(self)   # 从棋盘移除
	queue_free()  # 删除节点


# 死亡时的钩子（子类可重写，如黄球触发增益、蓝球清理随从）
func on_death() -> void:
	is_alive = false
	set_process(false)
	set_physics_process(false)  # 确保死亡弹珠不再参与物理模拟
	print("弹珠已出界/被淘汰，阵营：", camp)
	queue_free()
	print("%s 死亡" % get_class())


# ---------- 辅助方法 ----------
# 获取当前六边形坐标（优先使用缓存）
func get_current_hex() -> Vector2:
	return hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)

# 计算轴向坐标下指定方向的邻居坐标（公开方法，供辅助类调用）
# hex: 当前坐标 (q, r)
# dir: 0~5 方向索引
func get_neighbor_hex(hex: Vector2, dir: int) -> Vector2:
	var dirs = [
		Vector2(1, 0),   # 0: RIGHT
		Vector2(1, 1),   # 1: RIGHT_UP
		Vector2(0, 1),   # 2: LEFT_UP
		Vector2(-1, 0),  # 3: LEFT
		Vector2(-1, -1), # 4: LEFT_DOWN
		Vector2(0, -1)   # 5: RIGHT_DOWN
	]
	return hex + dirs[dir]
