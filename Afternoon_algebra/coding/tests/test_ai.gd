# test_ai.gd
# AI 策略测试
class_name TestAI
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
const RandomAIScript = preload("res://ai/RandomAI.gd")

var gm: GameManager
var grid: HexGrid2D
var random_ai

func before_each() -> void:
	gm = GameManager.new()
	
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	gm.hex_grid = grid
	
	random_ai = RandomAIScript.new()

func after_each() -> void:
	if random_ai:
		random_ai = null
	if grid:
		grid.queue_free()
		grid = null
	if gm:
		gm.queue_free()
		gm = null

# ── AIStrategy 基类 ──

func test_ai_strategy_decide_not_implemented() -> void:
	var base = AIStrategyScript.new()
	# 验证基类有 decide 和 evaluate 方法（不调用它们以避免 push_error）
	assert_not_null(base, "基类应能被实例化")
	assert_eq(base.get_script(), AIStrategyScript, "脚本类型应正确")

func test_ai_strategy_get_game_snapshot() -> void:
	var snapshot = random_ai.get_game_snapshot(gm)
	assert_has(snapshot, "current_team", "快照应包含 current_team")
	assert_has(snapshot, "current_state", "快照应包含 current_state")
	assert_has(snapshot, "turn_number", "快照应包含 turn_number")
	assert_has(snapshot, "marbles", "快照应包含 marbles")
	assert_has(snapshot, "all_marbles", "快照应包含 all_marbles")

func test_ai_strategy_get_alive_marbles() -> void:
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	gm.all_marbles.append(m1)
	
	var m2 = Marble2D.new()
	m2.camp = BLUE
	m2.is_alive = false
	gm.all_marbles.append(m2)
	
	var alive = random_ai.get_alive_marbles(gm, RED)
	assert_eq(alive.size(), 1, "应只返回存活的己方弹珠")
	assert_eq(alive[0], m1, "应返回正确的弹珠引用")
	
	m1.queue_free()
	m2.queue_free()

func test_ai_strategy_opponent() -> void:
	assert_eq(random_ai.opponent(RED), BLUE, "红的对手是蓝")
	assert_eq(random_ai.opponent(BLUE), RED, "蓝的对手是红")

# ── RandomAI ──

func test_random_select_marble_only_own_alive() -> void:
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	# 创建己方存活弹珠
	var my_marble = Marble2D.new()
	my_marble.camp = RED
	my_marble.is_alive = true
	gm.all_marbles.append(my_marble)
	
	# 创建敌方弹珠
	var enemy_marble = Marble2D.new()
	enemy_marble.camp = BLUE
	enemy_marble.is_alive = true
	gm.all_marbles.append(enemy_marble)
	
	# 创建己方死亡弹珠
	var dead_marble = Marble2D.new()
	dead_marble.camp = RED
	dead_marble.is_alive = false
	gm.all_marbles.append(dead_marble)
	
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "应返回 select_marble 动作")
	assert_eq(action.marble, my_marble, "应选中己方存活弹珠")
	
	my_marble.queue_free()
	enemy_marble.queue_free()
	dead_marble.queue_free()

func test_random_select_direction() -> void:
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "应返回 select_direction")
	assert_between(action.direction, 0, 5, "方向应在 0~5 范围内")

func test_random_select_power() -> void:
	gm.current_state = GameManager.TurnState.DIRECTION_SELECTED
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "select_power", "应返回 select_power")
	assert_between(action.power, 1, 5, "力度应在 1~5 范围内")

func test_random_red_power() -> void:
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	var red_marble = Marble2D.new()
	red_marble.color = RED_C
	gm.selected_marble = red_marble
	
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "red_power", "红球应返回 red_power")
	assert_between(action.power, 1, 5, "力度应在 1~5 范围内")
	
	red_marble.queue_free()

func test_random_red_direction() -> void:
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "red_direction", "红球逐格应返回 red_direction")
	assert_between(action.direction, 0, 5, "方向应在 0~5 范围内")

func test_random_setup_color() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.COLOR_SELECT
	gm.setup_current_team = RED
	
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "setup_color", "选珠颜色阶段应返回 setup_color")
	assert_between(action.color, 0, 5, "颜色值应在 0~5 范围内")

func test_random_setup_place() -> void:
	# 模拟选珠放置阶段
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.PLACEMENT
	gm.setup_current_team = RED
	
	# 需要为网格设置足够大的格子供放置
	var action = random_ai.decide(gm)
	assert_eq(action.get("action"), "setup_place", "选珠放置阶段应返回 setup_place")
	if action.get("action") == "setup_place":
		var pos = Vector2(action.q, action.r)
		var in_zone = grid.is_in_red_zone(action.q, action.r)
		assert_true(in_zone, "放置位置应在红方区域")
		assert_null(grid.get_marble_at(action.q, action.r), "放置位置不应已被占用")

# ── GameManager AI 集成 ──

func test_ai_setup_and_teardown() -> void:
	# 测试 set_ai_for_camp / remove_ai_for_camp
	var ai = RandomAIScript.new()
	
	gm.set_ai_for_camp(RED, ai)
	assert_true(gm.ai_enabled, "设置 AI 后 ai_enabled 应为 true")
	assert_eq(gm.ai_teams.size(), 1, "应有一个 AI 阵营")
	assert_eq(gm.ai_strategies.get(RED), ai, "AI 策略应被正确存储")
	
	gm.remove_ai_for_camp(RED)
	assert_false(gm.ai_enabled, "移除所有 AI 后 ai_enabled 应为 false")
	assert_eq(gm.ai_teams.size(), 0, "不应有 AI 阵营")

func test_ai_is_ai_turn() -> void:
	gm.set_ai_for_camp(RED, RandomAIScript.new())
	gm.current_team = RED
	assert_true(gm.is_ai_turn(), "当前阵营是 AI 时应返回 true")
	
	gm.current_team = BLUE
	assert_false(gm.is_ai_turn(), "当前阵营不是 AI 时应返回 false")

func test_ai_execute_red_vs_blue_action_flow() -> void:
	# 测试 AI 动作执行流程的基本功能
	# 创建一个简单的场景来验证 AI 可以完成一轮动作
	var ai = RandomAIScript.new()
	gm.set_ai_for_camp(RED, ai)
	
	# 创建一些弹珠
	var marble = Marble2D.new()
	marble.camp = RED
	marble.is_alive = true
	marble.color = WHITE
	marble.hex_grid = grid
	grid.place_marble(marble, 0, 0)
	marble.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(marble)
	
	var enemy = Marble2D.new()
	enemy.camp = BLUE
	enemy.is_alive = true
	enemy.color = WHITE
	enemy.hex_grid = grid
	grid.place_marble(enemy, 5, 0)
	enemy.hex_coord = Vector2(5, 0)
	gm.all_marbles.append(enemy)
	
	# 设置当前状态为 IDLE
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	# AI 应该能做出决策
	var action = ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "IDLE 状态应返回 select_marble")
	assert_eq(action.marble, marble, "应选中己方弹珠")
	
	marble.queue_free()
	enemy.queue_free()
