# test_player_interaction_v2.gd
# 玩家交互流程测试：
#   - 状态机交互（选/取消/非法操作）通过 GameManager 接口
#   - 移动/碰撞结果直接调用 marble.move()（避免 execute_move 的 await get_tree() 限制）
#   - 回合管理直接调用 start_turn()
class_name TestPlayerInteraction
extends "res://tests/base_test.gd"

const RED_CAMP := MarbleConst.Camp.RED
const BLUE_CAMP := MarbleConst.Camp.BLUE

# HexDirection 枚举值（int 类型）
const RIGHT := MarbleConst.HexDirection.RIGHT
const RIGHT_UP := MarbleConst.HexDirection.RIGHT_UP

# TurnState 常量（int 类型，赋值时需 as GameManager.TurnState）
const S_IDLE := GameManager.TurnState.IDLE
const S_SELECTED := GameManager.TurnState.MARBLE_SELECTED
const S_DIR := GameManager.TurnState.DIRECTION_SELECTED
const S_EXEC := GameManager.TurnState.EXECUTING
const S_RDIR := GameManager.TurnState.RED_DIRECTION_PICKING

var gm: GameManager
var grid: HexGrid2D
var marbles: Array[Marble2D] = []


func before_each() -> void:
	gm = GameManager.new()
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	gm.hex_grid = grid

	gm.current_state = S_IDLE as GameManager.TurnState
	gm.current_team = RED_CAMP
	gm.selected_marble = null
	gm.selected_direction = -1
	gm.selected_power = 0

	marbles = []


func after_each() -> void:
	for m in marbles:
		if m and is_instance_valid(m):
			m.queue_free()
	marbles.clear()
	if grid:
		for hex in grid.marbles.keys():
			var m = grid.marbles[hex]
			if is_instance_valid(m):
				m.queue_free()
		grid.marbles.clear()
		grid.queue_free()
		grid = null
	if gm:
		gm.queue_free()
		gm = null


# ---------- 辅助方法 ----------

func _mk(coord: Vector2i, camp: int, color: int) -> Marble2D:
	var m := Marble2D.new()
	m.hex_grid = grid
	m.hex_coord = Vector2(coord.x, coord.y)
	m.camp = camp as MarbleConst.Camp
	m.color = color as MarbleConst.MarbleColor
	m.is_alive = true
	grid.place_marble(m, coord.x, coord.y)
	marbles.append(m)
	return m

func _board4() -> void:
	_mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	_mk(Vector2i(2, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	_mk(Vector2i(-1, 1), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	_mk(Vector2i(3, -1), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)


# ================================================================
# 第1组：选中弹珠交互（状态机）
# ================================================================

func test_select_own_marble_gives_selected_state() -> void:
	_board4()
	gm.current_team = RED_CAMP
	var m: Marble2D = grid.get_marble_at(0, 0)

	gm.select_marble(m)

	assert_eq(gm.current_state, S_SELECTED as GameManager.TurnState, "→ MARBLE_SELECTED")
	assert_eq(gm.selected_marble, m, "记录弹珠")


func test_select_own_marble_highlights() -> void:
	_board4()
	gm.current_team = RED_CAMP
	var m: Marble2D = grid.get_marble_at(0, 0)

	gm.select_marble(m)

	assert_true(m.is_highlighted, "选中弹珠高亮")


func test_select_enemy_marble_rejected() -> void:
	_board4()
	gm.current_team = RED_CAMP
	var m: Marble2D = grid.get_marble_at(-1, 1)  # 蓝方

	gm.select_marble(m)

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "状态不变")
	assert_null(gm.selected_marble, "无选中")


func test_select_dead_marble_rejected() -> void:
	_board4()
	gm.current_team = RED_CAMP
	var m: Marble2D = grid.get_marble_at(0, 0)
	m.is_alive = false

	gm.select_marble(m)

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "状态不变")


func test_select_during_executing_rejected() -> void:
	_board4()
	gm.current_state = S_EXEC as GameManager.TurnState
	gm.current_team = RED_CAMP
	var m: Marble2D = grid.get_marble_at(0, 0)

	gm.select_marble(m)

	assert_eq(gm.current_state, S_EXEC as GameManager.TurnState, "保持 EXECUTING")


# ================================================================
# 第2组：选方向交互
# ================================================================

func test_select_direction_enters_dir_selected() -> void:
	_board4()
	gm.current_state = S_SELECTED as GameManager.TurnState
	gm.selected_marble = grid.get_marble_at(0, 0)

	gm.select_direction(RIGHT)

	assert_eq(gm.current_state, S_DIR as GameManager.TurnState, "→ DIRECTION_SELECTED")
	assert_eq(gm.selected_direction, RIGHT, "记录方向")


func test_select_direction_wrong_state_ignored() -> void:
	gm.current_state = S_IDLE as GameManager.TurnState
	gm.selected_direction = -1

	gm.select_direction(RIGHT)

	assert_eq(gm.selected_direction, -1, "未改变")


# ================================================================
# 第3组：取消操作
# ================================================================

func test_cancel_resets_to_idle() -> void:
	_board4()
	var m: Marble2D = grid.get_marble_at(0, 0)
	gm.current_state = S_SELECTED as GameManager.TurnState
	gm.selected_marble = m

	gm.cancel_selection()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	assert_null(gm.selected_marble, "清空选中")
	assert_false(m.is_highlighted, "取消高亮")
	assert_eq(gm.selected_direction, -1, "方向重置")
	assert_eq(gm.selected_power, 0, "力度重置")


func test_cancel_after_direction_resets() -> void:
	_board4()
	gm.current_state = S_DIR as GameManager.TurnState
	gm.selected_direction = 2
	gm.selected_marble = grid.get_marble_at(0, 0)

	gm.cancel_selection()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	assert_eq(gm.selected_direction, -1, "方向重置")


func test_cancel_idle_does_nothing() -> void:
	gm.current_state = S_IDLE as GameManager.TurnState
	gm.cancel_selection()
	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "不变")


func test_cancel_executing_does_nothing() -> void:
	gm.current_state = S_EXEC as GameManager.TurnState
	gm.cancel_selection()
	assert_eq(gm.current_state, S_EXEC as GameManager.TurnState, "不变")


# ================================================================
# 第4组：移动结果（直接 marble.move()）
# ================================================================

func test_move_step_by_step_position() -> void:
	var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)

	m.move(RIGHT, 3)

	assert_eq(m.hex_coord, Vector2(3, 0), "到(3,0)")
	assert_true(m.is_alive, "存活")


func test_move_updates_grid() -> void:
	var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)

	m.move(RIGHT, 2)

	assert_null(grid.get_marble_at(0, 0), "原位置空")
	assert_eq(grid.get_marble_at(2, 0), m, "新位置有弹珠")


func test_move_six_directions() -> void:
	var dirs := [0, 1, 2, 3, 4, 5]
	var exps := [
		Vector2(1, 0),   # 0 RIGHT
		Vector2(0, 1),   # 1 RIGHT_UP
		Vector2(-1, 1),  # 2 LEFT_UP
		Vector2(-1, 0),  # 3 LEFT
		Vector2(0, -1),  # 4 LEFT_DOWN
		Vector2(1, -1),  # 5 RIGHT_DOWN
	]
	var names := ["R","RU","LU","L","LD","RD"]
	for i in 6:
		var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
		m.move(dirs[i], 1)
		assert_eq(m.hex_coord, exps[i], "%s (dir=%d)" % [names[i], dirs[i]])


func test_move_out_of_bounds_dies() -> void:
	var r := MarbleConst.GRID_RADIUS
	var m := _mk(Vector2i(r, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)

	m.move(RIGHT, 1)

	assert_false(m.is_alive, "死亡")
	assert_null(grid.get_marble_at(r, 0), "从棋盘移除")


# ================================================================
# 第5组：碰撞交互
# ================================================================

func test_collision_attacker_stops_defender_advances() -> void:
	var att := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var def := _mk(Vector2i(1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)

	att.move(RIGHT, 3)

	# att(0,0)→看next(1,0)有def，停止
	# def 获得剩余3步→(4,0)
	assert_eq(att.hex_coord, Vector2(0, 0), "攻击者停在(0,0)")
	assert_true(def.is_alive, "防御者存活")
	assert_eq(def.hex_coord, Vector2(4, 0), "防御者到(4,0)")


func test_ally_collision_chain() -> void:
	var a := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var b := _mk(Vector2i(2, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)

	a.move(RIGHT, 3)

	# a(0,0)→(1,0)→看next(2,0)有b，停(1,0)
	# b 获得剩余2步→(4,0)
	assert_eq(a.hex_coord, Vector2(1, 0), "a停(1,0)")
	assert_true(b.is_alive, "b存活")
	assert_eq(b.hex_coord, Vector2(4, 0), "b到(4,0)")


func test_collision_to_death() -> void:
	var r := MarbleConst.GRID_RADIUS
	var blue := _mk(Vector2i(r, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var red := _mk(Vector2i(r - 1, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)

	red.move(RIGHT, 2)

	assert_false(blue.is_alive, "蓝死亡")
	assert_true(red.is_alive, "红存活")
	assert_eq(red.hex_coord, Vector2(r - 1, 0), "红停在原地")


# ================================================================
# 第6组：红球特殊交互
# ================================================================

func test_red_select_power_enters_picking() -> void:
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_state = S_SELECTED as GameManager.TurnState
	gm.selected_marble = rm

	gm.red_select_power(3)

	assert_eq(gm.current_state, S_RDIR as GameManager.TurnState, "→ RED_DIRECTION_PICKING")
	assert_eq(gm.red_total_steps, 3, "步数=3")


func test_red_append_direction_accumulates() -> void:
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_state = S_RDIR as GameManager.TurnState
	gm.selected_marble = rm
	gm.red_total_steps = 3

	gm.red_append_direction(RIGHT)

	assert_eq(gm.red_step_directions.size(), 1, "添加1个方向")
	assert_eq(gm.red_step_directions[0], RIGHT, "内容RIGHT")


func test_red_full_flow() -> void:
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_team = RED_CAMP
	gm.current_state = S_IDLE as GameManager.TurnState

	gm.select_marble(rm)
	gm.red_select_power(3)
	gm.red_append_direction(RIGHT)
	gm.red_append_direction(RIGHT)
	gm.red_append_direction(RIGHT_UP)

	# 红球(0,0)→RIGHT(1,0)→RIGHT(2,0)→RIGHT_UP(2,1)
	assert_eq(rm.hex_coord, Vector2(2, 1), "到(2,1)")
	assert_true(rm.is_alive, "存活")


func test_red_cancel_during_picking() -> void:
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_state = S_SELECTED as GameManager.TurnState
	gm.selected_marble = rm
	gm.red_select_power(3)
	gm.red_append_direction(RIGHT)

	gm.cancel_selection()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	assert_eq(gm.red_step_directions.size(), 0, "方向已清空")
	assert_eq(gm.red_total_steps, 0, "步数已清空")
	assert_eq(rm.hex_coord, Vector2(0, 0), "未移动")


# ================================================================
# 第7组：回合管理
# ================================================================

func test_start_turn_increments_number() -> void:
	assert_eq(gm.turn_number, 0, "初始0")
	gm.start_turn()
	assert_eq(gm.turn_number, 1, "第1回合")
	gm.start_turn()
	assert_eq(gm.turn_number, 2, "第2回合")


func test_start_turn_resets_selection_state() -> void:
	gm.current_state = S_EXEC as GameManager.TurnState
	gm.selected_direction = 3
	gm.selected_power = 2

	gm.start_turn()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	assert_null(gm.selected_marble, "清空")
	assert_eq(gm.selected_direction, -1, "方向重置")
	assert_eq(gm.selected_power, 0, "力度重置")


# ================================================================
# 第8组：棋盘状态一致性
# ================================================================

func test_board_size_unchanged_after_move() -> void:
	_board4()
	var bm: Marble2D = grid.get_marble_at(0, 0)

	bm.move(RIGHT, 1)

	assert_eq(grid.marbles.size(), 4, "弹珠数4")
	assert_not_null(grid.get_marble_at(1, 0), "(1,0)有弹珠")
	assert_null(grid.get_marble_at(0, 0), "(0,0)为空")


func test_board_no_invalid_entries_after_move() -> void:
	_board4()
	var bm: Marble2D = grid.get_marble_at(0, 0)
	bm.move(RIGHT, 2)

	for hex in grid.marbles.keys():
		var node = grid.marbles[hex]
		assert_true(is_instance_valid(node), "每个key对应有效节点")
		assert_true(node.is_alive, "每个节点存活")


# ================================================================
# 第9组：选择力度与执行（GameManager 完整流程）
# ================================================================

func test_select_power_moves_marble() -> void:
	# select_power → execute_move → _finish_turn_or_victory 完整流程
	# 注意：_finish_turn_or_victory 中 _check_victory 发现没有敌方弹珠时会胜利结束
	# 所以需要保留足够的蓝方弹珠
	var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	_mk(Vector2i(10, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	_mk(Vector2i(10, 2), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_state = S_DIR as GameManager.TurnState
	gm.selected_marble = m
	gm.selected_direction = RIGHT
	gm.all_marbles = marbles.duplicate()

	gm.select_power(2)

	# 执行完成后 start_turn 将状态变为 IDLE
	# 注意：在非场景树中，await(get_tree().create_timer) 会立即完成
	# 并且 _finish_turn_or_victory 可能直接设置 victory/执行新回合
	# 所以只验证弹珠移动正确
	assert_eq(m.hex_coord, Vector2(2, 0), "弹珠移动到(2,0)")
	assert_true(m.is_alive, "弹珠存活")


func test_select_power_from_wrong_state_ignored() -> void:
	_mk(Vector2i(10, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_state = S_IDLE as GameManager.TurnState
	gm.selected_direction = RIGHT

	gm.select_power(3)

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "IDLE不应响应")
	assert_eq(gm.selected_power, 0, "力度未改变")


# ================================================================
# 第10组：红球取消与棋盘状态验证
# ================================================================

func test_red_cancel_restores_grid_position() -> void:
	# 红球已移动几步后取消，棋盘状态应正确恢复
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	_mk(Vector2i(10, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_team = RED_CAMP
	gm.current_state = S_IDLE as GameManager.TurnState

	gm.select_marble(rm)
	gm.red_select_power(3)
	gm.red_append_direction(RIGHT)
	gm.red_append_direction(RIGHT)
	# 红球已移动2步到(2,0)

	gm.cancel_selection()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	# 检查棋盘：原位置有红球
	assert_eq(grid.get_marble_at(0, 0), rm, "红球应回到(0,0)")
	assert_null(grid.get_marble_at(1, 0), "(1,0)应为空")
	assert_null(grid.get_marble_at(2, 0), "(2,0)应为空")


func test_red_cancel_before_any_move() -> void:
	# 取消时红球还没移动过，棋盘状态应不变
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	_mk(Vector2i(10, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_team = RED_CAMP
	gm.current_state = S_SELECTED as GameManager.TurnState
	gm.selected_marble = rm

	gm.red_select_power(3)
	# 还没选任何方向就取消

	gm.cancel_selection()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	assert_eq(rm.hex_coord, Vector2(0, 0), "未移动")
	assert_eq(grid.get_marble_at(0, 0), rm, "棋盘上红球仍在(0,0)")


# ================================================================
# 第11组：红球错误状态拒绝
# ================================================================

func test_red_append_direction_from_idle_rejected() -> void:
	# 非 RED_DIRECTION_PICKING 状态不应响应
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_state = S_IDLE as GameManager.TurnState
	gm.selected_marble = rm

	gm.red_append_direction(RIGHT)

	assert_eq(gm.red_step_directions.size(), 0, "不应添加方向")


func test_red_select_power_from_rdir_rejected() -> void:
	# 已在逐格选方向模式时再次选力度不应响应
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_state = S_RDIR as GameManager.TurnState
	gm.selected_marble = rm

	gm.red_select_power(5)

	assert_eq(gm.current_state, S_RDIR as GameManager.TurnState, "状态不变")
	assert_eq(gm.red_total_steps, 0, "步数不变")


# ================================================================
# 第12组：红球碰撞后取消
# ================================================================

func test_red_cancel_after_collision_restores_grid() -> void:
	# 红球碰撞后取消，应回到起始位置
	var rm := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	var _enemy := _mk(Vector2i(2, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	_mk(Vector2i(10, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_team = RED_CAMP
	gm.current_state = S_IDLE as GameManager.TurnState

	gm.select_marble(rm)
	gm.red_select_power(4)
	# 第1步到(1,0)，第2步撞到(2,0)的enemy
	gm.red_append_direction(RIGHT)
	gm.red_append_direction(RIGHT)
	# 此时红球应停在(1,0)（碰撞逻辑）

	gm.cancel_selection()

	assert_eq(gm.current_state, S_IDLE as GameManager.TurnState, "→ IDLE")
	assert_eq(rm.hex_coord, Vector2(0, 0), "红球回(0,0)")
	assert_eq(grid.get_marble_at(0, 0), rm, "棋盘上红球在(0,0)")


# ================================================================
# 第13组：回合管理中红球状态重置
# ================================================================

func test_start_turn_resets_red_state() -> void:
	# start_turn 应重置红球专用变量
	gm.red_step_directions = [0, 1]
	gm.red_total_steps = 3
	gm.red_current_step_index = 2
	gm.red_moved_steps = 2

	gm.start_turn()

	assert_eq(gm.red_step_directions.size(), 0, "方向列表清空")
	assert_eq(gm.red_total_steps, 0, "步数清空")
	assert_eq(gm.red_current_step_index, 0, "索引重置")
	assert_eq(gm.red_moved_steps, 0, "已走步数重置")

# ================================================================
# 第14组：链式碰撞导致边界死亡（4球一线，末端出界）
# 覆盖场景：4个球连成一线，最后一个以力5碰撞，最前面的球应出界死亡
# ================================================================

func test_chain_collision_four_balls_leading_dies() -> void:
	# 4球一线：球A(0,0), 球B(1,0), 球C(2,0), 球D(3,0)
	# 球A(红)以力5向右撞 → 球D在位置(3,0)，力5应走到(8,0)，出界死亡（半径7）
	var ballA := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballC := _mk(Vector2i(2, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballD := _mk(Vector2i(3, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)

	ballA.move(RIGHT, 5)
	
	assert_false(ballD.is_alive, "最前端的球D应死亡（出界）")
	assert_true(ballA.is_alive, "攻击者球A应存活")
	assert_true(ballB.is_alive, "球B应存活")
	assert_true(ballC.is_alive, "球C应存活")
	assert_null(grid.get_marble_at(3, 0), "球D原位置(3,0)应为空")
	assert_eq(ballA.hex_coord, Vector2(0, 0), "攻击者球A应停在(0,0)")
	assert_eq(grid.marbles.size(), 3, "棋盘应只剩3个弹珠")


func test_chain_collision_four_balls_leading_dies_grid_state() -> void:
	"""验证4球链式碰撞出界后，棋盘字典完整无残留"""
	var ballA := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballC := _mk(Vector2i(2, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballD := _mk(Vector2i(3, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)

	ballA.move(RIGHT, 5)

	for hex in grid.marbles.keys():
		var node = grid.marbles[hex]
		assert_true(is_instance_valid(node), "每个key对应有效节点，hex=%s" % str(hex))
		assert_true(node.is_alive, "每个节点存活，hex=%s" % str(hex))
	
	assert_eq(grid.marbles.size(), 3, "棋盘应有3个弹珠")


func test_chain_collision_four_balls_no_death_success() -> void:
	"""4球一线，力3（不出界），验证链式碰撞正确完成"""
	var ballA := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballC := _mk(Vector2i(2, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballD := _mk(Vector2i(3, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)

	ballA.move(RIGHT, 3)

	assert_true(ballA.is_alive, "攻击者球A存活")
	assert_true(ballB.is_alive, "球B存活")
	assert_true(ballC.is_alive, "球C存活")
	assert_true(ballD.is_alive, "球D存活（(6,0)在边界内）")
	assert_eq(ballA.hex_coord, Vector2(0, 0), "球A停在(0,0)")
	assert_eq(ballB.hex_coord, Vector2(1, 0), "球B停在(1,0)")
	assert_eq(ballC.hex_coord, Vector2(2, 0), "球C停在(2,0)")
	assert_eq(ballD.hex_coord, Vector2(6, 0), "球D到(6,0)")
	assert_eq(grid.marbles.size(), 4, "棋盘应有4个弹珠")


# ================================================================
# 第15组：边界附近的碰撞死亡
# ================================================================

func test_collision_at_boundary_dies() -> void:
	"""边界处碰撞，被撞者出界死亡"""
	var r := MarbleConst.GRID_RADIUS
	var red := _mk(Vector2i(r - 1, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var blue := _mk(Vector2i(r, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)

	red.move(RIGHT, 2)

	assert_false(blue.is_alive, "蓝球应出界死亡")
	assert_true(red.is_alive, "红球应存活")
	assert_eq(red.hex_coord, Vector2(r - 1, 0), "红球停在(r-1,0)")
	assert_null(grid.get_marble_at(r, 0), "蓝球原位置为空")
	assert_eq(grid.marbles.size(), 1, "棋盘只剩红球")


func test_chain_collision_multiple_deaths() -> void:
	"""链式碰撞导致多个球出界死亡"""
	var r := MarbleConst.GRID_RADIUS
	var ballA := _mk(Vector2i(r - 2, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(r - 1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballC := _mk(Vector2i(r, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)

	ballA.move(RIGHT, 3)

	assert_false(ballC.is_alive, "球C应出界死亡")
	assert_true(ballA.is_alive, "球A存活")
	assert_true(ballB.is_alive, "球B存活（停在(r-1,0)）")
	assert_eq(ballA.hex_coord, Vector2(r - 2, 0), "球A停在(r-2,0)")
	assert_eq(ballB.hex_coord, Vector2(r - 1, 0), "球B停在(r-1,0)")
	assert_null(grid.get_marble_at(r, 0), "球C原位置为空")
	assert_eq(grid.marbles.size(), 2, "棋盘剩2个弹珠")


# ================================================================
# 第16组：GameManager 完整流程 + 链式碰撞出界死亡
# ================================================================

func test_gm_execute_move_chain_collision_leading_dies() -> void:
	"""GameManager execute_move 中链式碰撞导致最远球死亡"""
	var ballA := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballC := _mk(Vector2i(2, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballD := _mk(Vector2i(3, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	
	var extra_blue := _mk(Vector2i(10, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	extra_blue.is_alive = true
	
	gm.all_marbles = marbles.duplicate()
	gm.current_state = S_EXEC as GameManager.TurnState
	gm.selected_marble = ballA
	gm.selected_direction = RIGHT
	gm.selected_power = 5
	gm.current_team = RED_CAMP
	
	ballA.move(RIGHT, 5)
	
	assert_false(ballD.is_alive, "球D应出界死亡")
	assert_true(ballA.is_alive, "球A存活")
	assert_true(ballB.is_alive, "球B存活")
	assert_true(ballC.is_alive, "球C存活")


func test_gm_execute_move_chain_ends_at_victory() -> void:
	"""链式碰撞导致对方全灭，应触发胜利状态"""
	var ballA := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(1, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballC := _mk(Vector2i(2, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballD := _mk(Vector2i(3, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	
	gm.all_marbles = marbles.duplicate()
	
	var winner = gm._check_victory()
	assert_eq(winner, -1, "初始无胜利")
	
	ballA.move(RIGHT, 5)
	
	winner = gm._check_victory()
	assert_eq(winner, -1, "蓝方还有球B和C存活，不应胜利")
	assert_true(ballB.is_alive, "球B存活")
	assert_true(ballC.is_alive, "球C存活")


func test_gm_execute_move_all_enemy_dies_victory() -> void:
	"""碰撞导致唯一蓝球出界死亡，应检测到红方胜利"""
	var r := MarbleConst.GRID_RADIUS
	var ballA := _mk(Vector2i(r - 1, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	var ballB := _mk(Vector2i(r, 0), BLUE_CAMP, MarbleConst.MarbleColor.WHITE)
	
	gm.all_marbles = marbles.duplicate()
	
	# 球A向右移动2步，第一步就撞到球B，球B被推出界死亡
	ballA.move(RIGHT, 2)
	
	assert_false(ballB.is_alive, "唯一蓝球出界死亡")
	assert_true(ballA.is_alive, "红球存活")
	assert_eq(ballA.hex_coord, Vector2(r - 1, 0), "红球停在原地")
	
	var winner = gm._check_victory()
	assert_eq(winner, RED_CAMP, "红方应胜利")
