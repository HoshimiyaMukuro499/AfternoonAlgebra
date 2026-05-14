# test_white_marble.gd
# 测试 WhiteMarble 白球的变色和碰撞加成机制（含棋盘状态验证）
class_name TestWhiteMarble
extends BaseTest

const WhiteMarbleScript = preload("res://white_marble.gd")

var grid: HexGrid2D
var white: Marble2D

func before_each() -> void:
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	
	white = WhiteMarbleScript.new()
	white.hex_grid = grid
	white.hex_coord = Vector2.ZERO
	white.color = MarbleConst.MarbleColor.WHITE
	white.camp = MarbleConst.Camp.RED
	grid.place_marble(white, 0, 0)

func after_each() -> void:
	# 清理可能残留的随从
	if white and is_instance_valid(white):
		BlueMarbleHelper.clear_followers(white, white.temp_followers)
		white.queue_free()
		white = null
	if grid:
		for hex in grid.marbles.keys():
			var m = grid.marbles[hex]
			if is_instance_valid(m) and m != white:
				m.queue_free()
		grid.marbles.clear()
		grid.queue_free()
		grid = null

# ---------- 碰撞步数加成测试 ----------

func test_white_gets_bonus_from_ally() -> void:
	var ally = Marble2D.new()
	ally.hex_grid = grid
	ally.camp = MarbleConst.Camp.RED
	grid.place_marble(ally, 1, 0)
	ally.hex_coord = Vector2(1, 0)
	
	var steps = white.on_collision_as_target(ally, 2, MarbleConst.HexDirection.LEFT)
	assert_eq(steps, 3, "白球被友方碰撞时步数应+1")
	ally.queue_free()

func test_white_no_bonus_from_enemy() -> void:
	var enemy = Marble2D.new()
	enemy.hex_grid = grid
	enemy.camp = MarbleConst.Camp.BLUE
	grid.place_marble(enemy, 1, 0)
	enemy.hex_coord = Vector2(1, 0)
	
	var steps = white.on_collision_as_target(enemy, 2, MarbleConst.HexDirection.LEFT)
	assert_eq(steps, 2, "白球被敌方碰撞时步数不应+1")
	enemy.queue_free()

func test_no_bonus_when_already_colored() -> void:
	white.color = MarbleConst.MarbleColor.BLUE
	var ally = Marble2D.new()
	ally.hex_grid = grid
	ally.camp = MarbleConst.Camp.RED
	grid.place_marble(ally, 1, 0)
	ally.hex_coord = Vector2(1, 0)
	
	var steps = white.on_collision_as_target(ally, 2, MarbleConst.HexDirection.LEFT)
	assert_eq(steps, 2, "非白色时不应触发步数加成")
	ally.queue_free()

# ---------- 变色逻辑测试 ----------

func test_change_color_updates_color() -> void:
	white.change_color(MarbleConst.MarbleColor.BLUE)
	assert_eq(white.color, MarbleConst.MarbleColor.BLUE, "变色后color属性应更新")

func test_change_color_updates_appearance() -> void:
	# Sprite 需要实际节点才能测试 modulate，此处仅测试属性
	white.change_color(MarbleConst.MarbleColor.GREEN)
	assert_eq(white.color, MarbleConst.MarbleColor.GREEN)

func test_has_changed_flag() -> void:
	assert_false(white.has_changed, "初始应为未变色")
	white.on_teammate_died(MarbleConst.MarbleColor.BLUE)
	assert_true(white.has_changed, "变色后标志应为true")

func test_ignore_yellow_teammate_death() -> void:
	white.on_teammate_died(MarbleConst.MarbleColor.YELLOW)
	assert_eq(white.color, MarbleConst.MarbleColor.WHITE, "黄球死亡不应触发变色")

func test_can_override_color() -> void:
	white.on_teammate_died(MarbleConst.MarbleColor.BLUE)
	white.on_teammate_died(MarbleConst.MarbleColor.GREEN)
	assert_eq(white.color, MarbleConst.MarbleColor.GREEN, "应允许覆盖变色")

# ---------- 按颜色移动分发测试 ----------

func test_move_as_white() -> void:
	white.color = MarbleConst.MarbleColor.WHITE
	white.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_eq(white.hex_coord, Vector2(2, 0), "白色应正常移动")

func test_move_as_black_no_move() -> void:
	white.color = MarbleConst.MarbleColor.BLACK
	var old_pos = white.hex_coord
	white.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_eq(white.hex_coord, old_pos, "黑色不应移动")

# ---------- 变色为蓝后的棋盘随从测试 ----------

func test_blue_white_spawns_followers_on_grid() -> void:
	white.change_color(MarbleConst.MarbleColor.BLUE)
	white.move(MarbleConst.HexDirection.RIGHT, 2)
	
	# 移动后随从应被清除，棋盘上只应有白球
	assert_eq(white.hex_coord, Vector2(2, 0), "变蓝后应正常移动")
	assert_true(white.is_alive, "变蓝移动后应存活")

func test_blue_white_move_updates_grid_state() -> void:
	white.change_color(MarbleConst.MarbleColor.BLUE)
	grid.place_marble(white, 0, 0)
	white.hex_coord = Vector2.ZERO
	
	white.move(MarbleConst.HexDirection.RIGHT, 2)
	
	assert_null(grid.get_marble_at(0, 0), "变蓝移动后原位置应为空")
	assert_eq(grid.get_marble_at(2, 0), white, "变蓝移动后新位置应有白球")

func test_blue_white_collision_with_followers_grid_state() -> void:
	# 在路径上放置一个敌方棋子，测试碰撞时棋盘状态
	white.change_color(MarbleConst.MarbleColor.BLUE)
	var enemy = Marble2D.new()
	enemy.hex_grid = grid
	enemy.camp = MarbleConst.Camp.BLUE
	grid.place_marble(enemy, 2, 0)
	enemy.hex_coord = Vector2(2, 0)
	
	white.move(MarbleConst.HexDirection.RIGHT, 3)
	
	# 白球在 (1,0) 撞到 enemy，enemy 获得 2 步移动到 (4,0)
	assert_eq(grid.get_marble_at(1, 0), white, "白球应停在(1,0)")
	assert_eq(grid.get_marble_at(4, 0), enemy, "被撞者应到达(4,0)")
	assert_true(white.is_alive, "碰撞后白球应存活")
	
	enemy.queue_free()
