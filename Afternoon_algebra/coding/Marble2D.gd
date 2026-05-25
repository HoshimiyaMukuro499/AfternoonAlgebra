class_name Marble2D
extends Area2D

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
var hex_grid: HexGrid2D = null
# 当前所在的六边形坐标（缓存，提高性能）
var hex_coord: Vector2 = Vector2.ZERO

# 引用 Sprite 节点（用于改变颜色）
@onready var sprite: Sprite2D = $Sprite if has_node("Sprite") else null

# 高亮状态
var is_highlighted: bool = false
var label_index: int = 0
var _label_node: Label = null
# 黄球增益次数
var boost_count: int = 0


func _ready() -> void:
	# 自动查找 HexGrid2D 棋盘节点（向上遍历父节点）
	var parent = get_parent()
	while parent:
		if parent is HexGrid2D:
			hex_grid = parent
			break
		parent = parent.get_parent()
	
	# 如果上面没找到，再试试用节点名称查找（方便你在编辑器里把棋盘命名为 HexGrid）
	if not hex_grid:
		var root = get_tree().current_scene
		if root:
			hex_grid = root.find_child("HexGrid2D", true, false)
	
	if hex_grid:
		# 关键修复：从棋盘获取实际位置，而不是依赖 meta
		var pos = hex_grid.get_marble_hex(self)
		if pos != Vector2.ZERO:
			hex_coord = pos
		else:
			hex_coord = Vector2.ZERO
	else:
		push_error("Marble2D: 找不到 HexGrid2D 棋盘节点")

# 添加一个外部方法设置位置同时同步缓存
func update_hex_coord(new_coord: Vector2) -> void:
	hex_coord = new_coord

# 高亮选中弹珠
func highlight() -> void:
	is_highlighted = true
	var s = _get_sprite_node()
	if s:
		s.modulate = Color(1.5, 1.5, 1.5, 1)


# 取消高亮
func unhighlight() -> void:
	is_highlighted = false
	var s = _get_sprite_node()
	if s:
		s.modulate = Color.WHITE


# 获取实际存在的 Sprite 节点（兼容白球的 SpriteWhite）
func _get_sprite_node():
	if sprite:
		return sprite
	if has_node("SpriteWhite"):
		return $SpriteWhite
	return null


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
var _recursion_depth: int = 0

func _move_step_by_step(direction: int, steps: int) -> bool:
	# 防止无限递归
	if _recursion_depth > 10:
		push_error("递归深度超过限制，强制停止移动")
		return false
	_recursion_depth += 1
	
	var remaining = steps
	var current = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
	
	while remaining > 0:
		# 计算下一步的邻居坐标
		var next = get_neighbor_hex(current, direction)
		
		# 1. 边界检查：超出棋盘半径则死亡
		if hex_grid.is_out_of_bounds(next.x, next.y):
			die()
			_recursion_depth -= 1
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
	
	_recursion_depth -= 1
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
func on_collision_with(other: Marble2D, remaining_steps: int, direction: int) -> void:
	pass

# 当前弹珠作为"被撞者"时，外部会调用此函数询问步数是否需要调整
# 返回值将作为实际传给 continue_move 的步数
# 默认实现是不修改（原样返回）
func on_collision_as_target(collider: Marble2D, incoming_steps: int, direction: int) -> int:
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
	print("%s 死亡" % get_class())


# ---------- 辅助方法 ----------
# 获取当前六边形坐标（优先使用缓存）
func get_current_hex() -> Vector2:
	return hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)

# 计算轴向坐标下指定方向的邻居坐标（公开方法，供辅助类调用）
# hex: 当前坐标 (q, r)
# dir: 0~5 方向索引
func get_neighbor_hex(hex: Vector2, dir: int) -> Vector2:
	# 轴向六边形坐标下6个方向的偏移量
	# 使用标准轴向坐标 (q, r)，平顶布局，r向下递增
	# RIGHT=(1,0), SE=(0,1), SW=(-1,1), LEFT=(-1,0), NW=(0,-1), NE=(1,-1)
	var dirs = [
		Vector2(1, 0),   # 0: RIGHT
		Vector2(0, 1),   # 1: RIGHT_UP (SE方向)
		Vector2(-1, 1),  # 2: LEFT_UP (SW方向)
		Vector2(-1, 0),  # 3: LEFT
		Vector2(0, -1),  # 4: LEFT_DOWN (NW方向)
		Vector2(1, -1)   # 5: RIGHT_DOWN (NE方向)
	]
	return hex + dirs[dir]


# 更新编号标签（由 GameManager 在分配编号后调用）
func update_label() -> void:
	if label_index <= 0:
		return
	var prefix = "R" if camp == MarbleConst.Camp.RED else "B"
	var text = "%s%d" % [prefix, label_index]
	
	# 如果标签节点不存在则创建
	if not _label_node:
		_label_node = Label.new()
		_label_node.name = "MarbleLabel"
		_label_node.z_index = 2
		add_child(_label_node)
	
	_label_node.text = text
	_label_node.clip_text = false
	_label_node.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# 加载自定义字体
	var font_path = "res://HYPixel11pxU-2.ttf"
	if ResourceLoader.exists(font_path):
		var font_data = load(font_path)
		var font = FontFile.new()
		font.font_data = font_data
		_label_node.add_theme_font_override("font", font)
		_label_node.add_theme_font_size_override("font_size", 24)
	
	# 设置字体颜色
	var font_color = Color(1, 0.1, 0.1) if camp == MarbleConst.Camp.RED else Color(0.1, 0.3, 1)
	_label_node.add_theme_color_override("font_color", font_color)
	
	# 居中显示
	var s = _get_sprite_node()
	if s and s.texture:
		var tex_size = s.texture.get_size()
		_label_node.size = tex_size
		_label_node.position = -tex_size / 2
	else:
		_label_node.size = Vector2(64, 64)
		_label_node.position = Vector2(-32, -32)
	
	_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# 更新增益标签显示
func update_boost_label() -> void:
	if not _label_node:
		return
	var suffix = ""
	for i in range(boost_count):
		suffix += "+"
	if suffix != "":
		_label_node.text += suffix
