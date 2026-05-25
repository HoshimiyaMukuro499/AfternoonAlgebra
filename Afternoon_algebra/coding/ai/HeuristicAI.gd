# HeuristicAI.gd
# 启发式 AI 策略：通过评估函数对每个可能的操作评分，选择最优操作
# 支持各颜色弹珠的特性决策：
# - 白/蓝/绿/黄：方向 + 力度（标准流程）
# - 红球：先选力度，再逐格选方向
# - 黑球：先选敌方目标，再选大致方向（不能主动移动）
extends AIStrategy

# 评估函数权重
const WEIGHT_MARBLE_COUNT: float = 100.0
const WEIGHT_POSITION: float = 10.0
const WEIGHT_COLOR_VALUE: float = 20.0
const WEIGHT_THREAT: float = 30.0
const WEIGHT_OFFENSE: float = 25.0
const WEIGHT_CENTER: float = 5.0

# 各颜色价值（白球最高因变色潜力，黑球最低因不能移动）
const COLOR_VALUES = {
	MarbleConst.MarbleColor.WHITE: 5,
	MarbleConst.MarbleColor.BLUE: 4,
	MarbleConst.MarbleColor.GREEN: 3,
	MarbleConst.MarbleColor.RED: 3,
	MarbleConst.MarbleColor.YELLOW: 2,
	MarbleConst.MarbleColor.BLACK: 1,
}

# 选珠阶段颜色优先级
const SETUP_COLOR_PRIORITY = [
	MarbleConst.MarbleColor.WHITE,
	MarbleConst.MarbleColor.BLUE,
	MarbleConst.MarbleColor.GREEN,
	MarbleConst.MarbleColor.RED,
	MarbleConst.MarbleColor.YELLOW,
	MarbleConst.MarbleColor.BLACK,
]

var _used_colors_red: Array = []
var _used_colors_blue: Array = []

func _init():
	randomize()

# ── 主决策入口 ──
func decide(gm: GameManager) -> Dictionary:
	if gm.setup_phase_active:
		return _decide_setup(gm)
	
	match gm.current_state:
		GameManager.TurnState.IDLE:
			return _decide_select_marble_heuristic(gm)
		GameManager.TurnState.MARBLE_SELECTED:
			if gm.selected_marble and gm.selected_marble.color == MarbleConst.MarbleColor.RED:
				return _decide_red_power_heuristic(gm)
			else:
				return _decide_direction_heuristic(gm)
		GameManager.TurnState.DIRECTION_SELECTED:
			return _decide_power_heuristic(gm)
		GameManager.TurnState.RED_DIRECTION_PICKING:
			return _decide_red_direction_heuristic(gm)
		GameManager.TurnState.BLACK_MARBLE_SELECTED:
			return _decide_black_target_heuristic(gm)
		GameManager.TurnState.BLACK_TARGET_PICKING:
			return _decide_black_approx_direction_heuristic(gm)
	return {}

# ── 棋盘评估 ──
func evaluate(gm: GameManager, for_camp: int) -> float:
	var score = 0.0
	var enemy_camp = opponent(for_camp)
	
	# 1. 弹珠数量优势（权重最高）
	var my_count = get_alive_marbles(gm, for_camp).size()
	var enemy_count = get_alive_marbles(gm, enemy_camp).size()
	score += (my_count - enemy_count) * WEIGHT_MARBLE_COUNT
	
	# 2. 位置控制 + 颜色价值
	for marble in gm.all_marbles:
		if not is_instance_valid(marble) or not marble.is_alive:
			continue
		var is_mine = (marble.camp == for_camp)
		var pos_score = _evaluate_position(gm, marble)
		var color_val = COLOR_VALUES.get(marble.color, 1)
		
		if is_mine:
			score += pos_score * WEIGHT_POSITION
			score += color_val * WEIGHT_COLOR_VALUE
		else:
			score -= pos_score * WEIGHT_POSITION
			score -= color_val * WEIGHT_COLOR_VALUE
	
	# 3. 威胁评估（敌方可能吃掉己方弹珠）
	score -= _evaluate_threats(gm, for_camp) * WEIGHT_THREAT
	
	# 4. 己方进攻能力（己方可能吃掉敌方弹珠）
	score += _evaluate_offense(gm, for_camp) * WEIGHT_OFFENSE
	
	return score

# 评估单颗弹珠的位置得分（中心区域更高）
func _evaluate_position(gm: GameManager, marble: Marble2D) -> float:
	var q = marble.hex_coord.x
	var r = marble.hex_coord.y
	# 到棋盘中心的距离（轴向距离）
	var dist = max(abs(q), abs(r), abs(-q - r))
	# 中心区域（dist小）得分高
	var center_score = float(MarbleConst.GRID_RADIUS - dist) / MarbleConst.GRID_RADIUS
	return max(0.0, center_score)

# 威胁评估：敌方可能吃掉己方弹珠的情况
func _evaluate_threats(gm: GameManager, for_camp: int) -> float:
	var enemy_camp = opponent(for_camp)
	var total_threat = 0.0
	
	for my_marble in get_alive_marbles(gm, for_camp):
		if not is_instance_valid(my_marble):
			continue
		var my_pos = my_marble.hex_coord
		
		# 检查是否有敌方弹珠在附近（距离 ≤ 2）
		for enemy in get_alive_marbles(gm, enemy_camp):
			if not is_instance_valid(enemy):
				continue
			var enemy_pos = enemy.hex_coord
			var dist = _hex_distance(my_pos, enemy_pos)
			
			if dist <= 2:
				# 检查敌方攻击方向是否有障碍
				var dir_to_me = _direction_towards(enemy_pos, my_pos)
				var can_attack = _can_reach_in_straight_line(gm, enemy_pos, my_pos, dir_to_me)
				
				if can_attack:
					# 距离越近威胁越大
					total_threat += 1.0 / max(1.0, float(dist))
	
	return total_threat

# 进攻评估：己方可能吃掉敌方弹珠
func _evaluate_offense(gm: GameManager, for_camp: int) -> float:
	var enemy_camp = opponent(for_camp)
	var total_offense = 0.0
	
	for my_marble in get_alive_marbles(gm, for_camp):
		if not is_instance_valid(my_marble):
			continue
		var my_pos = my_marble.hex_coord
		
		for enemy in get_alive_marbles(gm, enemy_camp):
			if not is_instance_valid(enemy):
				continue
			var enemy_pos = enemy.hex_coord
			var dist = _hex_distance(my_pos, enemy_pos)
			
			if dist <= 3:
				# 检查己方弹珠到敌方弹珠的直线上是否有障碍
				var dir_to_enemy = _direction_towards(my_pos, enemy_pos)
				var can_reach = _can_reach_in_straight_line(gm, my_pos, enemy_pos, dir_to_enemy)
				
				if can_reach:
					# 距离越近得分越高
					total_offense += 1.0 / max(1.0, float(dist))
	
	return total_offense

# ── 辅助工具方法 ──

# 计算两个六边形坐标的轴向距离
func _hex_distance(a: Vector2, b: Vector2) -> int:
	var dq = abs(a.x - b.x)
	var dr = abs(a.y - b.y)
	var ds = abs((-a.x - a.y) - (-b.x - b.y))
	return max(dq, dr, ds)

# 计算从 from 指向 to 的最佳六边形方向（0-5）
func _direction_towards(from: Vector2, to: Vector2) -> int:
	var diff = to - from
	var dirs = [
		Vector2(1, 0),   # 0: RIGHT
		Vector2(0, 1),   # 1: RIGHT_UP
		Vector2(-1, 1),  # 2: LEFT_UP
		Vector2(-1, 0),  # 3: LEFT
		Vector2(0, -1),  # 4: LEFT_DOWN
		Vector2(1, -1)   # 5: RIGHT_DOWN
	]
	
	# 使用六边形距离公式，找到使目标"在方向上的投影"最大的方向
	# 对于轴向坐标，轴向距离公式 d = max(|dx|, |dy|, |dx+dy|)
	var best_dir = 0
	var best_score = -999.0
	for i in range(6):
		var d = dirs[i]
		var dot = d.x * diff.x + d.y * diff.y
		# 辅助指标：方向向量各分量与 diff 各分量的"匹配度"
		var match_q = sign(d.x) == sign(diff.x) or d.x == 0 or diff.x == 0
		var match_r = sign(d.y) == sign(diff.y) or d.y == 0 or diff.y == 0
		# 综合评分：点积为主，匹配度为辅
		var score = dot * 10.0
		if match_q:
			score += 2.0
		if match_r:
			score += 2.0
		# 对纯轴向（只有一个分量非零）加分
		if (d.x == 0 or d.y == 0) and dot > 0:
			score += 1.0
		if score > best_score:
			best_score = score
			best_dir = i
	return best_dir

# 检查在直线方向上是否可以从 from 到达 to（中间无障碍）
func _can_reach_in_straight_line(gm: GameManager, from: Vector2, to: Vector2, direction: int) -> bool:
	var current = from
	var steps = 0
	var max_steps = 10  # 防止无限循环
	
	var dirs = [
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(-1, 1),
		Vector2(-1, 0),
		Vector2(0, -1),
		Vector2(1, -1)
	]
	
	while current != to and steps < max_steps:
		var next = current + dirs[direction]
		# 如果到了目标位置，无论是否有弹珠（碰撞处理）都算可到达
		if next == to:
			return true
		# 检查是否有障碍物
		if gm.hex_grid.get_marble_at(int(next.x), int(next.y)) != null:
			return false
		current = next
		steps += 1
	return current == to

# 模拟在六边形网格上沿直线移动
func _simulate_line_movement(start: Vector2, direction: int, steps: int) -> Vector2:
	var dirs = [
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(-1, 1),
		Vector2(-1, 0),
		Vector2(0, -1),
		Vector2(1, -1)
	]
	return start + dirs[direction] * steps

# 获取颜色名称（用于调试）
func _color_name(color: int) -> String:
	match color:
		MarbleConst.MarbleColor.WHITE: return "白"
		MarbleConst.MarbleColor.BLUE: return "蓝"
		MarbleConst.MarbleColor.GREEN: return "绿"
		MarbleConst.MarbleColor.RED: return "红"
		MarbleConst.MarbleColor.BLACK: return "黑"
		MarbleConst.MarbleColor.YELLOW: return "黄"
	return "未知"

# 计算邻接坐标
func _get_neighbor_hex(hex: Vector2, dir: int) -> Vector2:
	var dirs = [
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(-1, 1),
		Vector2(-1, 0),
		Vector2(0, -1),
		Vector2(1, -1)
	]
	return hex + dirs[dir]

# ── 选珠阶段 ──
func _decide_setup(gm: GameManager) -> Dictionary:
	match gm.setup_state:
		GameManager.SetupState.COLOR_SELECT:
			return _decide_setup_color_heuristic(gm)
		GameManager.SetupState.PLACEMENT:
			return _decide_setup_placement_heuristic(gm)
	return {}

func _decide_setup_color_heuristic(gm: GameManager) -> Dictionary:
	var camp = gm.setup_current_team
	var used = _used_colors_red if camp == MarbleConst.Camp.RED else _used_colors_blue
	
	# 按优先级选择未选过的颜色
	for color in SETUP_COLOR_PRIORITY:
		if color not in used:
			used.append(color)
			return {"action": "setup_color", "color": color}
	
	# 如果所有颜色都已选（不应该发生），随机选
	var fallback = randi() % MarbleConst.MarbleColor.size()
	used.append(fallback)
	return {"action": "setup_color", "color": fallback}

func _decide_setup_placement_heuristic(gm: GameManager) -> Dictionary:
	var positions = gm.hex_grid.get_available_positions(gm.setup_current_team)
	var available = []
	
	for pos in positions:
		var q = int(pos.x)
		var r = int(pos.y)
		if gm.hex_grid.get_marble_at(q, r) == null:
			available.append(pos)
	
	if available.size() == 0:
		push_error("HeuristicAI: 没有可放置的位置")
		return {}
	
	# 评分策略：
	# 1. 中心区域优先（但不过于集中）
	# 2. 与已有弹珠保持适当距离（分散布局防碰撞）
	var existing_positions = []
	for marble in gm.all_marbles:
		if is_instance_valid(marble) and marble.camp == gm.setup_current_team:
			existing_positions.append(marble.hex_coord)
	
	var best_pos = available[0]
	var best_score = -9999.0
	
	for pos in available:
		var q = int(pos.x)
		var r = int(pos.y)
		var dist_to_center = max(abs(q), abs(r), abs(-q - r))
		
		# 1. 中心偏好：靠近中心得分高
		var center_score = float(MarbleConst.GRID_RADIUS - dist_to_center) / MarbleConst.GRID_RADIUS
		
		# 2. 分散布局：与已有弹珠保持距离
		var min_dist_to_existing = 999.0
		for ep in existing_positions:
			var d = _hex_distance(Vector2(q, r), ep)
			if d < min_dist_to_existing:
				min_dist_to_existing = d
		
		var spread_score = 0.0
		if existing_positions.size() > 0:
			spread_score = min_dist_to_existing / 3.0  # 期望距离3左右
			spread_score = clamp(spread_score, 0.0, 1.0)
		else:
			spread_score = 1.0  # 第一个弹珠任意位置
		
		# 3. 靠近自己半区边界（便于向敌方推进）
		var zone_edge_bonus = 0.0
		if gm.setup_current_team == MarbleConst.Camp.RED:
			# 红方在左侧，右侧边界更好（靠近战场）
			if q >= -3:
				zone_edge_bonus = 0.3
		else:
			# 蓝方在右侧，左侧边界更好
			if q <= 3:
				zone_edge_bonus = 0.3
		
		var score = center_score * 0.4 + spread_score * 0.4 + zone_edge_bonus * 0.2
		
		if score > best_score:
			best_score = score
			best_pos = pos
	
	return {"action": "setup_place", "q": int(best_pos.x), "r": int(best_pos.y)}

# ── 选弹珠阶段 ──
func _decide_select_marble_heuristic(gm: GameManager) -> Dictionary:
	var my_marbles = get_alive_marbles(gm, gm.current_team)
	if my_marbles.size() == 0:
		push_error("HeuristicAI: 没有可选的己方弹珠")
		return {}
	
	# 除非所有弹珠都是黑色的（不会发生），否则不选黑球
	var non_black = []
	for m in my_marbles:
		if is_instance_valid(m) and m.color != MarbleConst.MarbleColor.BLACK:
			non_black.append(m)
	
	var candidates = non_black if non_black.size() > 0 else my_marbles
	
	# 评分选择：选能造成最大伤害或最有战略价值的弹珠
	var best_marble = candidates[0]
	var best_score = -9999.0
	
	var enemy_camp = opponent(gm.current_team)
	
	for marble in candidates:
		if not is_instance_valid(marble):
			continue
		var pos = marble.hex_coord
		var score = 0.0
		
		# 1. 靠近敌方弹珠的优先（进攻价值）
		for enemy in get_alive_marbles(gm, enemy_camp):
			if not is_instance_valid(enemy):
				continue
			var enemy_pos = enemy.hex_coord
			var dist = _hex_distance(pos, enemy_pos)
			if dist <= 3:
				score += 1.0 / max(1.0, float(dist))
		
		# 2. 颜色价值加权
		score += COLOR_VALUES.get(marble.color, 1) * 0.5
		
		# 3. 靠近边界（可能把对方推出界）加分
		var dist_to_center = max(abs(pos.x), abs(pos.y), abs(-pos.x - pos.y))
		var edge_dist = MarbleConst.GRID_RADIUS - dist_to_center
		if edge_dist <= 2:
			score += 2.0
		
		if score > best_score:
			best_score = score
			best_marble = marble
	
	return {"action": "select_marble", "marble": best_marble}

# ── 方向选择（非红球）──
func _decide_direction_heuristic(gm: GameManager) -> Dictionary:
	if not is_instance_valid(gm.selected_marble) or not gm.selected_marble.is_alive:
		return {"action": "select_direction", "direction": randi() % 6}
	
	var marble = gm.selected_marble
	var marble_pos = marble.hex_coord
	var enemy_camp = opponent(gm.current_team)
	
	# 根据颜色选择最佳方向
	var marble_color = marble.color
	
	match marble_color:
		MarbleConst.MarbleColor.WHITE:
			return _decide_white_direction(gm, marble, marble_pos, enemy_camp)
		MarbleConst.MarbleColor.BLUE:
			return _decide_blue_direction(gm, marble, marble_pos, enemy_camp)
		MarbleConst.MarbleColor.GREEN:
			return _decide_green_direction(gm, marble, marble_pos, enemy_camp)
		MarbleConst.MarbleColor.YELLOW:
			return _decide_yellow_direction(gm, marble, marble_pos, enemy_camp)
		_:
			# 默认：评估每个方向
			return _evaluate_directions(gm, marble, marble_pos, enemy_camp)

# 评估所有6个方向，选择最佳
func _evaluate_directions(gm: GameManager, marble: Marble2D, pos: Vector2, enemy_camp: int, power: int = 3) -> Dictionary:
	var best_dir = 0
	var best_score = -9999.0
	
	# 如果当前弹珠是蓝色，还需要考虑随从生成位
	var is_blue = (marble.color == MarbleConst.MarbleColor.BLUE)
	
	for dir in range(6):
		var score = _evaluate_single_direction(gm, marble, pos, dir, enemy_camp, power, is_blue)
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return {"action": "select_direction", "direction": best_dir}

# 评估单个方向
func _evaluate_single_direction(gm: GameManager, marble: Marble2D, pos: Vector2, dir: int, enemy_camp: int, power: int, is_blue: bool) -> float:
	var score = 0.0
	var target_pos = _simulate_line_movement(pos, dir, power)
	
	# 1. 如果方向指向棋盘外（自杀），负分
	if gm.hex_grid.is_out_of_bounds(int(target_pos.x), int(target_pos.y)):
		score -= 100.0
	
	# 2. 沿途经过敌方弹珠加分（碰撞可能吃掉对方）
	var current = pos
	for step in range(1, power + 1):
		current = _get_neighbor_hex(current, dir)
		if gm.hex_grid.is_out_of_bounds(int(current.x), int(current.y)):
			break
		var other = gm.hex_grid.get_marble_at(int(current.x), int(current.y))
		if other != null and other.is_alive:
			if other.camp == enemy_camp:
				score += 15.0  # 能撞到敌方弹珠
			else:
				score -= 5.0  # 撞到友方弹珠
	
	# 3. 指向敌方区域加分
	var dist_to_enemy = 999
	for enemy in get_alive_marbles(gm, enemy_camp):
		if not is_instance_valid(enemy):
			continue
		var d = _hex_distance(target_pos, enemy.hex_coord)
		if d < dist_to_enemy:
			dist_to_enemy = d
	score += 10.0 / max(1.0, float(dist_to_enemy))
	
	# 4. 指向棋盘中心方向加分（控制力）
	var target_dist_to_center = max(abs(target_pos.x), abs(target_pos.y), abs(-target_pos.x - target_pos.y))
	if target_dist_to_center <= MarbleConst.GRID_RADIUS:
		score += (MarbleConst.GRID_RADIUS - target_dist_to_center) * 0.5
	
	# 5. 蓝色：检查随从生成位是否可用
	if is_blue:
		var left_dir = (dir + 1) % 6
		var right_dir = (dir + 5) % 6
		for spawn_dir in [left_dir, right_dir]:
			var spawn_pos = _get_neighbor_hex(pos, spawn_dir)
			if not gm.hex_grid.is_out_of_bounds(int(spawn_pos.x), int(spawn_pos.y)):
				var existing = gm.hex_grid.get_marble_at(int(spawn_pos.x), int(spawn_pos.y))
				if existing == null or not existing.is_alive:
					score += 3.0  # 有随从生成位加分
				else:
					score -= 2.0  # 生成位被占减分
	
	return score

# ── 白球策略 ──
func _decide_white_direction(gm: GameManager, marble: Marble2D, pos: Vector2, enemy_camp: int) -> Dictionary:
	# 白球：往有敌方弹珠的方向走，利用碰撞将对方推出界
	# 白球被友方碰撞时步数+1，所以也可以往友方密集区走
	return _evaluate_directions(gm, marble, pos, enemy_camp, 3)

# ── 蓝球策略 ──
func _decide_blue_direction(gm: GameManager, marble: Marble2D, pos: Vector2, enemy_camp: int) -> Dictionary:
	# 蓝球：选择随从生成位置最优的方向
	# 随从在两侧生成，考虑随从阻挡对方路径
	var best_dir = 0
	var best_score = -9999.0
	var power = 3
	
	for dir in range(6):
		var score = _evaluate_single_direction(gm, marble, pos, dir, enemy_camp, power, true)
		
		# 额外：随从是否能堵住敌方路线
		var left_dir = (dir + 1) % 6
		var right_dir = (dir + 5) % 6
		for spawn_dir in [left_dir, right_dir]:
			var spawn_pos = _get_neighbor_hex(pos, spawn_dir)
			if not gm.hex_grid.is_out_of_bounds(int(spawn_pos.x), int(spawn_pos.y)):
				# 如果随从生成位靠近敌方弹珠，加分
				for enemy in get_alive_marbles(gm, enemy_camp):
					if not is_instance_valid(enemy):
						continue
					var d = _hex_distance(spawn_pos, enemy.hex_coord)
					if d <= 2:
						score += 2.0  # 随从可以阻塞敌方路线
		
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return {"action": "select_direction", "direction": best_dir}

# ── 绿球策略 ──
func _decide_green_direction(gm: GameManager, marble: Marble2D, pos: Vector2, enemy_camp: int) -> Dictionary:
	# 绿球：往敌方密集区走，利用推挤一次推动多个敌方弹珠
	# 推挤范围1格，被推的弹珠只移动1格
	# 优先瞄准边界附近的敌方弹珠
	var best_dir = 0
	var best_score = -9999.0
	var power = 3
	
	for dir in range(6):
		var score = _evaluate_single_direction(gm, marble, pos, dir, enemy_camp, power, false)
		
		# 绿球特有：检查路径上是否有可推挤的敌方弹珠
		var current = pos
		for step in range(power):
			current = _get_neighbor_hex(current, dir)
			if gm.hex_grid.is_out_of_bounds(int(current.x), int(current.y)):
				break
			var other = gm.hex_grid.get_marble_at(int(current.x), int(current.y))
			if other != null and other.is_alive and other.camp == enemy_camp:
				# 敌方弹珠后面有边界？容易被推出界
				var behind = _get_neighbor_hex(current, dir)
				if gm.hex_grid.is_out_of_bounds(int(behind.x), int(behind.y)):
					score += 20.0  # 一击必杀！
				else:
					score += 10.0  # 可以推挤
		
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return {"action": "select_direction", "direction": best_dir}

# ── 黄球策略 ──
func _decide_yellow_direction(gm: GameManager, marble: Marble2D, pos: Vector2, enemy_camp: int) -> Dictionary:
	# 黄球：用期望步数做决策，靠近边界时小心步数超出
	# 实际步数 = 力度 ± 1（至少1步）
	# 用期望值决策
	var best_dir = 0
	var best_score = -9999.0
	
	for dir in range(6):
		var score = 0.0
		
		# 评估3种可能的实际步数（期望值）
		for actual_steps in [2, 3, 4]:
			var prob = 1.0 / 3.0  # 均匀分布
			var target_pos = _simulate_line_movement(pos, dir, actual_steps)
			
			if gm.hex_grid.is_out_of_bounds(int(target_pos.x), int(target_pos.y)):
				# 可能出界自杀
				if actual_steps > 1:
					score -= 50.0 * prob
				continue
			
			# 沿途碰撞加分
			var current = pos
			for step in range(1, actual_steps + 1):
				current = _get_neighbor_hex(current, dir)
				if gm.hex_grid.is_out_of_bounds(int(current.x), int(current.y)):
					score -= 50.0 * prob
					break
				var other = gm.hex_grid.get_marble_at(int(current.x), int(current.y))
				if other != null and other.is_alive and other.camp == enemy_camp:
					score += 15.0 * prob
			
			# 指向敌方区域
			var min_dist = 999
			for enemy in get_alive_marbles(gm, enemy_camp):
				if not is_instance_valid(enemy):
					continue
				var d = _hex_distance(target_pos, enemy.hex_coord)
				if d < min_dist:
					min_dist = d
			score += (10.0 / max(1.0, float(min_dist))) * prob
		
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return {"action": "select_direction", "direction": best_dir}

# ── 力度选择 ──
func _decide_power_heuristic(gm: GameManager) -> Dictionary:
	if not is_instance_valid(gm.selected_marble) or not gm.selected_marble.is_alive:
		return {"action": "select_power", "power": 3}
	
	var marble = gm.selected_marble
	var pos = marble.hex_coord
	var dir = gm.selected_direction
	var enemy_camp = opponent(gm.current_team)
	
	var best_power = 3
	var best_score = -9999.0
	
	for power in range(1, 6):
		var score = 0.0
		
		# 检查是否会把自己送出界
		var target_pos = _simulate_line_movement(pos, dir, power)
		if gm.hex_grid.is_out_of_bounds(int(target_pos.x), int(target_pos.y)):
			# 威力过大会出界
			score -= 80.0 + (power * 5)  # 越大的力量出界代价越高
		else:
			# 步数适中加分
			score += power * 2.0
		
		# 沿途碰撞敌方弹珠加分
		var current = pos
		var hit_enemy = false
		for step in range(1, power + 1):
			current = _get_neighbor_hex(current, dir)
			if gm.hex_grid.is_out_of_bounds(int(current.x), int(current.y)):
				break
			var other = gm.hex_grid.get_marble_at(int(current.x), int(current.y))
			if other != null and other.is_alive:
				if other.camp == enemy_camp:
					score += 20.0
					hit_enemy = true
				else:
					score -= 5.0
		
		# 如果是在黄球模式下，不做特殊处理（由方向选择处理期望值）
		if marble.color == MarbleConst.MarbleColor.YELLOW and power == 3:
			score += 3.0  # 推荐3步（期望值稳定）
		
		if score > best_score:
			best_score = score
			best_power = power
	
	return {"action": "select_power", "power": best_power}

# ── 红球专属：力度选择 ──
func _decide_red_power_heuristic(gm: GameManager) -> Dictionary:
	if not is_instance_valid(gm.selected_marble) or not gm.selected_marble.is_alive:
		return {"action": "red_power", "power": 3}
	
	var marble = gm.selected_marble
	var pos = marble.hex_coord
	var enemy_camp = opponent(gm.current_team)
	
	# 红球：暴力枚举步数1-5，对每种步数用贪心选方向，选综合最好的
	var best_power = 3
	var best_score = -9999.0
	
	for power in range(1, 6):
		var sim_score = _simulate_red_path(gm, marble, pos, power, enemy_camp)
		if sim_score > best_score:
			best_score = sim_score
			best_power = power
	
	return {"action": "red_power", "power": best_power}

# 模拟红球路径：用贪心策略逐格选方向
func _simulate_red_path(gm: GameManager, marble: Marble2D, start_pos: Vector2, steps: int, enemy_camp: int) -> float:
	var total_score = 0.0
	var current = start_pos
	
	for step in range(steps):
		# 对当前步的6个方向评分
		var best_dir = 0
		var best_dir_score = -9999.0
		
		for dir in range(6):
			var next_pos = _get_neighbor_hex(current, dir)
			var dir_score = 0.0
			
			# 出界 = 死亡
			if gm.hex_grid.is_out_of_bounds(int(next_pos.x), int(next_pos.y)):
				continue
			
			# 有弹珠？看是不是敌方的
			var other = gm.hex_grid.get_marble_at(int(next_pos.x), int(next_pos.y))
			if other != null and other.is_alive:
				if other.camp == enemy_camp:
					dir_score += 25.0  # 吃到敌方弹珠
				else:
					dir_score -= 10.0  # 撞到友方
			
			# 向敌方方向前进
			var min_enemy_dist = 999.0
			for enemy in get_alive_marbles(gm, enemy_camp):
				if not is_instance_valid(enemy):
					continue
				var d = _hex_distance(next_pos, enemy.hex_coord)
				if d < min_enemy_dist:
					min_enemy_dist = d
			dir_score += 15.0 / max(1.0, min_enemy_dist)
			
			# 靠近边界加分（有机会把敌方推出界）
			var dist_to_edge = MarbleConst.GRID_RADIUS - max(abs(next_pos.x), abs(next_pos.y), abs(-next_pos.x - next_pos.y))
			if dist_to_edge <= 1:
				dir_score += 5.0
			
			if dir_score > best_dir_score:
				best_dir_score = dir_score
				best_dir = dir
		
		# 更新位置
		total_score += best_dir_score
		current = _get_neighbor_hex(current, best_dir)
		
		# 如果当前位置有敌方弹珠（碰撞），加分
		var enemy_at_pos = gm.hex_grid.get_marble_at(int(current.x), int(current.y))
		if enemy_at_pos != null and enemy_at_pos.is_alive and enemy_at_pos.camp == enemy_camp:
			total_score += 10.0
	
	return total_score

# ── 红球专属：逐格方向选择 ──
func _decide_red_direction_heuristic(gm: GameManager) -> Dictionary:
	if not is_instance_valid(gm.selected_marble) or not gm.selected_marble.is_alive:
		return {"action": "red_direction", "direction": randi() % 6}
	
	var marble = gm.selected_marble
	var current_pos = marble.hex_coord
	var enemy_camp = opponent(gm.current_team)
	
	var best_dir = 0
	var best_score = -999.0
	
	for dir in range(6):
		var next_pos = _get_neighbor_hex(current_pos, dir)
		var dir_score = 0.0
		
		# 出界 = 死亡
		if gm.hex_grid.is_out_of_bounds(int(next_pos.x), int(next_pos.y)):
			continue
		
		# 有弹珠？看是不是敌方的
		var other = gm.hex_grid.get_marble_at(int(next_pos.x), int(next_pos.y))
		if other != null and other.is_alive:
			if other.camp == enemy_camp:
				dir_score += 25.0  # 吃到敌方弹珠
			else:
				dir_score -= 10.0  # 撞到友方
		
		# 向敌方方向前进
		var min_enemy_dist = 999.0
		for enemy in get_alive_marbles(gm, enemy_camp):
			if not is_instance_valid(enemy):
				continue
			var d = _hex_distance(next_pos, enemy.hex_coord)
			if d < min_enemy_dist:
				min_enemy_dist = d
		dir_score += 15.0 / max(1.0, min_enemy_dist)
		
		# 靠近边界加分（有机会把敌方推出界）
		var dist_to_edge = MarbleConst.GRID_RADIUS - max(abs(next_pos.x), abs(next_pos.y), abs(-next_pos.x - next_pos.y))
		if dist_to_edge <= 1:
			dir_score += 5.0
		
		# 靠近己方弹珠的加分（利于后续碰撞）
		for friend in get_alive_marbles(gm, gm.current_team):
			if not is_instance_valid(friend) or friend == marble:
				continue
			var d = _hex_distance(next_pos, friend.hex_coord)
			if d == 1:
				dir_score += 3.0  # 紧邻友方，可能有碰撞加成
		
		if dir_score > best_score:
			best_score = dir_score
			best_dir = dir
	
	return {"action": "red_direction", "direction": best_dir}
# ── 黑球专属：选择敌方目标 ──
func _decide_black_target_heuristic(gm: GameManager) -> Dictionary:
	var enemy_marbles = get_alive_marbles(gm, opponent(gm.current_team))
	if enemy_marbles.size() == 0:
		push_error("HeuristicAI: 黑球没有敌方目标可选")
		return {}
	
	# 评分每个敌方目标
	var best_target = enemy_marbles[0]
	var best_score = -9999.0
	
	for enemy in enemy_marbles:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var pos = enemy.hex_coord
		var score = 0.0
		
		# 1. 靠近棋盘边缘的优先（容易被黑球推出界）
		var dist_to_center = max(abs(pos.x), abs(pos.y), abs(-pos.x - pos.y))
		var edge_dist = MarbleConst.GRID_RADIUS - dist_to_center
		score += (MarbleConst.GRID_RADIUS - edge_dist) * 1.0  # 越靠近边缘分越高
		
		# 2. 高价值颜色优先（优先消灭白/蓝）
		score += COLOR_VALUES.get(enemy.color, 1) * 2.0
		
		# 3. 与其附近友方密集程度（黑球推出会导致连带碰撞）
		var friend_nearby = 0
		for friend in get_alive_marbles(gm, gm.current_team):
			if not is_instance_valid(friend):
				continue
			var d = _hex_distance(pos, friend.hex_coord)
			if d <= 2:
				friend_nearby += 1
		score -= friend_nearby * 3.0  # 附近有友方可能误伤
		
		# 4. 敌方周围是否有其他敌方弹珠（推出界可能导致连锁反应）
		var enemy_nearby = 0
		for other_enemy in enemy_marbles:
			if not is_instance_valid(other_enemy) or other_enemy == enemy:
				continue
			var d = _hex_distance(pos, other_enemy.hex_coord)
			if d <= 2:
				enemy_nearby += 1
		score += enemy_nearby * 1.0  # 周边敌方多，碰撞效果更好
		
		if score > best_score:
			best_score = score
			best_target = enemy
	
	return {"action": "select_enemy", "marble": best_target}
# ── 黑球专属：选择大致方向（倾向指向棋盘外）──
func _decide_black_approx_direction_heuristic(gm: GameManager) -> Dictionary:
	var enemy = gm.black_target_marble
	if enemy and is_instance_valid(enemy) and enemy.is_alive:
		var q = enemy.hex_coord.x
		var r = enemy.hex_coord.y
		
		# 根据敌方坐标计算6个方向的"出界评分"
		# 模拟走3步，算出界概率
		var dir_scores = []
		for dir in range(6):
			var score = 0
			var current = Vector2(q, r)
			for step in range(3):
				var neighbor = _get_neighbor_hex(current, dir)
				if gm.hex_grid.is_out_of_bounds(int(neighbor.x), int(neighbor.y)):
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