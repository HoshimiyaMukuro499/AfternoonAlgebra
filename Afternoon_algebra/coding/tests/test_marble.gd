# test_marble.gd
# 测试 Marble2D 基类的移动、碰撞、邻居计算
class_name TestMarble
extends BaseTest

var grid: HexGrid2D
var marble: Marble2D

func before_each() -> void:
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	
	marble = Marble2D.new()
	marble.hex_grid = grid
	marble.hex_coord = Vector2.ZERO
	grid.place_marble(marble, 0, 0)

func after_each() -> void:
	if marble:
		marble.queue_free()
		marble = null
	if grid:
		grid.queue_free()
		grid = null

# ---------- 邻居方向测试 ----------

func test_neighbor_right() -> void:
	var n = marble.get_neighbor_hex(Vector2.ZERO, MarbleConst.HexDirection.RIGHT)
	assert_eq(n, Vector2(1, 0), "RIGHT方向应为(1,0)")

func test_neighbor_left() -> void:
	var n = marble.get_neighbor_hex(Vector2.ZERO, MarbleConst.HexDirection.LEFT)
	assert_eq(n, Vector2(-1, 0), "LEFT方向应为(-1,0)")

func test_neighbor_right_up() -> void:
	var n = marble.get_neighbor_hex(Vector2.ZERO, MarbleConst.HexDirection.RIGHT_UP)
	assert_eq(n, Vector2(1, 1), "RIGHT_UP方向应为(1,1)")

func test_neighbor_all_directions() -> void:
	var expected = [
		Vector2(1, 0),   # RIGHT
		Vector2(1, 1),   # RIGHT_UP
		Vector2(0, 1),   # LEFT_UP
		Vector2(-1, 0),  # LEFT
		Vector2(-1, -1), # LEFT_DOWN
		Vector2(0, -1)   # RIGHT_DOWN
	]
	for dir in range(6):
		var n = marble.get_neighbor_hex(Vector2.ZERO, dir)
		assert_eq(n, expected[dir], "方向 %d 坐标不匹配" % dir)

# ---------- 弹珠状态测试 ----------

func test_initial_alive() -> void:
	assert_true(marble.is_alive, "初始状态应为存活")

func test_initial_color() -> void:
	assert_eq(marble.color, MarbleConst.MarbleColor.WHITE, "默认颜色应为WHITE")

func test_initial_camp() -> void:
	assert_eq(marble.camp, MarbleConst.Camp.RED, "默认阵营应为RED")

# ---------- 移动测试（基础） ----------

func test_move_to_empty_cell() -> void:
	marble.move(MarbleConst.HexDirection.RIGHT, 1)
	assert_eq(marble.hex_coord, Vector2(1, 0), "向右移动1格后坐标应为(1,0)")

func test_move_multi_steps() -> void:
	marble.move(MarbleConst.HexDirection.RIGHT, 3)
	assert_eq(marble.hex_coord, Vector2(3, 0), "向右移动3格后坐标应为(3,0)")

func test_move_out_of_bounds_die() -> void:
	var r = MarbleConst.GRID_RADIUS
	grid.place_marble(marble, r, 0)
	marble.hex_coord = Vector2(r, 0)
	marble.move(MarbleConst.HexDirection.RIGHT, 1)
	assert_false(marble.is_alive, "出界后应死亡")

# ---------- 碰撞测试 ----------

func test_collision_moves_target() -> void:
	var m1 = Marble2D.new()
	var m2 = Marble2D.new()
	m1.hex_grid = grid
	m2.hex_grid = grid
	grid.place_marble(m1, 0, 0)
	grid.place_marble(m2, 1, 0)
	m1.hex_coord = Vector2(0, 0)
	m2.hex_coord = Vector2(1, 0)
	
	m1.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_true(m1.is_alive, "碰撞者应保持存活")
	assert_true(m2.is_alive, "被撞者应保持存活")
	assert_eq(m2.hex_coord, Vector2(2, 0), "被撞者应移动到(2,0)")
	
	m1.queue_free()
	m2.queue_free()

func test_collision_chain() -> void:
	var m1 = Marble2D.new()
	var m2 = Marble2D.new()
	var m3 = Marble2D.new()
	for m in [m1, m2, m3]:
		m.hex_grid = grid
	grid.place_marble(m1, 0, 0)
	grid.place_marble(m2, 1, 0)
	grid.place_marble(m3, 2, 0)
	m1.hex_coord = Vector2(0, 0)
	m2.hex_coord = Vector2(1, 0)
	m3.hex_coord = Vector2(2, 0)
	
	m1.move(MarbleConst.HexDirection.RIGHT, 3)
	
	assert_true(m3.is_alive, "链式碰撞末端应保持存活")
	assert_eq(m3.hex_coord, Vector2(3, 0), "末端应到达(3,0)")
	
	for m in [m1, m2, m3]:
		m.queue_free()

# ---------- 高亮测试 ----------

func test_highlight_flag() -> void:
	marble.highlight()
	assert_true(marble.is_highlighted, "高亮后标志应为true")
	marble.unhighlight()
	assert_false(marble.is_highlighted, "取消高亮后标志应为false")

# ---------- 死亡测试 ----------

func test_die_removes_from_grid() -> void:
	grid.place_marble(marble, 0, 0)
	marble.hex_coord = Vector2.ZERO
	marble.die()
	assert_null(grid.get_marble_at(0, 0), "死亡后应从棋盘移除")
