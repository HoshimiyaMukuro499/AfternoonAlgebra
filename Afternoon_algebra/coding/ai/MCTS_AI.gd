# MCTS_AI.gd
# 蒙特卡洛树搜索（MCTS）AI 策略
# 通过大量模拟对局来评估走法，实现高级决策能力
# 
# 核心算法：
# 1. Selection（选择）：UCT 公式选择最佳子节点
# 2. Expansion（扩展）：为合法动作添加子节点
# 3. Simulation（模拟）：随机 playout 到终局
# 4. Backpropagation（回传）：更新节点统计
#
# 相较于 HeuristicAI 的优势：
# - 无需手工设计评估函数
# - 通过模拟自动发现深层策略
# - 天然支持随机性（黄球步数随机等）
extends AIStrategy

# MCTS 节点
class MCTSNode:
	var state         # 游戏状态快照（Dictionary，动态类型避免null赋值错误）
	var parent        # 父节点（MCTSNode）
	var children: Array  # 子节点列表
	var untried_actions: Array  # 尚未尝试的动作
	var action        # 到达此节点的动作（Dictionary）
		
	var visits: int = 0         # 访问次数
	var total_score: float = 0.0  # 总得分
	
	# UCT 常数（探索 vs 利用平衡）
	const UCT_C: float = 1.414
		
	func _init(p_state = null, p_parent = null, p_action = null):
		state = p_state if typeof(p_state) == TYPE_DICTIONARY else {}
		parent = p_parent
		children = []
		action = p_action if typeof(p_action) == TYPE_DICTIONARY else {}
		visits = 0
		total_score = 0.0
		untried_actions = []
	
	# UCB1 值（用于选择阶段）
	func ucb_value(parent_visits: int) -> float:
		if visits == 0:
			return INF  # 未访问的节点优先探索
		var exploitation = total_score / visits
		var exploration = UCT_C * sqrt(log(parent_visits) / visits)
		return exploitation + exploration
	
	# 获取平均分
	func average_score() -> float:
		if visits == 0:
			return 0.0
		return total_score / visits
	
	# 是否是叶节点
	func is_leaf() -> bool:
		return children.size() == 0
	
	# 是否完全展开
	func is_fully_expanded() -> bool:
		return untried_actions.size() == 0
	
	# 是否终端状态（游戏结束）
	func is_terminal() -> bool:
		return state.get("winner", -1) != -1


# MCTS 配置
var simulation_count: int = 1000      # 单次决策的模拟次数
var time_limit_ms: int = 3000         # 时间限制（毫秒），0 表示使用模拟次数限制
var use_time_limit: bool = false      # 是否使用时间限制
var debug_mode: bool = false          # 调试输出

# 对手策略（用于 playout 模拟）
var _random_ai_ref = null
var _random_ai_gd: Resource = null

func _init():
	_random_ai_gd = load("res://ai/RandomAI.gd")
	randomize()

# ── 主决策入口 ──
func decide(gm: GameManager) -> Dictionary:
	if gm.setup_phase_active:
		return _decide_setup_mcts(gm)
	
	# 构建当前游戏状态快照
	var snapshot = _capture_state(gm)
	
	# 运行 MCTS 搜索
	var best_action = _run_mcts(snapshot, gm)
	
	if best_action.is_empty():
		# 回退到随机决策
		if _random_ai_ref == null:
			_random_ai_ref = _random_ai_gd.new()
		return _random_ai_ref.decide(gm)
	
	# 将 marble_id 转换为 marble 引用（GameManager API 需要）
	if best_action.get("action") == "select_marble":
		var marble_id = best_action.get("marble_id", 0)
		for marble in gm.all_marbles:
			if is_instance_valid(marble) and marble.get_instance_id() == marble_id:
				best_action["marble"] = marble
				break
	
	return best_action

# ── 选珠阶段（使用启发式策略，MCTS 不参与选珠）──
func _decide_setup_mcts(gm: GameManager) -> Dictionary:
	# 选珠阶段使用启发式策略，因为选珠阶段的模拟对后续影响太大
	# 且选珠决策空间较小，启发式已足够
	match gm.setup_state:
		GameManager.SetupState.COLOR_SELECT:
			return _decide_setup_color(gm)
		GameManager.SetupState.PLACEMENT:
			return _decide_setup_placement(gm)
	return {}

func _decide_setup_color(gm: GameManager) -> Dictionary:
	# 获取已选颜色
	var camp = gm.setup_current_team
	var used = []
	for marble in gm.all_marbles:
		if is_instance_valid(marble) and marble.camp == camp:
			used.append(marble.color)
	
	# 优先级：白 > 蓝 > 绿 > 红 > 黄 > 黑
	var priority = [
		MarbleConst.MarbleColor.WHITE,
		MarbleConst.MarbleColor.BLUE,
		MarbleConst.MarbleColor.GREEN,
		MarbleConst.MarbleColor.RED,
		MarbleConst.MarbleColor.YELLOW,
		MarbleConst.MarbleColor.BLACK,
	]
	
	for color in priority:
		if color not in used:
			return {"action": "setup_color", "color": color}
	
	return {"action": "setup_color", "color": randi() % MarbleConst.MarbleColor.size()}

func _decide_setup_placement(gm: GameManager) -> Dictionary:
	var positions = gm.hex_grid.get_available_positions(gm.setup_current_team)
	var available = []
	for pos in positions:
		var q = int(pos.x)
		var r = int(pos.y)
		if gm.hex_grid.get_marble_at(q, r) == null:
			available.append(pos)
	
	if available.size() == 0:
		return {}
	
	# 选择位置：中心偏好 + 分散布局
	var existing = []
	for marble in gm.all_marbles:
		if is_instance_valid(marble) and marble.camp == gm.setup_current_team:
			existing.append(marble.hex_coord)
	
	var best_pos = available[0]
	var best_score = -99999.0
	
	for pos in available:
		var q = int(pos.x)
		var r = int(pos.y)
		var dist_to_center = max(abs(q), abs(r), abs(-q - r))
		var center_score = float(MarbleConst.GRID_RADIUS - dist_to_center) / MarbleConst.GRID_RADIUS
		
		var min_dist_to_existing = 999.0
		for ep in existing:
			var d = _sim_hex_distance(Vector2(q, r), ep)
			if d < min_dist_to_existing:
				min_dist_to_existing = d
		
		var spread_score = 0.0
		if existing.size() > 0:
			spread_score = min(min_dist_to_existing / 3.0, 1.0)
		else:
			spread_score = 1.0
		
		var zone_bonus = 0.0
		if gm.setup_current_team == MarbleConst.Camp.RED and q >= -3:
			zone_bonus = 0.3
		elif gm.setup_current_team == MarbleConst.Camp.BLUE and q <= 3:
			zone_bonus = 0.3
		
		var score = center_score * 0.4 + spread_score * 0.4 + zone_bonus * 0.2
		if score > best_score:
			best_score = score
			best_pos = pos
	
	return {"action": "setup_place", "q": int(best_pos.x), "r": int(best_pos.y)}

# ═══════════════════════════════════════════════════
#  MCTS 核心算法
# ═══════════════════════════════════════════════════

# 运行 MCTS 搜索
func _run_mcts(root_state: Dictionary, gm: GameManager) -> Dictionary:
	var root = MCTSNode.new(root_state)
	
	# 生成根节点的合法动作
	_generate_legal_actions(root_state, gm, root)
	
	# 如果根节点已经是终局或没有可用动作，直接返回空
	if root.is_terminal() or root.untried_actions.size() == 0:
		return {}
	
	var start_time = Time.get_ticks_msec()
	var sims_done = 0
	var max_simulations = simulation_count
	
	while sims_done < max_simulations:
		# 检查时间限制
		if use_time_limit:
			var elapsed = Time.get_ticks_msec() - start_time
			if elapsed >= time_limit_ms:
				break
		
		# 1. Selection
		var node = _select_node(root)
		
		# 2. Expansion
		if not node.is_terminal() and not node.is_fully_expanded():
			node = _expand_node(node, gm)
		
		# 3. Simulation
		var result = _simulate(node.state, gm)
		
		# 4. Backpropagation
		_backpropagate(node, result)
		
		sims_done += 1
	
	# 选择访问次数最多的子节点（而非得分最高的，更稳定）
	var best_child = _best_child_by_visits(root)
	if best_child == null:
		return {}
	
	if debug_mode:
		print("MCTS: %d 次模拟，选择动作 %s，得分 %.2f" % [sims_done, _action_string(best_child.action), best_child.average_score()])
	
	return best_child.action.duplicate()


# Selection：从上到下选择 UCB 值最高的节点
func _select_node(node: MCTSNode) -> MCTSNode:
	while not node.is_terminal() and node.is_fully_expanded() and node.children.size() > 0:
		var best_child: MCTSNode = null
		var best_ucb = -INF
		
		for child in node.children:
			var ucb = child.ucb_value(node.visits)
			if ucb > best_ucb:
				best_ucb = ucb
				best_child = child
		
		if best_child == null:
			break
		node = best_child
	
	return node


# Expansion：为未尝试的动作创建子节点
func _expand_node(node: MCTSNode, gm: GameManager) -> MCTSNode:
	var action = node.untried_actions.pop_back()
	if action == null:
		return node
	
	# 模拟执行动作
	var new_state = _simulate_action(node.state, action, gm)
	if new_state.is_empty():
		return node
	
	# 创建子节点
	var child = MCTSNode.new(new_state, node, action)
	_generate_legal_actions(new_state, gm, child)
	node.children.append(child)
	
	return child


# Simulation：随机 playout 到终局
func _simulate(state: Dictionary, gm: GameManager) -> int:
	# 如果已经是终局，直接返回胜利方
	var winner = state.get("winner", -1)
	if winner != -1:
		return winner
	
	var current_state = _deep_copy_state(state)
	var max_steps = 50  # 防止无限循环
	var step = 0
	var camp = current_state.get("current_team", MarbleConst.Camp.RED)
	
	while step < max_steps:
		winner = current_state.get("winner", -1)
		if winner != -1:
			return winner
		
		# 获取当前阵营
		camp = current_state.get("current_team", MarbleConst.Camp.RED)
		var state_val = current_state.get("state", "idle")
		
		# 生成合法动作并随机选择
		var legal_actions = _generate_simulation_actions(current_state, camp, state_val)
		if legal_actions.size() == 0:
			break
		
		var action = legal_actions[randi() % legal_actions.size()]
		var next_state = _simulate_action(current_state, action, gm)
		
		if next_state.is_empty():
			break
		
		current_state = next_state
		step += 1
	
	# 如果超过步数限制，用弹珠数量判胜负
	var red_count = 0
	var blue_count = 0
	for m in current_state.get("marbles", []):
		if m.get("is_alive"):
			if m.get("camp") == MarbleConst.Camp.RED:
				red_count += 1
			else:
				blue_count += 1
	
	if red_count > blue_count:
		return MarbleConst.Camp.RED
	elif blue_count > red_count:
		return MarbleConst.Camp.BLUE
	
	# 平局：对当前玩家不利
	return opponent(camp)


# Backpropagation：从当前节点向上更新统计
func _backpropagate(node: MCTSNode, winner: int):
	while node != null:
		node.visits += 1
		if node.state.has("current_team"):
			var perspective = node.state["current_team"]
			if winner == perspective:
				node.total_score += 1.0
			elif winner == -1:
				node.total_score += 0.5  # 平局
			else:
				node.total_score -= 1.0
		else:
			node.total_score += 0.0
		node = node.parent


# 选择访问次数最多的子节点
func _best_child_by_visits(node: MCTSNode) -> MCTSNode:
	var best: MCTSNode = null
	var best_visits = -1
	
	for child in node.children:
		if child.visits > best_visits:
			best_visits = child.visits
			best = child
	
	return best


# ═══════════════════════════════════════════════════
#  游戏状态捕获与模拟
# ═══════════════════════════════════════════════════

# 捕获当前游戏状态
func _capture_state(gm: GameManager) -> Dictionary:
	var state = {
		"current_team": gm.current_team,
		"state": _get_state_name(gm.current_state),
		"turn_number": gm.turn_number,
		"marbles": [],
		"selected_marble": null,
		"selected_direction": -1,
		"selected_power": 0,
		"winner": -1,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
	}
		
	# 捕获所有弹珠信息
	for marble in gm.all_marbles:
		if not is_instance_valid(marble):
			continue
		state["marbles"].append({
			"id": marble.get_instance_id(),
			"camp": marble.camp,
			"color": marble.color,
			"is_alive": marble.is_alive,
			"hex_coord": marble.hex_coord if marble.hex_coord != Vector2.ZERO else gm.hex_grid.get_marble_hex(marble),
		})
		
	# 捕获选中弹珠信息
	if gm.selected_marble and is_instance_valid(gm.selected_marble):
		state["selected_marble"] = gm.selected_marble.get_instance_id()
		
	state["selected_direction"] = gm.selected_direction
	state["selected_power"] = gm.selected_power
	state["red_power"] = gm.red_total_steps
		
	# 检查是否已胜利
	var red_alive = false
	var blue_alive = false
	for m in state.get("marbles", []):
		if m.get("is_alive", false):
			if m.get("camp") == MarbleConst.Camp.RED:
				red_alive = true
			else:
				blue_alive = true
		
	# 只在有弹珠时判定胜利（空棋盘无胜利者）
	if red_alive and not blue_alive:
		state["winner"] = MarbleConst.Camp.RED
	elif blue_alive and not red_alive:
		state["winner"] = MarbleConst.Camp.BLUE
	# 否则保持 winner = -1（平局或游戏未结束）
	
	return state


# 获取状态名称（简化版）
func _get_state_name(state_val) -> String:
	match state_val:
		GameManager.TurnState.IDLE: return "idle"
		GameManager.TurnState.MARBLE_SELECTED: return "marble_selected"
		GameManager.TurnState.DIRECTION_SELECTED: return "direction_selected"
		GameManager.TurnState.RED_DIRECTION_PICKING: return "red_direction_picking"
		GameManager.TurnState.BLACK_MARBLE_SELECTED: return "black_marble_selected"
		GameManager.TurnState.BLACK_TARGET_PICKING: return "black_target_picking"
		GameManager.TurnState.EXECUTING: return "executing"
		GameManager.TurnState.VICTORY: return "victory"
		_: return "idle"


# 生成合法动作列表（用于 MCTS 节点展开）
func _generate_legal_actions(state: Dictionary, gm: GameManager, node: MCTSNode):
	var camp = state.get("current_team", MarbleConst.Camp.RED)
	var state_name = state.get("state", "idle")
	var actions = _generate_simulation_actions(state, camp, state_name)
	node.untried_actions = actions


# 生成模拟动作列表
func _generate_simulation_actions(state: Dictionary, camp: int, state_name: String) -> Array:
	var actions = []
	var marbles = state.get("marbles", [])
	
	match state_name:
		"idle":
			# 选择己方存活且非黑色的弹珠
			for m in marbles:
				if m.get("is_alive") and m.get("camp") == camp and m.get("color") != MarbleConst.MarbleColor.BLACK:
					actions.append({"action": "select_marble", "marble_id": m.get("id")})
			
			# 如果没有非黑弹珠，选黑色
			if actions.size() == 0:
				for m in marbles:
					if m.get("is_alive") and m.get("camp") == camp:
						actions.append({"action": "select_marble", "marble_id": m.get("id")})
		
		"marble_selected":
			var sel_id = state.get("selected_marble", 0)
			var sel_marble = _find_marble_in_state(state, sel_id)
			
			if sel_marble and sel_marble.get("color") == MarbleConst.MarbleColor.RED:
				# 红球选力度
				for p in range(1, 6):
					actions.append({"action": "red_power", "power": p})
			else:
				# 选择方向
				for d in range(6):
					actions.append({"action": "select_direction", "direction": d})
		
		"direction_selected":
			for p in range(1, 6):
				actions.append({"action": "select_power", "power": p})
		
		"red_direction_picking":
			for d in range(6):
				actions.append({"action": "red_direction", "direction": d})
		
		"black_marble_selected":
			for m in marbles:
				if m.get("is_alive") and m.get("camp") != camp:
					actions.append({"action": "select_enemy", "marble_id": m.get("id")})
		
		"black_target_picking":
			for d in range(6):
				actions.append({"action": "select_approx_direction", "direction": d})
	
	return actions


# 模拟执行一个动作，返回新状态
func _simulate_action(state: Dictionary, action: Dictionary, gm: GameManager) -> Dictionary:
	var new_state = _deep_copy_state(state)
	var action_type = action.get("action", "")
	var camp = new_state.get("current_team", MarbleConst.Camp.RED)
	
	match action_type:
		"select_marble":
			var marble_id = action.get("marble_id", 0)
			var marble = _find_marble_in_state(new_state, marble_id)
			if marble == null:
				return {}
			
			new_state["selected_marble"] = marble_id
			
			if marble.get("color") == MarbleConst.MarbleColor.RED:
				new_state["state"] = "marble_selected"  # 等待选力度
			elif marble.get("color") == MarbleConst.MarbleColor.BLACK:
				new_state["state"] = "black_marble_selected"
			else:
				new_state["state"] = "marble_selected"
		
		"select_direction":
			var dir = action.get("direction", 0)
			new_state["selected_direction"] = dir
			new_state["state"] = "direction_selected"
		
		"select_power":
			var power = action.get("power", 3)
			new_state["selected_power"] = power
			# 执行移动
			new_state = _simulate_execute_move(new_state)
		
		"red_power":
			var power = action.get("power", 3)
			new_state["red_power"] = power
			new_state["state"] = "red_direction_picking"
		
		"red_direction":
			var dir = action.get("direction", 0)
			# 执行一步红球移动
			new_state = _simulate_red_step(new_state, dir)
		
		"select_enemy":
			var target_id = action.get("marble_id", 0)
			new_state["black_target_coord"] = _find_marble_coord(new_state, target_id)
			new_state["state"] = "black_target_picking"
		
		"select_approx_direction":
			var dir = action.get("direction", 0)
			new_state["black_approx_dir"] = dir
			# 执行黑球强制移动
			new_state = _simulate_black_move(new_state)
		
		_:
			# 未知动作
			return {}
	
	return new_state


# 模拟执行移动（非红球）
func _simulate_execute_move(state: Dictionary) -> Dictionary:
	var sel_id = state.get("selected_marble", 0)
	var marble = _find_marble_in_state(state, sel_id)
	if marble == null:
		state["state"] = "idle"
		return state
	
	var dir = state.get("selected_direction", 0)
	var power = state.get("selected_power", 3)
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var camp = marble.get("camp")
	
	# 执行逐格移动
	var current_pos = pos
	
	for step in range(1, power + 1):
		if not marble.get("is_alive", true):
			break
		
		var next_pos = _sim_get_neighbor(current_pos, dir)
		
		# 出界检查
		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break
		
		# 碰撞检查
		var target = _sim_get_marble_at(state, next_pos)
		if target != null and target.get("is_alive", false):
			# 碰撞：被撞弹珠继续移动
			var remaining = power - step
			if remaining > 0:
				_sim_collision_move(state, target, dir, remaining)
			# 攻击者停下
			current_pos = next_pos
			_sim_set_marble_pos(state, marble, current_pos)
			break
		else:
			# 空位移动
			_sim_set_marble_pos(state, marble, next_pos)
			current_pos = next_pos
	
	# 检查胜利（只设 winner，不设 state）
	_sim_check_victory(state)
	
	# 如果已有胜利者，结束
	if state.get("winner", -1) != -1:
		state["state"] = "victory"
		return state
	
	# 切换回合
	state["state"] = "idle"
	state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	state["turn_number"] = state.get("turn_number", 0) + 1
	
	return state


# 模拟红球走一步
func _simulate_red_step(state: Dictionary, dir: int) -> Dictionary:
	var sel_id = state.get("selected_marble", 0)
	var marble = _find_marble_in_state(state, sel_id)
	if marble == null:
		state["state"] = "idle"
		return state
	
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var camp = marble.get("camp")
	
	var next_pos = _sim_get_neighbor(pos, dir)
	
	# 出界检查
	if _sim_is_out_of_bounds(next_pos):
		marble["is_alive"] = false
		_gmark_dirty(state, marble)
		# 红球死亡，检查胜利
		_sim_check_victory(state)
		if state.get("winner", -1) != -1:
			state["state"] = "victory"
			return state
		# 结束回合
		state["state"] = "idle"
		state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
		state["turn_number"] = state.get("turn_number", 0) + 1
		return state
	
	# 碰撞检查
	var target = _sim_get_marble_at(state, next_pos)
	if target != null and target.get("is_alive", false):
		# 碰撞：目标被撞走
		_sim_collision_move(state, target, dir, 1)
	
	# 移动
	_sim_set_marble_pos(state, marble, next_pos)
	
	# 检查红球是否走完
	var red_power = state.get("red_power", 3)
	var dirs = state.get("red_directions", [])
	dirs.append(dir)
	state["red_directions"] = dirs
	
	if dirs.size() >= red_power or not marble.get("is_alive", true):
		# 红球走完，检查胜利
		_sim_check_victory(state)
		
		# 如果已有胜利者，结束
		if state.get("winner", -1) != -1:
			state["state"] = "victory"
			return state
		
		state["state"] = "idle"
		state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
		state["turn_number"] = state.get("turn_number", 0) + 1
	else:
		# 继续下一格
		state["state"] = "red_direction_picking"
	
	return state


# 模拟黑球强制移动
func _simulate_black_move(state: Dictionary) -> Dictionary:
	var target_coord = state.get("black_target_coord", null)
	var dir = state.get("black_approx_dir", 0)
	
	if target_coord == null:
		state["state"] = "idle"
		return state
	
	var camp = state.get("current_team", MarbleConst.Camp.RED)
	
	# 目标沿方向移动3格
	var current_pos = target_coord
	var target = _sim_get_marble_at(state, current_pos)
	
	if target == null or not target.get("is_alive", false):
		state["state"] = "idle"
		state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
		return state
	
	for step in range(3):
		if not target.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)
		
		if _sim_is_out_of_bounds(next_pos):
			target["is_alive"] = false
			_gmark_dirty(state, target)
			break
		
		var blocker = _sim_get_marble_at(state, next_pos)
		if blocker != null and blocker.get("is_alive", false):
			_sim_collision_move(state, blocker, dir, 1)
		
		_sim_set_marble_pos(state, target, next_pos)
		current_pos = next_pos
	
	_sim_check_victory(state)
	
	# 如果已有胜利者，结束
	if state.get("winner", -1) != -1:
		state["state"] = "victory"
		return state
	
	state["state"] = "idle"
	state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	
	return state


# 模拟碰撞移动
func _sim_collision_move(state: Dictionary, marble: Dictionary, dir: int, steps: int):
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var current_pos = pos
	
	for step in range(steps):
		if not marble.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)
		
		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break
		
		var blocker = _sim_get_marble_at(state, next_pos)
		if blocker != null and blocker.get("is_alive", false):
			var remaining = steps - step
			if remaining > 0:
				_sim_collision_move(state, blocker, dir, remaining)
			_sim_set_marble_pos(state, marble, next_pos)
			break
		else:
			_sim_set_marble_pos(state, marble, next_pos)
			current_pos = next_pos


# 检查胜利条件（只设 winner，不设 state，由调用方根据 winner 设 state）
func _sim_check_victory(state: Dictionary):
	var red_alive = false
	var blue_alive = false
	
	for m in state.get("marbles", []):
		if m.get("is_alive", false):
			if m.get("camp") == MarbleConst.Camp.RED:
				red_alive = true
			else:
				blue_alive = true
	
	if not red_alive:
		state["winner"] = MarbleConst.Camp.BLUE
	elif not blue_alive:
		state["winner"] = MarbleConst.Camp.RED


# ═══════════════════════════════════════════════════
#  快照工具方法
# ═══════════════════════════════════════════════════

# 深拷贝状态（避免引用共享）
func _deep_copy_state(state: Dictionary) -> Dictionary:
	var new_state = {}
	for key in state.keys():
		match typeof(state[key]):
			TYPE_DICTIONARY:
				# 不复制嵌套字典
				new_state[key] = state[key].duplicate(true)
			TYPE_ARRAY:
				var new_arr = []
				for item in state[key]:
					if typeof(item) == TYPE_DICTIONARY:
						new_arr.append(item.duplicate(true))
					else:
						new_arr.append(item)
				new_state[key] = new_arr
			_:
				new_state[key] = state[key]
	return new_state


# 在状态中查找弹珠数据
func _find_marble_in_state(state: Dictionary, marble_id: int) -> Dictionary:
	for m in state.get("marbles", []):
		if m.get("id") == marble_id:
			return m
	return {}


# 在状态中查找弹珠坐标
func _find_marble_coord(state: Dictionary, marble_id: int) -> Vector2:
	var m = _find_marble_in_state(state, marble_id)
	return m.get("hex_coord", Vector2(0, 0))


# 标记弹珠状态变更（预留接口）
func _gmark_dirty(_state: Dictionary, _marble: Dictionary):
	pass


# 设置弹珠位置
func _sim_set_marble_pos(_state: Dictionary, marble: Dictionary, pos: Vector2):
	marble["hex_coord"] = pos


# 获取指定位置的弹珠
func _sim_get_marble_at(state: Dictionary, pos: Vector2) -> Dictionary:
	for m in state.get("marbles", []):
		if m.get("is_alive", false) and m.get("hex_coord") == pos:
			return m
	return {}


# 检查位置是否出界
func _sim_is_out_of_bounds(pos: Vector2) -> bool:
	var q = int(pos.x)
	var r = int(pos.y)
	var s = -q - r
	return abs(q) > MarbleConst.GRID_RADIUS or abs(r) > MarbleConst.GRID_RADIUS or abs(s) > MarbleConst.GRID_RADIUS


# 计算邻居坐标
func _sim_get_neighbor(hex: Vector2, dir: int) -> Vector2:
	var dirs = [
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(-1, 1),
		Vector2(-1, 0),
		Vector2(0, -1),
		Vector2(1, -1),
	]
	return hex + dirs[dir]


# 六边形距离
func _sim_hex_distance(a: Vector2, b: Vector2) -> float:
	var dq = abs(a.x - b.x)
	var dr = abs(a.y - b.y)
	var ds = abs((-a.x - a.y) - (-b.x - b.y))
	return max(dq, dr, ds)


# 对手阵营
func opponent(camp: int) -> int:
	return MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED


# 动作描述（调试用）
func _action_string(action: Dictionary) -> String:
	if action.is_empty():
		return "空"
	return action.get("action", "未知") + "=" + str(action.get("direction", action.get("power", action.get("marble_id", "?"))))


# 配置方法
func set_simulation_count(count: int):
	simulation_count = count

func set_time_limit(ms: int):
	time_limit_ms = ms
	use_time_limit = true

func set_debug_mode(enabled: bool):
	debug_mode = enabled
