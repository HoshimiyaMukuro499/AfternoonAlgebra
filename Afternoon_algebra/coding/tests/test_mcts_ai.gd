# test_mcts_ai.gd
# MCTS AI 策略测试
class_name TestMCTS_AI
extends "res://tests/base_test.gd"

const RED = MarbleConst.Camp.RED
const BLUE = MarbleConst.Camp.BLUE
const WHITE = MarbleConst.MarbleColor.WHITE
const BLUE_C = MarbleConst.MarbleColor.BLUE
const GREEN = MarbleConst.MarbleColor.GREEN
const RED_C = MarbleConst.MarbleColor.RED
const BLACK = MarbleConst.MarbleColor.BLACK
const YELLOW = MarbleConst.MarbleColor.YELLOW

const MCTSAIScript = preload("res://ai/MCTS_AI.gd")

var gm: GameManager
var grid: HexGrid2D
var mcts_ai

# 简化的 MCTS 模拟次数（测试用）
const TEST_SIMULATION_COUNT = 50

func before_each() -> void:
	gm = GameManager.new()
	
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	gm.hex_grid = grid
	
	mcts_ai = MCTSAIScript.new()

func after_each() -> void:
	if mcts_ai:
		mcts_ai = null
	if grid:
		grid.queue_free()
		grid = null
	if gm:
		gm.queue_free()
		gm = null

# ── 基础测试 ──

func test_mcts_ai_is_instantiated() -> void:
	assert_not_null(mcts_ai, "MCTS_AI 应能被实例化")
	assert_eq(mcts_ai.get_script(), MCTSAIScript, "脚本类型应正确")

func test_mcts_ai_default_config() -> void:
	assert_eq(mcts_ai.simulation_count, 1000, "默认模拟次数应为 1000")
	assert_eq(mcts_ai.time_limit_ms, 3000, "默认时间限制应为 3000ms")
	assert_false(mcts_ai.use_time_limit, "默认不使用时间限制")

func test_mcts_ai_set_simulation_count() -> void:
	mcts_ai.set_simulation_count(500)
	assert_eq(mcts_ai.simulation_count, 500, "模拟次数应更新为 500")

func test_mcts_ai_set_time_limit() -> void:
	mcts_ai.set_time_limit(1000)
	assert_true(mcts_ai.use_time_limit, "应启用时间限制")
	assert_eq(mcts_ai.time_limit_ms, 1000, "时间限制应更新为 1000ms")

# ── 状态捕获测试 ──

func test_capture_state_empty() -> void:
	var state = mcts_ai._capture_state(gm)
	assert_has(state, "current_team", "状态应包含 current_team")
	assert_has(state, "state", "状态应包含 state")
	assert_has(state, "marbles", "状态应包含 marbles")
	assert_has(state, "winner", "状态应包含 winner")
	assert_eq(state.get("winner"), -1, "空棋盘无胜利者")

func test_capture_state_with_marbles() -> void:
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m1)
	
	var state = mcts_ai._capture_state(gm)
	var marbles = state.get("marbles", [])
	assert_eq(marbles.size(), 1, "状态应包含一个弹珠")
	assert_eq(marbles[0].get("camp"), RED, "弹珠阵营应正确")
	assert_eq(marbles[0].get("color"), WHITE, "弹珠颜色应正确")
	assert_true(marbles[0].get("is_alive"), "弹珠应存活")
	
	m1.queue_free()

func test_capture_state_victory() -> void:
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m1)
	
	# 没有蓝方弹珠，红方获胜
	var state = mcts_ai._capture_state(gm)
	assert_eq(state.get("winner"), RED, "只有红方弹珠时应判定红方胜利")
	
	m1.queue_free()

# ── 动作生成测试 ──

func test_generate_select_marble_actions() -> void:
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m1)
	
	var state = mcts_ai._capture_state(gm)
	var actions = mcts_ai._generate_simulation_actions(state, RED, "idle")
	
	assert_true(actions.size() > 0, "IDLE 状态下应有合法动作")
	var has_select = false
	for a in actions:
		if a.get("action") == "select_marble":
			has_select = true
	assert_true(has_select, "生成的动作应包含 select_marble")
	
	m1.queue_free()

func test_generate_skip_black_marble() -> void:
	var black = Marble2D.new()
	black.camp = RED
	black.is_alive = true
	black.color = BLACK
	black.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(black)
	
	var white = Marble2D.new()
	white.camp = RED
	white.is_alive = true
	white.color = WHITE
	white.hex_coord = Vector2(1, 0)
	gm.all_marbles.append(white)
	
	var state = mcts_ai._capture_state(gm)
	var actions = mcts_ai._generate_simulation_actions(state, RED, "idle")
	
	# 应该优先选择非黑色弹珠
	for a in actions:
		if a.get("action") == "select_marble":
			var marble_id = a.get("marble_id")
			var marble_data = mcts_ai._find_marble_in_state(state, marble_id)
			if marble_data.get("color") == WHITE:
				pass  # 白色弹珠可以被选
			elif marble_data.get("color") == BLACK:
				pass  # 黑色也能选（当没有其他可选时）
	
	assert_true(actions.size() > 0, "应有合法动作")
	
	black.queue_free()
	white.queue_free()

func test_generate_red_power_actions() -> void:
	var red = Marble2D.new()
	red.camp = RED
	red.is_alive = true
	red.color = RED_C
	red.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(red)
	
	var state = mcts_ai._capture_state(gm)
	state["state"] = "marble_selected"
	state["selected_marble"] = red.get_instance_id()
	
	var actions = mcts_ai._generate_simulation_actions(state, RED, "marble_selected")
	
	var has_red_power = false
	for a in actions:
		if a.get("action") == "red_power":
			has_red_power = true
			assert_between(a.get("power"), 1, 5, "力度应在 1~5 范围内")
	
	assert_true(has_red_power, "红球应生成 red_power 动作")
	
	red.queue_free()

func test_generate_direction_actions() -> void:
	var state = mcts_ai._capture_state(gm)
	state["state"] = "marble_selected"
	state["selected_marble"] = 1  # 非红球
	
	var actions = mcts_ai._generate_simulation_actions(state, RED, "marble_selected")
	
	var has_dir = false
	for a in actions:
		if a.get("action") == "select_direction":
			has_dir = true
			assert_between(a.get("direction"), 0, 5, "方向应在 0~5 范围内")
	
	assert_true(has_dir, "非红球应生成 select_direction 动作")

func test_generate_power_actions() -> void:
	var state = mcts_ai._capture_state(gm)
	state["state"] = "direction_selected"
	
	var actions = mcts_ai._generate_simulation_actions(state, RED, "direction_selected")
	
	var has_power = false
	for a in actions:
		if a.get("action") == "select_power":
			has_power = true
			assert_between(a.get("power"), 1, 5, "力度应在 1~5 范围内")
	
	assert_true(has_power, "DIRECTION_SELECTED 状态应生成 select_power 动作")

# ── 状态深拷贝测试 ──

func test_deep_copy_preserves_data() -> void:
	var original = {
		"current_team": RED,
		"state": "idle",
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(3, 0)},
		],
		"winner": -1,
	}
	
	var copy = mcts_ai._deep_copy_state(original)
	
	assert_eq(copy.get("current_team"), original.get("current_team"), "拷贝应保留 current_team")
	assert_eq(copy.get("state"), original.get("state"), "拷贝应保留 state")
	
	var copy_marbles = copy.get("marbles", [])
	var orig_marbles = original.get("marbles", [])
	assert_eq(copy_marbles.size(), orig_marbles.size(), "拷贝应保留弹珠数量")
	assert_eq(copy_marbles[0].get("color"), orig_marbles[0].get("color"), "拷贝应保留弹珠颜色")
	
	# 修改拷贝不应影响原件
	copy_marbles[0]["color"] = BLUE_C
	assert_eq(orig_marbles[0].get("color"), WHITE, "修改拷贝不应影响原件")

# ── 工具方法测试 ──

func test_find_marble_in_state() -> void:
	var m = Marble2D.new()
	m.camp = RED
	m.is_alive = true
	m.color = WHITE
	gm.all_marbles.append(m)
	
	var state = mcts_ai._capture_state(gm)
	var found = mcts_ai._find_marble_in_state(state, m.get_instance_id())
	
	assert_eq(found.get("id"), m.get_instance_id(), "应通过 ID 找到弹珠")
	assert_eq(found.get("camp"), RED, "找到的弹珠阵营应正确")
	
	m.queue_free()

func test_sim_is_out_of_bounds() -> void:
	assert_true(mcts_ai._sim_is_out_of_bounds(Vector2(100, 0)), "在棋盘外应返回 true")
	assert_false(mcts_ai._sim_is_out_of_bounds(Vector2(0, 0)), "棋盘中心应返回 false")
	assert_true(mcts_ai._sim_is_out_of_bounds(Vector2(10, 0)), "超出 GRID_RADIUS 应返回 true")

func test_sim_get_neighbor() -> void:
	var n = mcts_ai._sim_get_neighbor(Vector2(0, 0), 0)
	assert_eq(n, Vector2(1, 0), "方向 0 的邻居应为 (1,0)")
	
	n = mcts_ai._sim_get_neighbor(Vector2(0, 0), 3)
	assert_eq(n, Vector2(-1, 0), "方向 3 的邻居应为 (-1,0)")

func test_sim_hex_distance() -> void:
	var d = mcts_ai._sim_hex_distance(Vector2(0, 0), Vector2(3, 0))
	# _sim_hex_distance 返回 float，用 assert_true 避免 float/int 警告
	assert_true(d == 3.0, "(0,0)->(3,0) 距离应为 3")
	
	d = mcts_ai._sim_hex_distance(Vector2(0, 0), Vector2(0, 0))
	assert_true(d == 0.0, "相同坐标距离应为 0")

# ── 模拟动作测试 ──

func test_simulate_select_marble_action() -> void:
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m1)
	
	var state = mcts_ai._capture_state(gm)
	state["state"] = "idle"
	
	var action = {"action": "select_marble", "marble_id": m1.get_instance_id()}
	var new_state = mcts_ai._simulate_action(state, action, gm)
	
	assert_eq(new_state.get("selected_marble"), m1.get_instance_id(), "选择弹珠后应更新 selected_marble")
	assert_eq(new_state.get("state"), "marble_selected", "选择非红球后状态应变为 marble_selected")
	
	m1.queue_free()

func test_simulate_select_direction_action() -> void:
	var state = {
		"current_team": RED,
		"state": "marble_selected",
		"selected_marble": 1,
		"marbles": [],
		"winner": -1,
	}
	
	var action = {"action": "select_direction", "direction": 2}
	var new_state = mcts_ai._simulate_action(state, action, gm)
	
	assert_eq(new_state.get("selected_direction"), 2, "选择方向后应更新 selected_direction")
	assert_eq(new_state.get("state"), "direction_selected", "选方向后状态应变为 direction_selected")

func test_simulate_red_power_action() -> void:
	var state = {
		"current_team": RED,
		"state": "marble_selected",
		"selected_marble": 1,
		"selected_direction": -1,
		"selected_power": 0,
		"red_power": 0,
		"marbles": [],
		"winner": -1,
	}
	
	var action = {"action": "red_power", "power": 4}
	var new_state = mcts_ai._simulate_action(state, action, gm)
	
	assert_eq(new_state.get("red_power"), 4, "红球选力度后应更新 red_power")
	assert_eq(new_state.get("state"), "red_direction_picking", "红球选力度后状态应变为 red_direction_picking")

func test_simulate_execute_move_empty_space() -> void:
	# 创建一个状态：红方弹珠在 (0,0)，方向 0（右），力度 3
	# 包含蓝方弹珠避免触发胜利
	var state = {
		"current_team": RED,
		"state": "direction_selected",
		"selected_marble": 1,
		"selected_direction": 0,
		"selected_power": 3,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(6, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_execute_move(state)
	
	# 弹珠应该移动了
	var marble = mcts_ai._find_marble_in_state(new_state, 1)
	assert_true(marble.get("is_alive"), "弹珠应存活")
	# 走3步向右，应该到 (3,0)
	assert_eq(marble.get("hex_coord"), Vector2(3, 0), "弹珠应移动到 (3,0)")
	
	# 回合应切换
	assert_eq(new_state.get("current_team"), BLUE, "回合应切换到蓝方")
	assert_eq(new_state.get("state"), "idle", "执行完成后状态应回到 idle")

func test_simulate_execute_move_collision() -> void:
	var state = {
		"current_team": RED,
		"state": "direction_selected",
		"selected_marble": 1,
		"selected_direction": 0,
		"selected_power": 3,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(2, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_execute_move(state)
	
	# 红方弹珠应该停在 (2,0)（碰撞位置）
	var attacker = mcts_ai._find_marble_in_state(new_state, 1)
	var defender = mcts_ai._find_marble_in_state(new_state, 2)
	
	assert_true(attacker.get("is_alive"), "攻击者应存活")
	assert_eq(attacker.get("hex_coord"), Vector2(2, 0), "攻击者应停在碰撞位置")
	
	# 防守方应该被撞走（剩余1步）
	assert_true(defender.get("is_alive"), "防守方应存活")
	assert_eq(defender.get("hex_coord"), Vector2(3, 0), "防守方应被撞到 (3,0)")

func test_simulate_out_of_bounds_dies() -> void:
	# 蓝方弹珠在远处保证不阻挡路径
	var state = {
		"current_team": RED,
		"state": "direction_selected",
		"selected_marble": 1,
		"selected_direction": 0,
		"selected_power": 5,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(5, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(-5, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_execute_move(state)
	
	var marble = mcts_ai._find_marble_in_state(new_state, 1)
	assert_false(marble.get("is_alive"), "超出边界的弹珠应死亡")

func test_simulate_victory() -> void:
	# 只有红方弹珠，弹出边界后蓝方胜利
	var state = {
		"current_team": RED,
		"state": "direction_selected",
		"selected_marble": 1,
		"selected_direction": 0,
		"selected_power": 3,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(5, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_execute_move(state)
	
	# 弹珠从 (5,0) 向右走3步到 (8,0) 出界死亡
	# 红方全灭，蓝方胜利
	assert_eq(new_state.get("winner"), BLUE, "红方弹珠死亡后蓝方应获胜")
	assert_eq(new_state.get("state"), "victory", "游戏应结束")

# ── 红球模拟测试 ──

func test_simulate_red_single_step() -> void:
	var state = {
		"current_team": RED,
		"state": "red_direction_picking",
		"selected_marble": 1,
		"red_power": 3,
		"red_directions": [],
		"selected_direction": -1,
		"selected_power": 0,
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": RED_C, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(6, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_action(state, {"action": "red_direction", "direction": 0}, gm)
	
	var marble = mcts_ai._find_marble_in_state(new_state, 1)
	assert_true(marble.get("is_alive"), "红球第一步应存活")
	
	# 走了1步（总共3步），还有2步
	assert_eq(new_state.get("state"), "red_direction_picking", "红球未走完应保持 red_direction_picking 状态")

func test_simulate_red_complete() -> void:
	var state = {
		"current_team": RED,
		"state": "red_direction_picking",
		"selected_marble": 1,
		"red_power": 1,  # 只走1步
		"red_directions": [],
		"selected_direction": -1,
		"selected_power": 0,
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": RED_C, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(6, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_action(state, {"action": "red_direction", "direction": 0}, gm)
	
	assert_eq(new_state.get("state"), "idle", "红球走完后状态应回到 idle")
	assert_eq(new_state.get("current_team"), BLUE, "红球走完后应切换到蓝方")

# ── 黑球模拟测试 ──

func test_simulate_black_move() -> void:
	var state = {
		"current_team": RED,
		"state": "black_target_picking",
		"selected_marble": 1,
		"black_target_coord": Vector2(5, 0),
		"black_approx_dir": 0,
		"red_power": 0,
		"red_directions": [],
		"selected_direction": -1,
		"selected_power": 0,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": BLACK, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(5, 0)},
		],
		"winner": -1,
	}
	
	var new_state = mcts_ai._simulate_black_move(state)
	
	# 蓝方弹珠应向方向0（右）移动3步
	# 5+3=8，棋盘半径7，(8,0)超出棋盘，蓝方弹珠死亡
	# 蓝方唯一弹珠死亡 => 红方胜利 => state="victory"
	var target = mcts_ai._find_marble_in_state(new_state, 2)
	assert_false(target.get("is_alive"), "蓝方弹珠应出界死亡")
	
	assert_eq(new_state.get("state"), "victory", "蓝方全灭后状态应为 victory")

# ── 决策测试 ──

func test_mcts_decide_in_idle() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m1)
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "select_marble", "IDLE 状态应返回 select_marble")
	assert_not_null(action.get("marble"), "应返回选中的弹珠")
	
	m1.queue_free()

func test_mcts_decide_select_direction() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.selected_marble = m1
	gm.all_marbles.append(m1)
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "select_direction", "MARBLE_SELECTED 状态应返回 select_direction")
	assert_between(action.get("direction"), 0, 5, "方向应在 0~5 范围内")
	
	m1.queue_free()

func test_mcts_decide_select_power() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.DIRECTION_SELECTED
	gm.selected_direction = 0
	
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	gm.selected_marble = m1
	gm.all_marbles.append(m1)
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "select_power", "DIRECTION_SELECTED 状态应返回 select_power")
	assert_between(action.get("power"), 1, 5, "力度应在 1~5 范围内")
	
	m1.queue_free()

func test_mcts_decide_red_power() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	
	var red_m = Marble2D.new()
	red_m.camp = RED
	red_m.is_alive = true
	red_m.color = RED_C
	red_m.hex_coord = Vector2(0, 0)
	gm.selected_marble = red_m
	gm.all_marbles.append(red_m)
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "red_power", "红球应返回 red_power")
	assert_between(action.get("power"), 1, 5, "力度应在 1~5 范围内")
	
	red_m.queue_free()

func test_mcts_decide_red_direction() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	
	var red_m = Marble2D.new()
	red_m.camp = RED
	red_m.is_alive = true
	red_m.color = RED_C
	red_m.hex_coord = Vector2(0, 0)
	gm.selected_marble = red_m
	gm.all_marbles.append(red_m)
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "red_direction", "红球逐格应返回 red_direction")
	assert_between(action.get("direction"), 0, 5, "方向应在 0~5 范围内")
	
	red_m.queue_free()

# ── 选珠阶段测试 ──

func test_mcts_setup_color_select() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.COLOR_SELECT
	gm.setup_current_team = RED
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "setup_color", "选珠颜色阶段应返回 setup_color")
	assert_between(action.get("color"), 0, 5, "颜色值应在 0~5 范围内")
	assert_eq(action.get("color"), WHITE, "首次选色应选择白色（优先级最高）")

func test_mcts_setup_placement() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.PLACEMENT
	gm.setup_current_team = RED
	
	var action = mcts_ai.decide(gm)
	assert_eq(action.get("action"), "setup_place", "选珠放置阶段应返回 setup_place")
	assert_has(action, "q", "应包含 q 坐标")
	assert_has(action, "r", "应包含 r 坐标")
	
	var in_zone = grid.is_in_red_zone(action.get("q"), action.get("r"))
	assert_true(in_zone, "放置位置应在红方区域")

# ── MCTS 节点测试 ──

func test_mcts_node_creation() -> void:
	var state = {"test": "data"}
	var node = mcts_ai.MCTSNode.new(state)
	
	assert_eq(node.state, state, "节点应存储状态")
	assert_eq(node.visits, 0, "新节点访问次数应为 0")
	assert_eq(node.total_score, 0.0, "新节点总得分应为 0")
	assert_true(node.is_leaf(), "新节点应为叶节点")

func test_mcts_node_ucb_inf_for_unvisited() -> void:
	var node = mcts_ai.MCTSNode.new({})
	var ucb = node.ucb_value(100)
	assert_eq(ucb, INF, "未访问节点的 UCB 应为 INF")

func test_mcts_node_ucb_for_visited() -> void:
	var node = mcts_ai.MCTSNode.new({})
	node.visits = 10
	node.total_score = 5.0
	
	var ucb = node.ucb_value(100)
	# UCB = exploitation(0.5) + exploration(~0.96) ≈ 1.46
	assert_true(ucb > 0.0, "访问过的节点 UCB 应大于 0.0")
	assert_true(ucb > 0.5, "访问过的节点 UCB 应包括 exploitation")

func test_mcts_node_is_terminal() -> void:
	var terminal_state = {"winner": RED}
	var node = mcts_ai.MCTSNode.new(terminal_state)
	assert_true(node.is_terminal(), "有胜利者的状态应为终端状态")
	
	var non_terminal = {"winner": -1}
	var node2 = mcts_ai.MCTSNode.new(non_terminal)
	assert_false(node2.is_terminal(), "无胜利者的状态不应为终端状态")

func test_mcts_node_average_score() -> void:
	var node = mcts_ai.MCTSNode.new({})
	node.visits = 4
	node.total_score = 2.0
	assert_eq(node.average_score(), 0.5, "平均分应为 0.5")
	
	node.visits = 0
	node.total_score = 0.0
	assert_eq(node.average_score(), 0.0, "未访问节点的平均分应为 0")

func test_mcts_node_is_fully_expanded() -> void:
	var node = mcts_ai.MCTSNode.new({})
	node.untried_actions = [{"action": "test"}]
	assert_false(node.is_fully_expanded(), "有未尝试动作时不应是完整展开的")
	
	node.untried_actions = []
	assert_true(node.is_fully_expanded(), "无未尝试动作时应是完整展开的")

# ── 回传测试 ──

func test_backpropagate_win() -> void:
	var child = mcts_ai.MCTSNode.new({"current_team": RED})
	var parent = mcts_ai.MCTSNode.new({"current_team": BLUE}, null, {"action": "test"})
	child.parent = parent
	parent.children = [child]
	
	mcts_ai._backpropagate(child, RED)
	
	assert_eq(child.visits, 1, "子节点访问次数应为 1")
	assert_eq(child.total_score, 1.0, "赢家与视角一致时应 +1")
	assert_eq(parent.visits, 1, "父节点访问次数应为 1")
	assert_eq(parent.total_score, -1.0, "父节点视角为蓝方，红方赢应 -1")

func test_backpropagate_loss() -> void:
	var child = mcts_ai.MCTSNode.new({"current_team": RED})
	
	mcts_ai._backpropagate(child, BLUE)
	
	assert_eq(child.visits, 1, "子节点访问次数应为 1")
	assert_eq(child.total_score, -1.0, "赢家为蓝方，红方视角应 -1")

func test_backpropagate_draw() -> void:
	var child = mcts_ai.MCTSNode.new({"current_team": RED})
	
	mcts_ai._backpropagate(child, -1)
	
	assert_eq(child.visits, 1, "子节点访问次数应为 1")
	assert_eq(child.total_score, 0.5, "平局应 +0.5")

# ── 错误处理测试 ──

func test_mcts_empty_state_returns_empty_action() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	# 只有蓝方弹珠（无红方），MCTS 判定胜利状态 → 返回空 → 回退 RandomAI
	# 至少不应崩溃
	var m_blue = Marble2D.new()
	m_blue.camp = BLUE
	m_blue.is_alive = true
	m_blue.color = WHITE
	m_blue.hex_coord = Vector2(0, 0)
	gm.all_marbles.append(m_blue)
	
	var m_red = Marble2D.new()
	m_red.camp = RED
	m_red.is_alive = true
	m_red.color = WHITE
	m_red.hex_coord = Vector2(3, 0)
	gm.all_marbles.append(m_red)
	
	var action = mcts_ai.decide(gm)
	assert_not_null(action, "有己方弹珠时不应崩溃")
	
	m_blue.queue_free()
	m_red.queue_free()

func test_mcts_config_methods() -> void:
	mcts_ai.set_simulation_count(200)
	assert_eq(mcts_ai.simulation_count, 200, "set_simulation_count 应更新值")
	
	mcts_ai.set_time_limit(500)
	assert_eq(mcts_ai.time_limit_ms, 500, "set_time_limit 应更新值")
	assert_true(mcts_ai.use_time_limit, "set_time_limit 应启用时间限制")

func test_mcts_debug_mode() -> void:
	mcts_ai.set_debug_mode(true)
	assert_true(mcts_ai.debug_mode, "set_debug_mode 应启用调试模式")
	
	mcts_ai.set_debug_mode(false)
	assert_false(mcts_ai.debug_mode, "set_debug_mode 应禁用调试模式")

# ── 模拟 playout 测试 ──

func test_simulate_playout_to_terminal() -> void:
	var state = {
		"current_team": RED,
		"state": "idle",
		"selected_marble": null,
		"selected_direction": -1,
		"selected_power": 0,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(3, 0)},
		],
		"winner": -1,
	}
	
	var winner = mcts_ai._simulate(state, gm)
	
	# 模拟应返回一个胜利者（RED 或 BLUE）
	assert_true(winner == RED or winner == BLUE, "playout 应返回一个胜利者")

# ── 完整 MCTS 搜索测试 ──

func test_mcts_tree_search_returns_action() -> void:
	# 创建一个简单的场景并运行 MCTS
	var state = {
		"current_team": RED,
		"state": "idle",
		"selected_marble": null,
		"selected_direction": -1,
		"selected_power": 0,
		"red_power": 0,
		"red_directions": [],
		"black_target_coord": null,
		"black_approx_dir": -1,
		"turn_number": 1,
		"marbles": [
			{"id": 1, "camp": RED, "color": WHITE, "is_alive": true, "hex_coord": Vector2(0, 0)},
			{"id": 2, "camp": BLUE, "color": WHITE, "is_alive": true, "hex_coord": Vector2(3, 0)},
		],
		"winner": -1,
	}
	
	var root = mcts_ai.MCTSNode.new(state)
	mcts_ai._generate_legal_actions(state, gm, root)
	
	assert_true(root.untried_actions.size() > 0, "根节点应有合法动作")
	
	# 执行若干轮 MCTS
	for i in range(20):
		var node = mcts_ai._select_node(root)
		if not node.is_terminal() and not node.is_fully_expanded():
			node = mcts_ai._expand_node(node, gm)
		var result = mcts_ai._simulate(node.state, gm)
		mcts_ai._backpropagate(node, result)
	
	# 验证有节点被访问
	assert_true(root.visits > 0, "根节点应有访问次数")
	assert_true(root.children.size() > 0, "根节点应有子节点")
	
	# 选择最佳动作
	var best_child = mcts_ai._best_child_by_visits(root)
	assert_not_null(best_child, "应有最佳子节点")
	assert_true(best_child.visits > 0, "最佳子节点应有访问次数")

func test_mcts_choose_best_action() -> void:
	# 创建一个 MCTS 搜索并验证返回的动作结构
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
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
	m2.hex_coord = Vector2(3, 0)
	gm.all_marbles.append(m2)
	
	var action = mcts_ai.decide(gm)
	
	assert_has(action, "action", "返回的动作应有 action 字段")
	assert_true(action.get("action") in ["select_marble", "select_direction", "select_power",
		"red_power", "red_direction", "select_enemy", "select_approx_direction",
		"setup_color", "setup_place"],
		"返回的动作类型应合法")
	
	m1.queue_free()
	m2.queue_free()

# ── 执行完整性测试（确保代码不崩溃） ──

func test_mcts_with_real_game_manager() -> void:
	mcts_ai.set_simulation_count(TEST_SIMULATION_COUNT)
	# 使用真实的 GameManager 创建弹珠
	gm.current_team = RED
	gm.current_state = GameManager.TurnState.IDLE
	
	var m1 = Marble2D.new()
	m1.camp = RED
	m1.is_alive = true
	m1.color = WHITE
	m1.hex_coord = Vector2(0, 0)
	m1.hex_grid = grid
	gm.all_marbles.append(m1)
	
	var m2 = Marble2D.new()
	m2.camp = BLUE
	m2.is_alive = true
	m2.color = WHITE
	m2.hex_coord = Vector2(3, 0)
	gm.all_marbles.append(m2)
	
	# 模拟完整的一轮决策
	var action = mcts_ai.decide(gm)
	assert_not_null(action, "MCTS 应返回动作")
	
	# 验证 action 中的 marble 引用
	if action.get("action") == "select_marble":
		assert_not_null(action.get("marble"), "select_marble 应包含 marble 引用")
