class_name GameManager
extends Node2D

signal state_changed(new_state)

var hex_grid: HexGrid2D
var all_marbles: Array[Marble2D] = []
var ui: CanvasLayer

enum TurnState {
	IDLE,
	MARBLE_SELECTED,
	DIRECTION_SELECTED,
	RED_DIRECTION_PICKING,  # 红球逐格选方向状态
	EXECUTING,
	VICTORY
}
var current_state = TurnState.IDLE
var selected_marble = null
var selected_direction: int = -1
var selected_power: int = 0
var current_team = MarbleConst.Camp.RED
var turn_number: int = 0

# 红球逐格选方向专用变量
var red_step_directions: Array[int] = []
var red_total_steps: int = 0
var red_current_step_index: int = 0

func _ready():
	hex_grid = $HexGrid2D
	
	# 将棋盘居中
	var screen_size = get_viewport().get_visible_rect().size
	hex_grid.position = Vector2(screen_size.x / 2, screen_size.y / 2)
	
	# 清理场景中的旧测试弹珠
	if has_node("Marble_Rigid"):
		$Marble_Rigid.queue_free()
	
	# 使用 BoardInitializer 初始化标准棋盘
	if hex_grid:
		all_marbles = BoardInitializer.initialize_board(hex_grid)
		_adjust_marble_visuals()
		# 为每个弹珠分配编号（R1~R6 / B1~B6）
		var red_count = 0
		var blue_count = 0
		for marble in all_marbles:
			if marble.camp == MarbleConst.Camp.RED:
				red_count += 1
				marble.label_index = red_count
			else:
				blue_count += 1
				marble.label_index = blue_count
			marble.update_label()
		# 监听弹珠销毁事件，自动从数组中移除
		for marble in all_marbles:
			marble.tree_exited.connect(_on_marble_freed.bind(marble))
	
	# 创建背景
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color.WHITE  # 白色背景
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)
	# 将背景移到最底层
	move_child(background, 0)
	
	# 初始化 UI
	_init_ui()
	
	randomize()
	current_team = MarbleConst.Camp.RED if randi() % 2 == 0 else MarbleConst.Camp.BLUE
	start_turn()

func _adjust_marble_visuals():
	if not hex_grid:
		return
	var target_size = hex_grid.cell_size * 1.2
	for marble in all_marbles:
		# 调整 Sprite 大小使其在棋盘上可见
		var sprite = marble._get_sprite_node()
		if sprite and sprite.texture:
			var tex_size = sprite.texture.get_size()
			var scale_factor = target_size / max(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)
		# 重置碰撞体到弹珠中心
		for child in marble.get_children():
			if child is CollisionShape2D:
				child.position = Vector2.ZERO

func _init_ui():
	# 查找或创建 UI 节点
	var ui_node = get_node_or_null("UI")
	var need_add_child = false
	if not ui_node:
		ui_node = CanvasLayer.new()
		ui_node.name = "UI"
		need_add_child = true
	
	# 确保 UI 挂载了 UI.gd 脚本
	if ui_node.get_script() == null:
		var ui_script = load("res://UI/UI.gd")
		if ui_script:
			ui_node.set_script(ui_script)
	
	if need_add_child:
		add_child(ui_node)
	
	# 保存引用以便后续使用
	ui = ui_node

func start_turn():
	current_state = TurnState.IDLE
	selected_marble = null
	selected_direction = -1
	selected_power = 0
	red_step_directions = []
	red_total_steps = 0
	red_current_step_index = 0
	turn_number += 1
	var turn_text = "第 %d 回合，%s 方行动" % [turn_number, "红" if current_team == MarbleConst.Camp.RED else "蓝"]
	print(turn_text)
	if ui:
		ui.update_turn_display(self)
	state_changed.emit(current_state)

func select_marble(marble):
	if current_state != TurnState.IDLE or current_state == TurnState.VICTORY: return
	if marble.camp != current_team or not marble.is_alive: return
	selected_marble = marble
	selected_marble.highlight()
	
	# 红球特殊处理：先选力度（步数），再逐格选方向
	if marble.color == MarbleConst.MarbleColor.RED:
		current_state = TurnState.MARBLE_SELECTED
		print("红球：请选择力度（按 1~5 键确定步数）")
	else:
		current_state = TurnState.MARBLE_SELECTED
		print("选中弹珠，请选择方向")
	state_changed.emit(current_state)

func select_direction(direction: int):
	if current_state != TurnState.MARBLE_SELECTED or current_state == TurnState.VICTORY: return
	selected_direction = direction
	current_state = TurnState.DIRECTION_SELECTED
	print("已选方向，请选择力度")
	state_changed.emit(current_state)

# 红球选择力度（步数），然后进入逐格选方向模式
func red_select_power(power: int):
	if current_state != TurnState.MARBLE_SELECTED or current_state == TurnState.VICTORY: return
	if selected_marble == null or selected_marble.color != MarbleConst.MarbleColor.RED:
		return
	
	red_total_steps = power
	red_step_directions = []
	red_current_step_index = 0
	current_state = TurnState.RED_DIRECTION_PICKING
	print("红球：请选择第 1 步的方向（点击相邻格子）")
	state_changed.emit(current_state)

# 红球追加一个方向
func red_append_direction(direction: int):
	if current_state != TurnState.RED_DIRECTION_PICKING or current_state == TurnState.VICTORY: return
	if selected_marble == null: return
	
	red_step_directions.append(direction)
	red_current_step_index += 1
	
	if red_current_step_index >= red_total_steps:
		# 方向选满，执行移动
		print("红球方向已选满，开始移动")
		_red_execute_move()
	else:
		print("红球：请选择第 %d 步的方向（点击相邻格子）" % (red_current_step_index + 1))
		state_changed.emit(current_state)

# 红球执行移动（传入方向列表）
func _red_execute_move():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	if selected_marble and selected_marble.is_alive:
		selected_marble.on_before_move(red_step_directions[0] if red_step_directions.size() > 0 else 0, red_total_steps)
		RedMarbleHelper.move_with_step_directions(selected_marble, red_step_directions, red_total_steps)
		selected_marble.on_after_move(red_step_directions[0] if red_step_directions.size() > 0 else 0, red_total_steps, selected_marble.is_alive)
		selected_marble.unhighlight()
	
	# 在不处于场景树中的测试环境里，同步执行后续逻辑
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	
	_finish_turn()

func select_power(power: int):
	if current_state != TurnState.DIRECTION_SELECTED or current_state == TurnState.VICTORY: return
	selected_power = power
	execute_move()

func execute_move():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	if selected_marble and selected_marble.is_alive:
		selected_marble.move(selected_direction, selected_power)
	
	# 在不处于场景树中的测试环境里，同步执行后续逻辑
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	
	_finish_turn()

# 提取回合结束公共逻辑，方便测试和代码复用
func _finish_turn():
	var winner = _check_victory()
	if winner != -1:
		_on_victory(winner)
		return
	# 切换回合
	current_team = MarbleConst.Camp.BLUE if current_team == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	start_turn()

func cancel_selection():
	if current_state == TurnState.IDLE or current_state == TurnState.EXECUTING or current_state == TurnState.VICTORY: 
		return
	
	# 红球逐格选方向模式取消
	if current_state == TurnState.RED_DIRECTION_PICKING:
		if selected_marble:
			selected_marble.unhighlight()
		selected_marble = null
		selected_direction = -1   # 添加：重置方向
		selected_power = 0         # 添加：重置力度
		red_step_directions = []
		red_total_steps = 0
		red_current_step_index = 0
		current_state = TurnState.IDLE
		print("已取消选择")
		if ui:
			ui.update_message("已取消选择，请点击己方弹珠")
		state_changed.emit(current_state)
		return  # 这里的 return 是正确的，避免执行后面的通用代码
	
	# 普通球取消选择
	if selected_marble:
		selected_marble.unhighlight()
	selected_marble = null
	selected_direction = -1
	selected_power = 0
	current_state = TurnState.IDLE
	print("已取消选择")
	if ui:
		ui.update_message("已取消选择，请点击己方弹珠")
	state_changed.emit(current_state)

func _check_victory() -> int:
	var red_alive = false
	var blue_alive = false
	for marble in all_marbles:
		if not is_instance_valid(marble):
			continue
		if marble.is_alive:
			if marble.camp == MarbleConst.Camp.RED:
				red_alive = true
			else:
				blue_alive = true
	if not red_alive:
		return MarbleConst.Camp.BLUE
	if not blue_alive:
		return MarbleConst.Camp.RED
	return -1

func _on_victory(winner: int):
	current_state = TurnState.VICTORY
	state_changed.emit(current_state)
	var winner_name = "红方" if winner == MarbleConst.Camp.RED else "蓝方"
	print("游戏结束，%s 获胜！" % winner_name)
	if ui:
		ui.show_victory(winner_name)

func _on_marble_freed(marble: Marble2D):
	var idx = all_marbles.find(marble)
	if idx != -1:
		all_marbles.remove_at(idx)

func remove_marble(marble: Marble2D):
	# 供外部（如 DeathResolver）调用，手动移除弹珠
	var idx = all_marbles.find(marble)
	if idx != -1:
		all_marbles.remove_at(idx)
