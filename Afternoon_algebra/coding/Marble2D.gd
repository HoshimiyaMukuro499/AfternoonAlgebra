class_name Marble2D
extends Area2D

# 信号：碰撞与死亡
signal collision_occurred(collider: Marble2D, target: Marble2D, remaining_steps: int, direction: int)
signal marble_died(marble: Marble2D)

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

# 移动动画用的 tween 引用（防止多步移动时冲突）
var _slide_tween: Tween = null

# 高亮状态
var is_highlighted: bool = false
var label_index: int = 0
var _label_node: Label = null

# 黄球增益追踪
var boost_count: int = 0
var _boost_label: Label = null


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
		var tree = get_tree()
		if tree:
			var root = tree.current_scene
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
	
	# 延迟一帧播放放置入场效果（确保父节点已添加完毕，且后续视觉调整已生效）
	call_deferred("_create_placement_effect")

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
			
			# 发送碰撞信号（用于 UI 提示）
			collision_occurred.emit(self, other, temp, direction)
			
			# 让被撞弹珠继续移动
			other.continue_move(temp, direction)
			# 当前弹珠停止移动（不再继续本次移动）
			break
		else:
			# 空位：直接移动
			var prev_hex = current  # 保存移动前的位置，用于生成轨迹阴影
			var old_world = hex_grid.hex_to_world(int(prev_hex.x), int(prev_hex.y))
			
			# 先更新游戏逻辑位置（marbles 字典 + meta）
			hex_grid.move_marble(self, current, next)
			current = next
			remaining -= 1
			hex_coord = current   # 更新缓存坐标
			var new_world = hex_grid.hex_to_world(int(current.x), int(current.y))
			
			# 弹珠平滑滑动动画（链式：如果前一步的动画还在播放，覆盖到新位置）
			if _slide_tween and _slide_tween.is_running():
				_slide_tween.kill()
			position = old_world
			# headless/测试模式下无场景树，直接瞬移
			if is_inside_tree():
				_slide_tween = get_tree().create_tween().set_parallel(false)
				_slide_tween.tween_property(self, "position", new_world, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			else:
				position = new_world
			
			# 创建移动轨迹阴影（旧位置幽灵 + 路径连线 + 滑行残影）
			if is_inside_tree():
				_create_move_trail(prev_hex, old_world, new_world)
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
	
	# 通知同阵营存活白球：队友死亡时白球变色
	_notify_white_teammates()
	
	hex_grid.remove_marble_by_node(self)   # 从棋盘移除
	
	# 发送死亡信号（用于 UI 提示）
	marble_died.emit(self)
	
	queue_free()  # 删除节点


# 通知同阵营存活的白球：有队友死亡了
# 规则：每次死亡只触发一个己方白球变色，优先选未变色的
func _notify_white_teammates() -> void:
	if not hex_grid:
		return
	
	# 收集同阵营存活白球
	var alive_whites: Array = []
	for hex_key in hex_grid.marbles:
		var marble = hex_grid.marbles[hex_key]
		if marble is WhiteMarble and marble.camp == self.camp and marble.is_alive:
			alive_whites.append(marble)
	
	if alive_whites.is_empty():
		return
	
	# 选一个白球变色：优先未变色（has_changed == false）
	var chosen: WhiteMarble = null
	for w in alive_whites:
		if not w.has_changed:
			chosen = w
			break
	if not chosen:
		chosen = alive_whites[0]  # 全部已变色，选第一个覆盖
	
	chosen.on_teammate_died(self.color)


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


# ---------- 运动轨迹阴影效果 ----------
# 在弹珠移动一格后，在旧位置→新位置之间创建动态拖尾轨迹
# 包含：旧位置渐隐幽灵 + 路径连线 + 滑行残影
# from_world / to_world 为移动前后的世界坐标（显式传入，避免依赖 position 变化）
func _create_move_trail(prev_hex: Vector2, from_world: Vector2, to_world: Vector2) -> void:
	if not hex_grid or not is_inside_tree():
		return
	
	# 获取弹珠的精灵纹理
	var sprite_node = _get_sprite_node()
	if not sprite_node or not sprite_node.texture:
		return  # 没有纹理则跳过
	
	var tree = get_tree()
	if not tree:
		return
	
	# ── 1. 旧位置幽灵（原地渐隐 + 缩小） ──
	var ghost = Sprite2D.new()
	ghost.texture = sprite_node.texture
	ghost.scale = sprite_node.scale * 0.95
	ghost.modulate = Color(1, 1, 1, 0.55)
	ghost.z_index = -1
	ghost.position = from_world
	hex_grid.add_child(ghost)
	
	var t1 = tree.create_tween()
	t1.set_parallel(true)
	t1.tween_property(ghost, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	t1.tween_property(ghost, "scale", ghost.scale * 0.6, 0.5).set_ease(Tween.EASE_IN)
	t1.tween_callback(ghost.queue_free)
	
	# ── 2. 路径拖尾连线（从旧位置到新位置的渐隐线段） ──
	var line = Line2D.new()
	line.points = PackedVector2Array([from_world, to_world])
	line.width = 2.5
	line.default_color = Color(0.8, 0.8, 0.8, 0.35)
	line.z_index = -1
	hex_grid.add_child(line)
	
	var t2 = tree.create_tween()
	t2.set_parallel(true)
	t2.tween_property(line, "default_color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	t2.tween_property(line, "width", 0.0, 0.35).set_ease(Tween.EASE_IN)
	t2.tween_callback(line.queue_free)
	
	# ── 3. 滑行残影（从旧位置滑向新位置的半透明影子，模拟拖尾） ──
	var afterimage = Sprite2D.new()
	afterimage.texture = sprite_node.texture
	afterimage.scale = sprite_node.scale * 0.85
	afterimage.modulate = Color(1, 1, 1, 0.6)
	afterimage.z_index = -1
	afterimage.position = from_world
	hex_grid.add_child(afterimage)
	
	var t3 = tree.create_tween()
	t3.set_parallel(true)
	# 残影从旧位置滑到新位置（略微滞后于真实弹珠）
	t3.tween_property(afterimage, "position", to_world, 0.18).set_ease(Tween.EASE_OUT)
	t3.tween_property(afterimage, "modulate:a", 0.0, 0.35).set_delay(0.08).set_ease(Tween.EASE_OUT)
	t3.tween_property(afterimage, "scale", afterimage.scale * 0.5, 0.35).set_delay(0.08)
	t3.tween_callback(afterimage.queue_free).set_delay(0.1)


# 弹珠放置时的入场效果（布阵阶段使用）
func _create_placement_effect() -> void:
	if not hex_grid or not is_inside_tree():
		return
	
	var sprite_node = _get_sprite_node()
	if not sprite_node:
		return
	
	# 计算合理的缩放目标：
	# 如果 sprite 缩放还很小（默认 0.01），说明 _adjust_marble_visuals 尚未执行，
	# 主动根据 cell_size 计算合适的缩放
	var target_scale = sprite_node.scale
	if target_scale.length() < 0.1 and sprite_node.texture:
		var tex_size = sprite_node.texture.get_size()
		var target_size = hex_grid.cell_size * 1.2
		var scale_factor = target_size / max(tex_size.x, tex_size.y)
		target_scale = Vector2(scale_factor, scale_factor)
	
	sprite_node.scale = Vector2.ZERO
	modulate = Color(1, 1, 1, 0.0)  # 整体透明
	
	# 创建环形扩散阴影
	var shadow = Sprite2D.new()
	if sprite_node.texture:
		shadow.texture = sprite_node.texture
	shadow.scale = target_scale * 0.5
	shadow.modulate = Color(1, 1, 1, 0.4)
	shadow.z_index = -2
	add_child(shadow)
	
	var tree = get_tree()
	if not tree:
		return
	
	# 弹珠缩放弹入 + 淡入
	var tween = tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_node, "scale", target_scale, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	# 环形阴影扩散消失
	tween.tween_property(shadow, "scale", target_scale * 1.8, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(shadow, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(shadow.queue_free)


# ---------- 黄球增益系统 ----------
# 添加黄球增益（由 GameManager 调用），并显示 "+" 标签
func add_yellow_boost() -> void:
	boost_count += 1
	_update_boost_label()
	print("%s 获得黄球增益，当前增益层数: %d" % [get_class(), boost_count])


# 更新或创建 "+" 增益标签
func _update_boost_label() -> void:
	# 如果标签节点不存在则创建
	if not _boost_label:
		_boost_label = Label.new()
		_boost_label.name = "BoostLabel"
		_boost_label.z_index = 3  # 比编号标签更高
		_boost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击
		add_child(_boost_label)
	
	# 显示 boost_count 个 "+" 号
	var text = ""
	for i in range(boost_count):
		text += "+"
	_boost_label.text = text
	_boost_label.clip_text = false
	_boost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 加载自定义字体（与 update_label 相同方式）
	var font_path = "res://HYPixel11pxU-2.ttf"
	if ResourceLoader.exists(font_path):
		var font_data = load(font_path)
		var font = FontFile.new()
		font.font_data = font_data
		_boost_label.add_theme_font_override("font", font)
	
	# 始终设置字体大小（确保 "+" 标签文字足够大、可见）
	_boost_label.add_theme_font_size_override("font_size", 24)
	
	# 金色 "+" 标签
	_boost_label.add_theme_color_override("font_color", Color(1, 0.84, 0))  # Gold
	
	# 固定大小和位置，确保在所有弹珠上都能正常显示
	_boost_label.size = Vector2(48, 32)
	var s = _get_sprite_node()
	if s:
		# 根据 Sprite 的缩放调整偏移量，使标签始终位于弹珠右上角外侧
		_boost_label.position = Vector2(24 * s.scale.x, -48 * s.scale.y)
	else:
		_boost_label.position = Vector2(24, -48)
