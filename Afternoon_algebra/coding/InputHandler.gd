extends Node2D

# 六边形轴向坐标的六个邻居偏移量（点顶朝向）
const NEIGHBOR_OFFSETS = [
	Vector2(1, 0),   # 0: 东
	Vector2(0, 1),   # 1: 东南
	Vector2(-1, 1),  # 2: 西南
	Vector2(-1, 0),  # 3: 西
	Vector2(0, -1),  # 4: 西北
	Vector2(1, -1)   # 5: 东北
]

var game_manager: GameManager

func _ready():
	game_manager = get_node_or_null("/root/Node2D")
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")

func _unhandled_input(event):
	# 选珠阶段由 GameManager 处理点击
	if game_manager.setup_phase_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 将全局鼠标坐标转换为 HexGrid2D 的局部坐标
		var local_pos = game_manager.hex_grid.to_local(get_global_mouse_position())
		_handle_click(local_pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		game_manager.cancel_selection()

func _handle_click(pos: Vector2):
	# 选珠阶段由 GameManager 处理
	if game_manager.setup_phase_active:
		return
	match game_manager.current_state:
		GameManager.TurnState.IDLE:
			_try_select_marble(pos)
		GameManager.TurnState.MARBLE_SELECTED:
			# 红球在MARBLE_SELECTED状态下点击方向（力度已选完才有效）
			# 如果力度还没选（red_total_steps == 0），忽略点击，等待按数字键
			if game_manager.selected_marble and game_manager.selected_marble.color == MarbleConst.MarbleColor.RED:
				# 红球在MARBLE_SELECTED状态下不处理点击，等待键盘选力度
				pass
			else:
				_try_select_direction(pos)
		GameManager.TurnState.DIRECTION_SELECTED:
			_try_select_power(pos)
		GameManager.TurnState.RED_DIRECTION_PICKING:
			_try_red_select_direction(pos)
		GameManager.TurnState.BLACK_MARBLE_SELECTED:
			_try_black_select_target(pos)
		GameManager.TurnState.BLACK_TARGET_PICKING:
			_try_black_select_approx_direction(pos)
		GameManager.TurnState.YELLOW_GAIN_PICKING:
			_try_yellow_gain_select(pos)

func _try_select_marble(pos: Vector2):
	var hex = game_manager.hex_grid.world_to_hex(pos)
	var marble = game_manager.hex_grid.get_marble_at(int(hex.x), int(hex.y))
	if marble and marble.is_alive and marble.camp == game_manager.current_team:
		game_manager.select_marble(marble)
		return

func _try_yellow_gain_select(pos: Vector2):
	var hex = game_manager.hex_grid.world_to_hex(pos)
	var marble = game_manager.hex_grid.get_marble_at(int(hex.x), int(hex.y))
	if marble and marble.is_alive:
		# 只允许选择同阵营的非白非黄弹珠
		game_manager.yellow_select_gain_target(marble)
		return

func _try_red_select_direction(pos: Vector2):
	if not game_manager.selected_marble:
		return
	var current_hex = game_manager.selected_marble.get_current_hex()
	for dir in range(6):
		var neighbor = current_hex + NEIGHBOR_OFFSETS[dir]
		var neighbor_pos = game_manager.hex_grid.hex_to_world(neighbor.x, neighbor.y)
		if pos.distance_to(neighbor_pos) < game_manager.hex_grid.cell_size * 0.8:
			game_manager.red_append_direction(dir)
			return
	# 点击位置不在任何相邻格子，不取消选择，等待玩家继续点击
	return

# 黑球：点击敌方弹珠选择为目标
func _try_black_select_target(pos: Vector2):
	var hex = game_manager.hex_grid.world_to_hex(pos)
	var marble = game_manager.hex_grid.get_marble_at(int(hex.x), int(hex.y))
	if marble and marble.is_alive and marble.camp != game_manager.current_team:
		game_manager.black_select_target(marble)
		return

# 黑球：点击敌方目标弹珠周围的相邻格子选择大致方向
func _try_black_select_approx_direction(pos: Vector2):
	if not game_manager.selected_marble:
		return
	if not game_manager.black_target_marble:
		return
	var target_hex = game_manager.black_target_marble.get_current_hex()
	for dir in range(6):
		var neighbor = target_hex + NEIGHBOR_OFFSETS[dir]
		var neighbor_pos = game_manager.hex_grid.hex_to_world(neighbor.x, neighbor.y)
		if pos.distance_to(neighbor_pos) < game_manager.hex_grid.cell_size * 0.8:
			game_manager.black_select_approx_direction(dir)
			return
func _try_select_direction(pos: Vector2):
	if not game_manager.selected_marble:
		return
	var current_hex = game_manager.selected_marble.get_current_hex()
	for dir in range(6):
		# 直接使用已知的偏移量计算邻居坐标，避免依赖 get_neighbor_hex 可能存在的错误
		var neighbor = current_hex + NEIGHBOR_OFFSETS[dir]
		var neighbor_pos = game_manager.hex_grid.hex_to_world(neighbor.x, neighbor.y)
		if pos.distance_to(neighbor_pos) < game_manager.hex_grid.cell_size * 0.8:
			game_manager.select_direction(dir)
			return
	game_manager.cancel_selection()

func _try_select_power(pos: Vector2):
	pass

func _input(event):
	# 非红球：在DIRECTION_SELECTED状态下按1~5选力度
	if game_manager.current_state == GameManager.TurnState.DIRECTION_SELECTED:
		if event is InputEventKey and event.pressed:
			var key_map = {
				KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5
			}
			if event.keycode in key_map:
				game_manager.select_power(key_map[event.keycode])
	
	# 红球：在MARBLE_SELECTED状态下按1~6选力度（步数，6仅限黄球增益后）
	if game_manager.current_state == GameManager.TurnState.MARBLE_SELECTED:
		if game_manager.selected_marble and game_manager.selected_marble.color == MarbleConst.MarbleColor.RED:
			if event is InputEventKey and event.pressed:
				var key_map = {
					KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5, KEY_6: 6
				}
				if event.keycode in key_map:
					game_manager.red_select_power(key_map[event.keycode])
