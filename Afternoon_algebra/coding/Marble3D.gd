# Marble3D.gd
# 弹珠基类，所有颜色弹珠（白、蓝、绿、红、黑、黄）都继承此类。
# 负责基础的移动、碰撞、出界、死亡等公共逻辑。
class_name Marble3D
extends RigidBody3D

# ---------- 导出变量（可在编辑器中调整） ----------
# 弹珠的颜色类型（白/蓝/绿/红/黑/黄），定义在 MarbleConst 中
@export var color: MarbleConst.MarbleColor = MarbleConst.MarbleColor.WHITE
# 弹珠所属阵营（红方/蓝方）
@export var camp: MarbleConst.Camp = MarbleConst.Camp.RED

# ---------- 运行时状态 ----------
# 弹珠是否还存活（未出界/未被淘汰）
var is_alive: bool = true
# 碰撞后被赋予的剩余步数（用于继续移动）
var remaining_steps: int = 0
# 当前移动方向（0~5），配合剩余步数使用
var current_dir: int = 0

# 棋盘管理器的引用（由子类初始化时获取）
var hex_grid: HexGrid3D = null
# 当前所在六边形坐标（轴向坐标 q, r），缓存以提高性能
var hex_coord: Vector2 = Vector2.ZERO

# ---------- 初始化 ----------
func _ready() -> void:
	# 获取棋盘管理器节点（假设位于 /root/Game/HexGrid3D，可根据实际调整）
	hex_grid = get_node("/root/Game/HexGrid3D")
	if hex_grid:
		# 从管理器中读取当前坐标（place_marble 时会写入 meta）
		hex_coord = hex_grid.get_marble_hex(self)

# ---------- 公共移动接口 ----------
# 主动移动弹珠（由玩家回合调用）
# direction: 0~5 方向（对应 HexDirection 枚举）
# steps: 要移动的步数（1~5）
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	# 移动前钩子（子类可在此做准备工作，如蓝球生成随从）
	on_before_move(direction, steps)
	# 执行逐格移动，返回是否成功（未死亡）
	var success = _move_step_by_step(direction, steps)
	# 移动后钩子（子类可在此做清理，如蓝球移除随从）
	on_after_move(direction, steps, success)
	# 清除临时步数和方向
	remaining_steps = 0
	current_dir = 0

# 被碰撞后继续移动（由碰撞逻辑调用）
# steps: 剩余步数
# direction: 移动方向
func continue_move(steps: int, direction: int) -> void:
	if not is_alive or steps <= 0:
		return
	_move_step_by_step(direction, steps)

# ---------- 核心逐格移动逻辑 ----------
# 返回值：是否成功完成移动（未中途死亡）
func _move_step_by_step(direction: int, steps: int) -> bool:
	var remaining = steps
	# 获取当前坐标（优先使用缓存的坐标，否则从棋盘读取）
	var current = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
	
	while remaining > 0:
		# 计算下一步的邻居坐标
		var next = _get_neighbor_hex(current, direction)
		
		# 1. 出界检查
		if hex_grid.is_out_of_bounds(next.x, next.y):
			die()        # 死亡并移出棋盘
			return false
		
		# 2. 检查目标格子是否有其他存活弹珠
		var other = hex_grid.get_marble_at(next.x, next.y)
		if other != null and other.is_alive:
			# 有弹珠 → 弹性碰撞
			var temp = remaining
			# 调用被撞弹珠的碰撞回调，让其有机会修改步数（例如白球被友方碰撞时+1）
			temp = other.on_collision_as_target(self, temp, direction)
			# 调用本弹珠的碰撞回调（子类可额外处理）
			on_collision_with(other, temp, direction)
			# 让被撞弹珠继续移动
			other.continue_move(temp, direction)
			# 当前弹珠停止移动（位置不变）
			break
		else:
			# 空位 → 直接移动
			hex_grid.move_marble(self, current, next)
			current = next
			remaining -= 1
			hex_coord = current          # 更新缓存坐标
			on_step_moved(current)       # 每步移动后的钩子
	return true

# ---------- 钩子函数（供子类重写，实现各自特殊能力） ----------
# 移动开始前调用
func on_before_move(direction: int, steps: int) -> void:
	pass

# 移动结束后调用
func on_after_move(direction: int, steps: int, success: bool) -> void:
	pass

# 每移动一步后调用（可用于绿球的推挤等即时效果）
func on_step_moved(new_hex: Vector2) -> void:
	pass

# 当本弹珠主动碰撞其他弹珠时调用
# other: 被撞的弹珠
# remaining_steps: 被撞弹珠获得的步数
# direction: 移动方向
func on_collision_with(other: Marble3D, remaining_steps: int, direction: int) -> void:
	pass

# 当本弹珠作为“被撞者”时，外部会调用此函数询问步数是否需要调整
# 返回值：最终传递给 continue_move 的步数（默认为原值）
# 白球通过重写此函数实现“被友方碰撞时步数+1”
func on_collision_as_target(collider: Marble3D, incoming_steps: int, direction: int) -> int:
	return incoming_steps

# ---------- 死亡处理 ----------
# 弹珠死亡（出界或被碰撞致死）
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	on_death()                          # 触发子类死亡钩子（如黄球死亡增益）
	hex_grid.remove_marble_by_node(self) # 从棋盘移除
	queue_free()                         # 删除节点

# 死亡时的钩子（子类可重写，如黄球触发增益、蓝球清理随从）
func on_death() -> void:
	print("%s 死亡" % get_class())

# ---------- 辅助函数 ----------
# 获取当前六边形坐标（优先使用缓存，否则从棋盘读取）
func get_current_hex() -> Vector2:
	return hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)

# 根据轴向坐标和方向索引，计算邻居坐标
# hex: 当前坐标 Vector2(q, r)
# dir: 0~5 方向索引（顺序与 MarbleConst.HexDirection 一致）
func _get_neighbor_hex(hex: Vector2, dir: int) -> Vector2:
	var dirs = [
		Vector2(1, 0),   # 0: RIGHT      (1,0)
		Vector2(1, 1),   # 1: RIGHT_UP   (1,1)
		Vector2(0, 1),   # 2: LEFT_UP    (0,1)
		Vector2(-1, 0),  # 3: LEFT       (-1,0)
		Vector2(-1, -1), # 4: LEFT_DOWN  (-1,-1)
		Vector2(0, -1)   # 5: RIGHT_DOWN (0,-1)
	]
	return hex + dirs[dir]
