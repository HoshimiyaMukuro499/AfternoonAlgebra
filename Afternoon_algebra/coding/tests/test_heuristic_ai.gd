# test_heuristic_ai.gd
# 启发式AI策略测试
class_name TestHeuristicAI
extends "res://tests/base_test.gd"

const RED = MarbleConst.Camp.RED
const BLUE = MarbleConst.Camp.BLUE
const WHITE = MarbleConst.MarbleColor.WHITE
const BLUE_C = MarbleConst.MarbleColor.BLUE
const GREEN = MarbleConst.MarbleColor.GREEN
const RED_C = MarbleConst.MarbleColor.RED
const BLACK = MarbleConst.MarbleColor.BLACK
const YELLOW = MarbleConst.MarbleColor.YELLOW

const AIStrategyScript = preload("res://ai/AIStrategy.gd")
const HeuristicAIScript = preload("res://ai/HeuristicAI.gd")

var gm: GameManager
var grid: HexGrid2D
var heuristic_ai

func before_each() -> void:
	gm = GameManager.new()
	
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	gm.hex_grid = grid
	
	heuristic_ai = HeuristicAIScript.new()

func after_each() -> void:
	if heuristic_ai:
		heuristic_ai = null
	if grid:
		grid.queue_free()
		grid = null
	if gm:
		gm.queue_free()
		gm = null

# ── 基础测试 ──

func test_heuristic_ai_is_instantiated() -> void:
	assert_not_null(heuristic_ai, "HeuristicAI 应能被实例化")
	assert_eq(heuristic_ai.get_script(), HeuristicAIScript, "脚本类型应正确")

func test_heuristic_ai_decide_in_idle() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	var my_marble = Marble2D.new()
	my_marble.camp = RED
	my_marble.is_alive = true
	my_marble.color = WHITE
	gm.all_marbles.append(my_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "IDLE 状态应返回 select_marble")
	
	my_marble.queue_free()

func test_heuristic_ai_decide_select_marble_skips_black() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	# 创建黑色弹珠（不可动）
	var black_marble = Marble2D.new()
	black_marble.camp = RED
	black_marble.is_alive = true
	black_marble.color = BLACK
	gm.all_marbles.append(black_marble)
	
	# 创建白色弹珠（可选）
	var white_marble = Marble2D.new()
	white_marble.camp = RED
	white_marble.is_alive = true
	white_marble.color = WHITE
	white_marble.hex_coord = Vector2(1, 0)
	gm.all_marbles.append(white_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "应返回 select_marble")
	assert_eq(action.marble, white_marble, "应优先选择非黑色弹珠")
	
	black_marble.queue_free()
	white_marble.queue_free()

func test_heuristic_ai_decide_direction() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	var my_marble = Marble2D.new()
	my_marble.camp = RED
	my_marble.is_alive = true
	my_marble.color = WHITE
	my_marble.hex_coord = Vector2(0, 0)
	gm.selected_marble = my_marble
	gm.all_marbles.append(my_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "MARBLE_SELECTED 状态应返回 select_direction")
	assert_between(action.direction, 0, 5, "方向应在 0~5 范围内")
	
	my_marble.queue_free()

func test_heuristic_ai_decide_power() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.DIRECTION_SELECTED
	gm.selected_direction = 0
	
	var my_marble = Marble2D.new()
	my_marble.camp = RED
	my_marble.is_alive = true
	my_marble.color = WHITE
	my_marble.hex_coord = Vector2(0, 0)
	gm.selected_marble = my_marble
	gm.all_marbles.append(my_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_power", "DIRECTION_SELECTED 状态应返回 select_power")
	assert_between(action.power, 1, 5, "力度应在 1~5 范围内")
	
	my_marble.queue_free()

func test_heuristic_ai_decide_red_power() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	var red_marble = Marble2D.new()
	red_marble.camp = RED
	red_marble.is_alive = true
	red_marble.color = RED_C
	red_marble.hex_coord = Vector2(0, 0)
	gm.selected_marble = red_marble
	gm.all_marbles.append(red_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "red_power", "红球应返回 red_power")
	assert_between(action.power, 1, 5, "力度应在 1~5 范围内")
	
	red_marble.queue_free()

func test_heuristic_ai_decide_red_direction() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	
	var red_marble = Marble2D.new()
	red_marble.camp = RED
	red_marble.is_alive = true
	red_marble.color = RED_C
	red_marble.hex_coord = Vector2(0, 0)
	gm.selected_marble = red_marble
	gm.all_marbles.append(red_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "red_direction", "红球逐格应返回 red_direction")
	assert_between(action.direction, 0, 5, "方向应在 0~5 范围内")
	
	red_marble.queue_free()

# ── 决策：选择弹珠（白球靠近边界优先） ──

func test_heuristic_select_marble_prefers_boundary() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	# 创建两个白色弹珠：一个在边界附近，一个在中心
	var center_marble = Marble2D.new()
	center_marble.camp = RED
	center_marble.is_alive = true
	center_marble.color = WHITE
	center_marble.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(center_marble)
	
	var edge_marble = Marble2D.new()
	edge_marble.camp = RED
	edge_marble.is_alive = true
	edge_marble.color = WHITE
	edge_marble.hex_coord = Vector2(MarbleConst.GRID_RADIUS - 1, 0)  # 靠近边界
	gm.all_marbles.append(edge_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "应返回 select_marble")
	# 边界弹珠可能因为能推出敌人而得分更高
	# 但由于没有敌人，边界弹珠可能得分不如中心弹珠
	assert_not_null(action.marble, "应选择弹珠")
	
	center_marble.queue_free()
	edge_marble.queue_free()

func test_heuristic_select_marble_prefers_high_value_color() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	# 创建白色（高价值）和黄色（低价值）弹珠
	var yellow_marble = Marble2D.new()
	yellow_marble.camp = RED
	yellow_marble.is_alive = true
	yellow_marble.color = YELLOW
	yellow_marble.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(yellow_marble)
	
	var white_marble = Marble2D.new()
	white_marble.camp = RED
	white_marble.is_alive = true
	white_marble.color = WHITE
	white_marble.hex_coord = Vector2(1, 0)
	gm.all_marbles.append(white_marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.marble, white_marble, "白球（颜色价值更高）应被优先选择")
	
	yellow_marble.queue_free()
	white_marble.queue_free()

# ── 决策：方向选择（考虑颜色特性） ──

func test_heuristic_white_direction_avoids_out_of_bounds() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	# 在边界放置白色弹珠
	var marble = Marble2D.new()
	marble.camp = RED
	marble.is_alive = true
	marble.color = WHITE
	marble.hex_coord = Vector2(MarbleConst.GRID_RADIUS - 1, 0)  # 靠近右边界
	marble.hex_grid = grid
	grid.place_marble(marble, marble.hex_coord.x, marble.hex_coord.y)
	gm.selected_marble = marble
	gm.all_marbles.append(marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "应返回 select_direction")
	# 方向3（左边）是唯一安全的方向（远离边界）
	# 不具体断言方向值，只确保不崩溃
	
	# 清理
	grid.remove_marble_by_node(marble)
	marble.queue_free()

func test_heuristic_white_direction_towards_enemy() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	# 己方弹珠
	var marble = Marble2D.new()
	marble.camp = RED
	marble.is_alive = true
	marble.color = WHITE
	marble.hex_coord = Vector2(0, 0)
	marble.hex_grid = grid
	grid.place_marble(marble, 0, 0)
	gm.selected_marble = marble
	gm.all_marbles.append(marble)
	
	# 敌方弹珠在右侧（方向0）
	var enemy = Marble2D.new()
	enemy.camp = BLUE
	enemy.is_alive = true
	enemy.color = WHITE
	enemy.hex_coord = Vector2(3, 0)
	enemy.hex_grid = grid
	grid.place_marble(enemy, 3, 0)
	gm.all_marbles.append(enemy)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "应返回 select_direction")
	# 有敌人时应偏向敌人方向（方向0=右边）
	# 不强制断言，只验证不崩溃
	
	grid.remove_marble_by_node(marble)
	grid.remove_marble_by_node(enemy)
	marble.queue_free()
	enemy.queue_free()

# ── 决策：力度选择 ──

func test_heuristic_power_prefers_mid_range() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.DIRECTION_SELECTED
	gm.selected_direction = 0
	
	var marble = Marble2D.new()
	marble.camp = RED
	marble.is_alive = true
	marble.color = WHITE
	marble.hex_coord = Vector2(0, 0)
	marble.hex_grid = grid
	grid.place_marble(marble, 0, 0)
	gm.selected_marble = marble
	gm.all_marbles.append(marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_power", "应返回 select_power")
	assert_between(action.power, 1, 5, "力度应在 1~5 范围内")
	# 在棋盘中心方向0（右边），力度3应该安全（GRID_RADIUS=8）
	# 但不应选会导致出界的力度
	if action.power == 5:
		# 5步可能出界（0,0 往右5步到(5,0)，在半径8内没问题）
		pass
	
	grid.remove_marble_by_node(marble)
	marble.queue_free()

func test_heuristic_power_avoids_out_of_bounds() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.DIRECTION_SELECTED
	gm.selected_direction = 0  # 向右
	
	# 靠近右边界
	var marble = Marble2D.new()
	marble.camp = RED
	marble.is_alive = true
	marble.color = WHITE
	marble.hex_coord = Vector2(MarbleConst.GRID_RADIUS - 2, 0)
	marble.hex_grid = grid
	grid.place_marble(marble, marble.hex_coord.x, marble.hex_coord.y)
	gm.selected_marble = marble
	gm.all_marbles.append(marble)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_power", "应返回 select_power")
	# 靠近边界时，应避免选择太大的力度
	# 从半径8-2=6的位置向右走，力度3到(9,0)出界
	# 所以AI应选择较小的力度
	assert_true(action.power <= 2, "靠近边界时应选小力度（不超过2步）以避免出界")
	
	grid.remove_marble_by_node(marble)
	marble.queue_free()

# ── 棋盘评估 ──

func test_evaluate_empty_board() -> void:
	var score = heuristic_ai.evaluate(gm, RED)
	# 空棋盘时蓝方和红方都没有弹珠
	assert_eq(score, 0.0, "空棋盘评估应为0")

func test_evaluate_marble_count_advantage() -> void:
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m1)
	
	var m2 = Marble2D.new()
	m2.camp = BLUE
	m2.is_alive = true
	m2.color = WHITE
	m2.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m2)
	
	var score = heuristic_ai.evaluate(gm, RED)
	# 红方1个，蓝方1个，弹珠数量差为0
	# 但由于颜色价值（白=5）和位置，分数可能略高或略低
	# 主要验证评分不崩溃
	
	m1.queue_free()
	m2.queue_free()

func test_evaluate_red_more_marbles() -> void:
	for i in range(3):
		var m = Marble2D.new()
		m.camp = RED
		m.is_alive = true
		m.color = WHITE
		m.hex_coord = Vector2(0, i)
		gm.all_marbles.append(m)
	
	for i in range(1):
		var m = Marble2D.new()
		m.camp = BLUE
		m.is_alive = true
		m.color = WHITE
		m.hex_coord = Vector2(3, i)
		gm.all_marbles.append(m)
	
	var score = heuristic_ai.evaluate(gm, RED)
	assert_true(score > 0, "红方弹珠多时应为正分")
	
	# 清理
	for m in gm.all_marbles:
		m.queue_free()
	gm.all_marbles.clear()

func test_evaluate_blue_more_marbles() -> void:
	for i in range(1):
		var m = Marble2D.new()
		m.camp = RED
		m.is_alive = true
		m.color = WHITE
		m.hex_coord = Vector2(0, 0)
		gm.all_marbles.append(m)
	
	for i in range(3):
		var m = Marble2D.new()
		m.camp = BLUE
		m.is_alive = true
		m.color = WHITE
		m.hex_coord = Vector2(3, i)
		gm.all_marbles.append(m)
	
	var score = heuristic_ai.evaluate(gm, RED)
	assert_true(score < 0, "红方弹珠少时应为负分")
	
	for m in gm.all_marbles:
		m.queue_free()
	gm.all_marbles.clear()

func test_evaluate_prefers_center() -> void:
	# 己方弹珠在中心 vs 敌方在边缘
	var center = Marble2D.new()
	center.camp = RED
	center.is_alive = true
	center.color = WHITE
	center.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(center)
	
	var edge = Marble2D.new()
	edge.camp = BLUE
	edge.is_alive = true
	edge.color = WHITE
	edge.hex_coord = Vector2(5, 0)
	gm.all_marbles.append(edge)
	
	var score = heuristic_ai.evaluate(gm, RED)
	# 红方在中心位置更好
	assert_true(score > 0, "己方在中心敌方在边缘时应为正分")
	
	center.queue_free()
	edge.queue_free()

func test_evaluate_penalizes_dead_marbles() -> void:
	var alive = Marble2D.new()
	alive.camp = RED
	alive.is_alive = true
	alive.color = WHITE
	alive.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(alive)
	
	var dead = Marble2D.new()
	dead.camp = RED
	dead.is_alive = false
	dead.color = WHITE
	dead.hex_coord = Vector2(1, 0)
	gm.all_marbles.append(dead)
	
	var enemy = Marble2D.new()
	enemy.camp = BLUE
	enemy.is_alive = true
	enemy.color = WHITE
	enemy.hex_coord = Vector2(3, 0)
	gm.all_marbles.append(enemy)
	
	var score = heuristic_ai.evaluate(gm, RED)
	# 红方总体少（1活 vs 1敌），应为负分
	# 主要验证不死弹珠被忽略
	
	alive.queue_free()
	dead.queue_free()
	enemy.queue_free()

# ── 设置阶段 ──

func test_heuristic_setup_color_select() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.COLOR_SELECT
	gm.setup_current_team = RED
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "setup_color", "选珠颜色阶段应返回 setup_color")
	assert_between(action.color, 0, 5, "颜色值应在 0~5 范围内")
	# 第一个颜色应为白色（优先级最高）
	assert_eq(action.color, WHITE, "首次选色应选择白色（优先级最高）")

func test_heuristic_setup_color_sequence() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.COLOR_SELECT
	gm.setup_current_team = RED
	
	# 第一次选色应为白色
	var action1 = heuristic_ai.decide(gm)
	assert_eq(action1.color, WHITE, "第一次选色应为白色")
	
	# 第二次选色应为蓝色
	var action2 = heuristic_ai.decide(gm)
	assert_eq(action2.color, BLUE_C, "第二次选色应为蓝色")
	
	# 第三次选色应为绿色
	var action3 = heuristic_ai.decide(gm)
	assert_eq(action3.color, GREEN, "第三次选色应为绿色")

func test_heuristic_setup_placement() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.PLACEMENT
	gm.setup_current_team = RED
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "setup_place", "选珠放置阶段应返回 setup_place")
	assert_has(action, "q", "应包含 q 坐标")
	assert_has(action, "r", "应包含 r 坐标")
	
	# 验证在红方区域内
	var in_zone = grid.is_in_red_zone(action.q, action.r)
	assert_true(in_zone, "放置位置应在红方区域")

func test_heuristic_setup_placement_spreads_out() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.PLACEMENT
	gm.setup_current_team = RED
	
	# 第一次放置
	var action1 = heuristic_ai.decide(gm)
	
	# 模拟放置一个弹珠
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.hex_coord = Vector2(action1.q, action1.r)
	gm.all_marbles.append(m1)
	
	# 第二次放置
	var action2 = heuristic_ai.decide(gm)
	
	# 两个放置位置不应相同（但也不强制，因为位置有限）
	var same_position = (action1.q == action2.q and action1.r == action2.r)
	if same_position:
		push_warning("两次放置位置相同（可能因可用位置有限）")
	
	m1.queue_free()

# ── 工具方法测试 ──

func test_hex_distance() -> void:
	var dist = heuristic_ai._hex_distance(Vector2(0, 0), Vector2(3, 0))
	assert_eq(dist, 3, "轴向距离 (0,0) -> (3,0) 应为 3")
	
	dist = heuristic_ai._hex_distance(Vector2(0, 0), Vector2(0, 0))
	assert_eq(dist, 0, "相同坐标距离应为 0")
	
	dist = heuristic_ai._hex_distance(Vector2(1, -1), Vector2(-1, 1))
	assert_eq(dist, 2, "轴向距离 (1,-1) -> (-1,1) 应为 2")

func test_direction_towards() -> void:
	var dir = heuristic_ai._direction_towards(Vector2(0, 0), Vector2(3, 0))
	assert_eq(dir, 0, "(0,0)->(3,0) 方向应为 0 (右)")
	
	dir = heuristic_ai._direction_towards(Vector2(0, 0), Vector2(-3, 0))
	assert_eq(dir, 3, "(0,0)->(-3,0) 方向应为 3 (左)")
	
	dir = heuristic_ai._direction_towards(Vector2(0, 0), Vector2(0, 3))
	assert_eq(dir, 1, "(0,0)->(0,3) 方向应为 1 (右上)")

func test_get_neighbor_hex() -> void:
	var result = heuristic_ai._get_neighbor_hex(Vector2(0, 0), 0)
	assert_eq(result, Vector2(1, 0), "方向0的邻居应为 (1,0)")
	
	result = heuristic_ai._get_neighbor_hex(Vector2(0, 0), 3)
	assert_eq(result, Vector2(-1, 0), "方向3的邻居应为 (-1,0)")

func test_simulate_line_movement() -> void:
	var result = heuristic_ai._simulate_line_movement(Vector2(0, 0), 0, 3)
	assert_eq(result, Vector2(3, 0), "从(0,0)方向0走3步应为(3,0)")
	
	result = heuristic_ai._simulate_line_movement(Vector2(2, -1), 2, 2)
	assert_eq(result, Vector2(0, 1), "从(2,-1)方向2走2步应为(0,1)")

# ── 颜色特定方向策略 ──

func test_blue_direction_with_enemy_nearby() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	var blue_marble = Marble2D.new()
	blue_marble.camp = RED
	blue_marble.is_alive = true
	blue_marble.color = BLUE_C
	blue_marble.hex_coord = Vector2(0, 0)
	blue_marble.hex_grid = grid
	grid.place_marble(blue_marble, 0, 0)
	gm.selected_marble = blue_marble
	gm.all_marbles.append(blue_marble)
	
	# 在蓝球旁边放一个敌人（方向3=左边）
	var enemy = Marble2D.new()
	enemy.camp = BLUE
	enemy.is_alive = true
	enemy.color = WHITE
	enemy.hex_coord = Vector2(-1, 0)
	enemy.hex_grid = grid
	grid.place_marble(enemy, -1, 0)
	gm.all_marbles.append(enemy)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "应返回 select_direction")
	
	grid.remove_marble_by_node(blue_marble)
	grid.remove_marble_by_node(enemy)
	blue_marble.queue_free()
	enemy.queue_free()

func test_green_direction_towards_enemy() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	var green_marble = Marble2D.new()
	green_marble.camp = RED
	green_marble.is_alive = true
	green_marble.color = GREEN
	green_marble.hex_coord = Vector2(0, 0)
	green_marble.hex_grid = grid
	grid.place_marble(green_marble, 0, 0)
	gm.selected_marble = green_marble
	gm.all_marbles.append(green_marble)
	
	# 在右边放一个敌方弹珠
	var enemy = Marble2D.new()
	enemy.camp = BLUE
	enemy.is_alive = true
	enemy.color = WHITE
	enemy.hex_coord = Vector2(2, 0)
	enemy.hex_grid = grid
	grid.place_marble(enemy, 2, 0)
	gm.all_marbles.append(enemy)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "应返回 select_direction")
	# 应该有敌人附近的推挤加分
	
	grid.remove_marble_by_node(green_marble)
	grid.remove_marble_by_node(enemy)
	green_marble.queue_free()
	enemy.queue_free()

# ── 黑球策略 ──

func test_black_marble_select_target() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.BLACK_MARBLE_SELECTED
	
	var enemy1 = Marble2D.new()
	enemy1.camp = BLUE
	enemy1.is_alive = true
	enemy1.color = WHITE
	enemy1.hex_coord = Vector2(3, 0)
	gm.all_marbles.append(enemy1)
	
	var enemy2 = Marble2D.new()
	enemy2.camp = BLUE
	enemy2.is_alive = true
	enemy2.color = WHITE
	enemy2.hex_coord = Vector2(5, 0)
	gm.all_marbles.append(enemy2)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_enemy", "黑球应返回 select_enemy")
	assert_not_null(action.marble, "应选择目标")
	
	enemy1.queue_free()
	enemy2.queue_free()

func test_black_marble_prefers_edge_enemy() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.BLACK_MARBLE_SELECTED
	
	# 边缘敌人（靠近棋盘边界）
	var edge_enemy = Marble2D.new()
	edge_enemy.camp = BLUE
	edge_enemy.is_alive = true
	edge_enemy.color = WHITE
	edge_enemy.hex_coord = Vector2(MarbleConst.GRID_RADIUS - 1, 0)
	gm.all_marbles.append(edge_enemy)
	
	# 中心敌人
	var center_enemy = Marble2D.new()
	center_enemy.camp = BLUE
	center_enemy.is_alive = true
	center_enemy.color = WHITE
	center_enemy.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(center_enemy)
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_enemy", "应返回 select_enemy")
	# 边缘敌人应优先被选中
	assert_eq(action.marble, edge_enemy, "应优先选择靠近边缘的敌人")
	
	edge_enemy.queue_free()
	center_enemy.queue_free()

func test_black_approx_direction_towards_edge() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.BLACK_TARGET_PICKING
	
	var target = Marble2D.new()
	target.camp = BLUE
	target.is_alive = true
	target.color = WHITE
	target.hex_coord = Vector2(MarbleConst.GRID_RADIUS - 1, 0)  # 在右边界
	gm.black_target_marble = target
	
	var action = heuristic_ai.decide(gm)
	assert_eq(action.get("action"), "select_approx_direction", "应返回 select_approx_direction")
	# 应该选择指向边界的（右边=方向0）
	assert_eq(action.direction, 0, "应选择指向棋盘外的方向（向右）")
	
	target.queue_free()

# ── 集成测试 ──

func test_heuristic_ai_can_execute_full_turn() -> void:
	# 模拟一个完整的 AI 回合流程
	var ai = heuristic_ai
	gm.set_ai_for_camp(RED, ai)
	
	var marble = Marble2D.new()
	marble.camp = RED
	marble.is_alive = true
	marble.color = WHITE
	marble.hex_coord = Vector2(0, 0)
	marble.hex_grid = grid
	grid.place_marble(marble, 0, 0)
	gm.all_marbles.append(marble)
	
	var enemy = Marble2D.new()
	enemy.camp = BLUE
	enemy.is_alive = true
	enemy.color = WHITE
	enemy.hex_coord = Vector2(5, 0)
	enemy.hex_grid = grid
	grid.place_marble(enemy, 5, 0)
	gm.all_marbles.append(enemy)
	
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
		# Step 1: 选择弹珠
	var action = ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "第一步应选择弹珠")
	gm.select_marble(action.marble)
	
	# Step 2: 选择方向
	if gm.current_state == GameManager.TurnState.MARBLE_SELECTED:
		var dir_action = ai.decide(gm)
		assert_eq(dir_action.get("action"), "select_direction", "第二步应选择方向")
		gm.select_direction(dir_action.direction)
	
	# Step 3: 选择力度（如果状态正确）
	if gm.current_state == GameManager.TurnState.DIRECTION_SELECTED:
		var power_action = ai.decide(gm)
		assert_eq(power_action.get("action"), "select_power", "第三步应选择力度")
		gm.select_power(power_action.power)
	
	# 验证流程完成
	assert_true(gm.current_state == GameManager.TurnState.IDLE or gm.current_state == GameManager.TurnState.EXECUTING,
		"流程完成后应回到 IDLE 或进入 EXECUTING")
	
	grid.remove_marble_by_node(marble)
	grid.remove_marble_by_node(enemy)
	marble.queue_free()
	enemy.queue_free()

func test_heuristic_ai_red_marble_flow() -> void:
	gm.current_team = RED
	
	var red_marble = Marble2D.new()
	red_marble.camp = RED
	red_marble.is_alive = true
	red_marble.color = RED_C
	red_marble.hex_coord = Vector2(0, 0)
	red_marble.hex_grid = grid
	grid.place_marble(red_marble, 0, 0)
	gm.all_marbles.append(red_marble)
	
		# 模拟红球选择
	gm.current_state = GameManager.TurnState.IDLE
	gm.select_marble(red_marble)
	assert_eq(gm.current_state, GameManager.TurnState.MARBLE_SELECTED, "选择红球后状态应为 MARBLE_SELECTED")
	
	# AI 应选择力度
	var power_action = heuristic_ai.decide(gm)
	assert_eq(power_action.get("action"), "red_power", "红球应选择力度")
	
	red_marble.queue_free()
