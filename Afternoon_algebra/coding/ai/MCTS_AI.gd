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
		var marble_data = {
			"id": marble.get_instance_id(),
			"camp": marble.camp,
			"color": marble.color,
			"is_alive": marble.is_alive,
			"hex_coord": marble.hex_coord if marble.hex_coord != Vector2.ZERO else gm.hex_grid.get_marble_hex(marble),
		}
		
		# 捕获颜色特有属性（白球（变色后）或原生颜色弹珠均可能持有）
		if "push_range" in marble:
			marble_data["push_range"] = marble.push_range
		else:
			marble_data["push_range"] = 1  # 默认值
		
		if "max_steps" in marble:
			marble_data["max_steps"] = marble.max_steps
		else:
			marble_data["max_steps"] = 4  # 默认值
		
		if "enhanced" in marble:
			marble_data["enhanced"] = marble.enhanced
		else:
			marble_data["enhanced"] = false
		
		if "follower_safe" in marble:
			marble_data["follower_safe"] = marble.follower_safe
		else:
			marble_data["follower_safe"] = false
		
		if "has_changed" in marble:
			marble_data["has_changed"] = marble.has_changed
		else:
			marble_data["has_changed"] = false
		
		state["marbles"].append(marble_data)
		
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


# 模拟执行移动（根据弹珠颜色分发）
func _simulate_execute_move(state: Dictionary) -> Dictionary:
	var sel_id = state.get("selected_marble", 0)
	var marble = _find_marble_in_state(state, sel_id)
	if marble == null:
		state["state"] = "idle"
		return state
	
	var color = marble.get("color", MarbleConst.MarbleColor.WHITE)
	
	match color:
		MarbleConst.MarbleColor.BLUE:
			return _sim_blue_move(state, marble)
		MarbleConst.MarbleColor.GREEN:
			return _sim_green_move(state, marble)
		MarbleConst.MarbleColor.YELLOW:
			return _sim_yellow_move(state, marble)
		MarbleConst.MarbleColor.WHITE:
			return _sim_white_move(state, marble)
		_:
			# 黑球无法主动移动（防御性兜底）
			return _sim_basic_move(state, marble)


# 模拟红球走一步
func _simulate_red_step(state: Dictionary, dir: int) -> Dictionary:
	var sel_id = state.get("selected_marble", 0)
	var marble = _find_marble_in_state(state, sel_id)
	if marble == null:
		state["state"] = "idle"
		return state
	
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var camp = marble.get("camp")
	var max_steps = marble.get("max_steps", 4)
	var red_power = state.get("red_power", 3)
	var actual_power = min(red_power, max_steps)
	
	var next_pos = _sim_get_neighbor(pos, dir)
	
	# 出界检查
	if _sim_is_out_of_bounds(next_pos):
		marble["is_alive"] = false
		_gmark_dirty(state, marble)
		_sim_check_victory(state)
		if state.get("winner", -1) != -1:
			state["state"] = "victory"
			return state
		_sim_post_action_events(state)
		_sim_check_victory(state)
		if state.get("winner", -1) != -1:
			state["state"] = "victory"
			return state
		state["state"] = "idle"
		state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
		state["turn_number"] = state.get("turn_number", 0) + 1
		return state
	
	# 碰撞检查（红球特殊碰撞：目标获得剩余步数-2，红球继续）
	var dirs = state.get("red_directions", [])
	var remaining_total = actual_power - dirs.size()
	
	var target = _sim_get_marble_at(state, next_pos)
	if target != null and target.get("is_alive", false):
		var push_steps = remaining_total - 2
		if push_steps > 0:
			_sim_collision_move(state, target, dir, push_steps, marble)
		# 检查目标是否已离开
		if _sim_get_marble_at(state, next_pos) == null:
			# 红球移入
			_sim_set_marble_pos(state, marble, next_pos)
		else:
			# 目标未离开，红球停止
			dirs.append(dir)
			state["red_directions"] = dirs
			# 红球本次停止，结束回合
			_sim_check_victory(state)
			if state.get("winner", -1) != -1:
				state["state"] = "victory"
				return state
			_sim_post_action_events(state)
			_sim_check_victory(state)
			if state.get("winner", -1) != -1:
				state["state"] = "victory"
				return state
			state["state"] = "idle"
			state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
			state["turn_number"] = state.get("turn_number", 0) + 1
			return state
	else:
		_sim_set_marble_pos(state, marble, next_pos)
	
	dirs.append(dir)
	state["red_directions"] = dirs
	
	if dirs.size() >= actual_power or not marble.get("is_alive", true):
		_sim_check_victory(state)
		if state.get("winner", -1) != -1:
			state["state"] = "victory"
			return state
		_sim_post_action_events(state)
		_sim_check_victory(state)
		if state.get("winner", -1) != -1:
			state["state"] = "victory"
			return state
		state["state"] = "idle"
		state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
		state["turn_number"] = state.get("turn_number", 0) + 1
	else:
		state["state"] = "red_direction_picking"
	
	return state


# 模拟黑球强制移动
func _simulate_black_move(state: Dictionary) -> Dictionary:
	var target_coord = state.get("black_target_coord", null)
	var approx_dir = state.get("black_approx_dir", 0)
	
	if target_coord == null:
		state["state"] = "idle"
		return state
	
	# 获取黑球弹珠以查询 enhanced 属性
	var sel_id = state.get("selected_marble", 0)
	var marble = _find_marble_in_state(state, sel_id)
	var enhanced = marble.get("enhanced", false) if marble != null else false
	
	# 随机方向（指定方向 ±60°）
	var offset = randi() % 3 - 1
	var actual_dir = (approx_dir + offset) % 6
	if actual_dir < 0:
		actual_dir += 6
	
	# 步数：增强后固定3，否则随机2或3
	var steps = 3 if enhanced else (2 if randi() % 2 == 0 else 3)
	
	var camp = state.get("current_team", MarbleConst.Camp.RED)
	
	var current_pos = target_coord
	var target = _sim_get_marble_at(state, current_pos)
	
	if target == null or not target.get("is_alive", false):
		state["state"] = "idle"
		state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
		return state
	
	for step in range(steps):
		if not target.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, actual_dir)
		
		if _sim_is_out_of_bounds(next_pos):
			target["is_alive"] = false
			_gmark_dirty(state, target)
			break
		
		var blocker = _sim_get_marble_at(state, next_pos)
		if blocker != null and blocker.get("is_alive", false):
			_sim_collision_move(state, blocker, actual_dir, 1, marble)
		
		_sim_set_marble_pos(state, target, next_pos)
		current_pos = next_pos
	
	_sim_check_victory(state)
	
	if state.get("winner", -1) != -1:
		state["state"] = "victory"
		return state
	
	_sim_post_action_events(state)
	_sim_check_victory(state)
	if state.get("winner", -1) != -1:
		state["state"] = "victory"
		return state
	
	state["state"] = "idle"
	state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	
	return state


# 模拟碰撞移动（含白球友方碰撞步数+1）
# 注意：collider 是碰撞发起方，marble 是被撞方
func _sim_collision_move(state: Dictionary, marble: Dictionary, dir: int, steps: int, collider: Dictionary = {}):
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var current_pos = pos
	
	# 白球被友方碰撞时步数+1
	var actual_steps = steps
	if marble.get("color") == MarbleConst.MarbleColor.WHITE and not collider.is_empty():
		if collider.get("camp") == marble.get("camp"):
			actual_steps += 1
	
	for step in range(actual_steps):
		if not marble.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)
		
		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break
		
		var blocker = _sim_get_marble_at(state, next_pos)
		if blocker != null and blocker.get("is_alive", false):
			var remaining = actual_steps - step
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


# ── 白球移动（友方碰撞 +1 步） ──
func _sim_white_move(state: Dictionary, marble: Dictionary) -> Dictionary:
	var dir = state.get("selected_direction", 0)
	var power = state.get("selected_power", 3)
	var camp = marble.get("camp")
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var current_pos = pos

	for step in range(1, power + 1):
		if not marble.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)

		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break

		var target = _sim_get_marble_at(state, next_pos)
		if target != null and target.get("is_alive", false):
			var remaining = power - step
			# 白球特有：被友方碰撞时步数 +1
			if target.get("color") == MarbleConst.MarbleColor.WHITE and target.get("camp") == camp:
				remaining += 1
			if remaining > 0:
				_sim_collision_move(state, target, dir, remaining)
			current_pos = next_pos
			_sim_set_marble_pos(state, marble, current_pos)
			break
		else:
			_sim_set_marble_pos(state, marble, next_pos)
			current_pos = next_pos

	return _sim_end_turn(state, camp)


# ── 蓝球移动（随从生成+移动+死亡检测） ──
func _sim_blue_move(state: Dictionary, marble: Dictionary) -> Dictionary:
	var dir = state.get("selected_direction", 0)
	var power = state.get("selected_power", 3)
	var camp = marble.get("camp")
	var pos = marble.get("hex_coord", Vector2(0, 0))

	# 模拟生成随从（左右两侧各1个）
	var left_dir = (dir + 1) % 6
	var right_dir = (dir + 5) % 6
	var followers = []
	for spawn_dir in [left_dir, right_dir]:
		var spawn_pos = _sim_get_neighbor(pos, spawn_dir)
		if not _sim_is_out_of_bounds(spawn_pos) and _sim_get_marble_at(state, spawn_pos) == null:
			followers.append({"pos": spawn_pos, "alive": true})

	# 蓝球自身逐格移动
	var current_pos = pos
	var steps_done = 0

	for step in range(1, power + 1):
		if not marble.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)

		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break

		var target = _sim_get_marble_at(state, next_pos)
		if target != null and target.get("is_alive", false):
			var remaining = power - step
			# 白球特有：被友方碰撞时步数 +1
			if target.get("color") == MarbleConst.MarbleColor.WHITE and target.get("camp") == camp:
				remaining += 1
			if remaining > 0:
				_sim_collision_move(state, target, dir, remaining)
			current_pos = next_pos
			_sim_set_marble_pos(state, marble, current_pos)
			steps_done = step
			break
		else:
			_sim_set_marble_pos(state, marble, next_pos)
			current_pos = next_pos
			steps_done = step

	# 移动随从（与蓝球同方向同剩余步数）
	var follower_safe = marble.get("follower_safe", false)
	var follower_dead = false

	for f in followers:
		if not f.alive:
			continue
		var f_pos = f.pos
		for s in range(steps_done):
			var next_f_pos = _sim_get_neighbor(f_pos, dir)
			if _sim_is_out_of_bounds(next_f_pos):
				if not follower_safe:
					follower_dead = true
				f.alive = false
				break
			var blocker = _sim_get_marble_at(state, next_f_pos)
			if blocker != null and blocker.get("is_alive", false):
				var remaining = steps_done - s
				if remaining > 0:
					_sim_collision_move(state, blocker, dir, remaining)
				f_pos = next_f_pos
				break
			else:
				f_pos = next_f_pos

	if follower_dead and marble.get("is_alive", true):
		marble["is_alive"] = false
		_gmark_dirty(state, marble)

	return _sim_end_turn(state, camp)


# ── 绿球移动（推挤碰撞） ──
func _sim_green_move(state: Dictionary, marble: Dictionary) -> Dictionary:
	var dir = state.get("selected_direction", 0)
	var power = state.get("selected_power", 3)
	var camp = marble.get("camp")
	var push_range = marble.get("push_range", 1)

	# 绿球：推开路径上的棋子，而不是被碰撞挡住
	var current_pos = marble.get("hex_coord", Vector2(0, 0))

	for step in range(1, power + 1):
		if not marble.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)

		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break

		var target = _sim_get_marble_at(state, next_pos)
		if target != null and target.get("is_alive", false):
			# 推挤：被撞弹珠沿相同方向移动 push_range 格
			_sim_collision_move(state, target, dir, push_range)
			# 如果目标被推走后格子空了，绿球移入
			if _sim_get_marble_at(state, next_pos) == null:
				_sim_set_marble_pos(state, marble, next_pos)
				current_pos = next_pos
			else:
				# 目标未被推开，绿球停下
				break
		else:
			_sim_set_marble_pos(state, marble, next_pos)
			current_pos = next_pos

	# 绿球停止后推挤相邻所有格（同时结算）
	if marble.get("is_alive", true):
		for p_dir in range(6):
			var neighbor_pos = _sim_get_neighbor(current_pos, p_dir)
			var neighbor = _sim_get_marble_at(state, neighbor_pos)
			if neighbor != null and neighbor.get("is_alive", false):
				_sim_collision_move(state, neighbor, p_dir, 1)

	return _sim_end_turn(state, camp)


# ── 黄球移动（步数随机 ±1） ──
func _sim_yellow_move(state: Dictionary, marble: Dictionary) -> Dictionary:
	var dir = state.get("selected_direction", 0)
	var power = state.get("selected_power", 3)
	# 步数随机 ±1（范围 1~5）
	var actual_power = clamp(power + randi() % 3 - 1, 1, 5)
	state["selected_power"] = actual_power
	return _sim_basic_move(state, marble)


# ── 基础移动（通用逐格+碰撞） ──
func _sim_basic_move(state: Dictionary, marble: Dictionary) -> Dictionary:
	var dir = state.get("selected_direction", 0)
	var power = state.get("selected_power", 3)
	var camp = marble.get("camp")
	var pos = marble.get("hex_coord", Vector2(0, 0))
	var current_pos = pos

	for step in range(1, power + 1):
		if not marble.get("is_alive", true):
			break
		var next_pos = _sim_get_neighbor(current_pos, dir)

		if _sim_is_out_of_bounds(next_pos):
			marble["is_alive"] = false
			_gmark_dirty(state, marble)
			break

		var target = _sim_get_marble_at(state, next_pos)
		if target != null and target.get("is_alive", false):
			var remaining = power - step
			if remaining > 0:
				_sim_collision_move(state, target, dir, remaining)
			current_pos = next_pos
			_sim_set_marble_pos(state, marble, current_pos)
			break
		else:
			_sim_set_marble_pos(state, marble, next_pos)
			current_pos = next_pos

	return _sim_end_turn(state, camp)


# ── 回合结束处理（胜利检测+切换回合） ──
func _sim_end_turn(state: Dictionary, camp: int) -> Dictionary:
	_sim_check_victory(state)

	if state.get("winner", -1) != -1:
		state["state"] = "victory"
		return state

	# 切换回合前触发后效事件
	_sim_post_action_events(state)

	# 再次检查胜利（后效事件可能导致新死亡）
	_sim_check_victory(state)
	if state.get("winner", -1) != -1:
		state["state"] = "victory"
		return state

	state["state"] = "idle"
	state["current_team"] = MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	state["turn_number"] = state.get("turn_number", 0) + 1
	return state


# ── 后效事件处理（白球变色、黄球增益） ──
func _sim_post_action_events(state: Dictionary) -> void:
	# 收集本回合死亡事件
	var dead_marbles = []
	for m in state.get("marbles", []):
		if not m.get("is_alive", true):
			dead_marbles.append(m)
	
	var any_dead = false
	for m in dead_marbles:
		if m.get("is_alive", false):
			continue
		var dead_camp = m.get("camp")
		var dead_color = m.get("color")
		
		# 黄球死亡：对随机友方目标施加增益
		if dead_color == MarbleConst.MarbleColor.YELLOW:
			any_dead = true
			# 找随机存活友方蓝/绿/红/黑球
			var eligible = []
			for ally in state.get("marbles", []):
				if ally.get("is_alive", false) and ally.get("camp") == dead_camp:
					var ac = ally.get("color")
					if ac in [MarbleConst.MarbleColor.BLUE, MarbleConst.MarbleColor.GREEN, MarbleConst.MarbleColor.RED, MarbleConst.MarbleColor.BLACK]:
						eligible.append(ally)
			if eligible.size() > 0:
				var target = eligible[randi() % eligible.size()]
				var tc = target.get("color")
				match tc:
					MarbleConst.MarbleColor.BLUE:
						target["follower_safe"] = true
					MarbleConst.MarbleColor.GREEN:
						target["push_range"] = target.get("push_range", 1) + 1
					MarbleConst.MarbleColor.RED:
						target["max_steps"] = target.get("max_steps", 4) + 1
					MarbleConst.MarbleColor.BLACK:
						target["enhanced"] = true
		
		# 白球：友方任意颜色弹珠死亡 → 变色
		var white_marbles = []
		for ally in state.get("marbles", []):
			if ally.get("is_alive", false) and ally.get("camp") == dead_camp and ally.get("color") == MarbleConst.MarbleColor.WHITE:
				white_marbles.append(ally)
		
		for wm in white_marbles:
			if dead_color != MarbleConst.MarbleColor.YELLOW:
				wm["color"] = dead_color
				wm["has_changed"] = true
				any_dead = true


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
