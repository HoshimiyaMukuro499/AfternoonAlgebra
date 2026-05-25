# RandomAI.gd
# 随机 AI 策略：所有决策点均随机选择合法操作
# 支持各颜色弹珠的专属功能：
# - 白/蓝/绿/黄：方向 + 力度（标准流程）
# - 红球：先选力度，再逐格选方向
# - 黑球：先选敌方目标，再选大致方向（不能主动移动）
extends AIStrategy

var _used_colors_red: Array = []
var _used_colors_blue: Array = []

func _init():
	randomize()

func decide(gm: GameManager) -> Dictionary:
	if gm.setup_phase_active:
		return _decide_setup(gm)
	match gm.current_state:
		GameManager.TurnState.IDLE:
			return _decide_select_marble(gm)
		GameManager.TurnState.MARBLE_SELECTED:
			if gm.selected_marble and gm.selected_marble.color == MarbleConst.MarbleColor.RED:
				return _decide_red_power(gm)
			else:
				return _decide_direction(gm)
		GameManager.TurnState.DIRECTION_SELECTED:
			return _decide_power(gm)
		GameManager.TurnState.RED_DIRECTION_PICKING:
			return _decide_red_direction(gm)
		GameManager.TurnState.BLACK_MARBLE_SELECTED:
			return _decide_black_target(gm)
		GameManager.TurnState.BLACK_TARGET_PICKING:
			return _decide_black_approx_direction(gm)
	return {}

func _decide_setup(gm: GameManager) -> Dictionary:
	match gm.setup_state:
		GameManager.SetupState.COLOR_SELECT:
			return _decide_setup_color(gm)
		GameManager.SetupState.PLACEMENT:
			return _decide_setup_placement(gm)
	return {}

func _decide_setup_color(gm: GameManager) -> Dictionary:
	var camp = gm.setup_current_team
	var used = _used_colors_red if camp == MarbleConst.Camp.RED else _used_colors_blue
	var available_colors = []
	for c in range(MarbleConst.MarbleColor.size()):
		if c not in used:
			available_colors.append(c)
	var color
	if available_colors.size() > 0:
		color = available_colors[randi() % available_colors.size()]
	else:
		color = randi() % MarbleConst.MarbleColor.size()
	used.append(color)
	return {"action": "setup_color", "color": color}

func _decide_setup_placement(gm: GameManager) -> Dictionary:
	var positions = gm.hex_grid.get_available_positions(gm.setup_current_team)
	var available = []
	for pos in positions:
		var q = int(pos.x)
		var r = int(pos.y)
		if gm.hex_grid.get_marble_at(q, r) == null:
			available.append(pos)
	if available.size() == 0:
		push_error("RandomAI: 没有可放置的位置，跳过决策")
		return {}  # 返回空字典，让上层停止 AI 决策循环
	var chosen = available[randi() % available.size()]
	return {"action": "setup_place", "q": int(chosen.x), "r": int(chosen.y)}

func _decide_select_marble(gm: GameManager) -> Dictionary:
	var my_marbles = get_alive_marbles(gm, gm.current_team)
	if my_marbles.size() == 0:
		push_error("RandomAI: 没有可选的己方弹珠")
		return {}
	var chosen = my_marbles[randi() % my_marbles.size()]
	return {"action": "select_marble", "marble": chosen}

# ── 方向选择 ──
# 普通球（白/蓝/绿/黄）选择方向
func _decide_direction(gm: GameManager) -> Dictionary:
	return {"action": "select_direction", "direction": randi() % 6}

func _decide_power(gm: GameManager) -> Dictionary:
	return {"action": "select_power", "power": (randi() % 5) + 1}

# ── 红球专属：选力度 → 逐格选方向 ──

func _decide_red_power(gm: GameManager) -> Dictionary:
	return {"action": "red_power", "power": (randi() % 5) + 1}

func _decide_red_direction(gm: GameManager) -> Dictionary:
	return {"action": "red_direction", "direction": randi() % 6}

# ── 黑球专属：选择敌方目标 ──

func _decide_black_target(gm: GameManager) -> Dictionary:
	# 获取所有敌方存活弹珠
	var enemy_marbles = get_alive_marbles(gm, opponent(gm.current_team))
	if enemy_marbles.size() == 0:
		push_error("RandomAI: 黑球没有敌方目标可选")
		return {}
	
	# 优先选择距离棋盘边缘较近的弹珠（更容易被推出界）
	var best_target = null
	var closest_to_edge = -1
	
	for marble in enemy_marbles:
		if not is_instance_valid(marble) or not marble.is_alive:
			continue
		var q = marble.hex_coord.x if marble.hex_coord != Vector2.ZERO else gm.hex_grid.get_marble_hex(marble).x
		var r = marble.hex_coord.y if marble.hex_coord != Vector2.ZERO else gm.hex_grid.get_marble_hex(marble).y
		
		# 计算到棋盘中心的距离，越远越靠近边缘
		var dist_to_center = max(abs(q), abs(r), abs(q - r))
		var edge_dist = MarbleConst.GRID_RADIUS - dist_to_center
		
		# edge_dist 越小越靠近边缘，我们要找最小的
		if closest_to_edge < 0 or edge_dist < closest_to_edge:
			closest_to_edge = edge_dist
			best_target = marble
	
	if best_target == null:
		best_target = enemy_marbles[randi() % enemy_marbles.size()]
	
	return {"action": "select_enemy", "marble": best_target}

# ── 黑球专属：选择大致方向（倾向于指向棋盘外） ──

func _decide_black_approx_direction(gm: GameManager) -> Dictionary:
	# 选择指向棋盘外的方向，更容易将敌方推出界
	var enemy = gm.black_target_marble
	if enemy and is_instance_valid(enemy) and enemy.is_alive:
		var q = enemy.hex_coord.x if enemy.hex_coord != Vector2.ZERO else gm.hex_grid.get_marble_hex(enemy).x
		var r = enemy.hex_coord.y if enemy.hex_coord != Vector2.ZERO else gm.hex_grid.get_marble_hex(enemy).y
		
		# 根据敌方坐标计算6个方向的"出界评分"
		# 模拟走3步，算出界概率
		var dir_scores = []
		for dir in range(6):
			var score = 0
			var current = Vector2(q, r)
			for step in range(3):
				var neighbor = _get_neighbor_hex(current, dir)
				if gm.hex_grid.is_out_of_bounds(neighbor.x, neighbor.y):
					score += 1
				current = neighbor
			dir_scores.append(score)
		
		# 选最高分方向
		var best_dir = 0
		var best_score = -1
		for dir in range(6):
			if dir_scores[dir] > best_score:
				best_score = dir_scores[dir]
				best_dir = dir
		
		return {"action": "select_approx_direction", "direction": best_dir}
	
	# 没有目标信息，随机选方向
	return {"action": "select_approx_direction", "direction": randi() % 6}

# 辅助方法：计算邻居坐标
func _get_neighbor_hex(hex: Vector2, dir: int) -> Vector2:
	var dirs = [
		Vector2(1, 0),   # 0: RIGHT
		Vector2(0, 1),   # 1: RIGHT_UP
		Vector2(-1, 1),  # 2: LEFT_UP
		Vector2(-1, 0),  # 3: LEFT
		Vector2(0, -1),  # 4: LEFT_DOWN
		Vector2(1, -1)   # 5: RIGHT_DOWN
	]
	return hex + dirs[dir]
