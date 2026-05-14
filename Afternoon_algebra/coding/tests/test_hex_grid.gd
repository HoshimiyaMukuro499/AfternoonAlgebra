# test_hex_grid.gd
# 测试 HexGrid2D 六边形棋盘的核心功能（使用真实 Marble2D 棋子）
class_name TestHexGrid
extends BaseTest

var grid: HexGrid2D

func before_all() -> void:
	pass

func before_each() -> void:
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE

func after_each() -> void:
	if grid:
		# 清理棋盘上所有残留的节点
		for hex in grid.marbles.keys():
			var m = grid.marbles[hex]
			if is_instance_valid(m):
				m.queue_free()
		grid.marbles.clear()
		grid.queue_free()
		grid = null

# ---------- 坐标转换测试 ----------

func test_hex_to_world_origin() -> void:
	var world = grid.hex_to_world(0, 0)
	assert_almost_eq(world.x, 0.0, 0.001, "原点x坐标应为0")
	assert_almost_eq(world.y, 0.0, 0.001, "原点y坐标应为0")

func test_hex_to_world_and_back() -> void:
	var test_coords = [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(-1,1), Vector2(-1,0), Vector2(0,-1)]
	for hex in test_coords:
		var world = grid.hex_to_world(int(hex.x), int(hex.y))
		var back = grid.world_to_hex(world)
		assert_eq(back, hex, "坐标 %s 转换后应能还原" % str(hex))

# ---------- 边界检查测试 ----------

func test_in_bounds_center() -> void:
	assert_false(grid.is_out_of_bounds(0, 0), "中心点应在棋盘内")

func test_in_bounds_edge() -> void:
	var r = MarbleConst.GRID_RADIUS
	assert_false(grid.is_out_of_bounds(r, -r), "边界点应在棋盘内")
	assert_false(grid.is_out_of_bounds(-r, r), "边界点应在棋盘内")

func test_out_of_bounds() -> void:
	var r = MarbleConst.GRID_RADIUS
	assert_true(grid.is_out_of_bounds(r + 1, 0), "超出半径应为界外")
	assert_true(grid.is_out_of_bounds(0, r + 1), "超出半径应为界外")
	assert_true(grid.is_out_of_bounds(r, r), "q+r+s=0约束，此点应界外")

# ---------- 弹珠放置与查询测试（使用真实 Marble2D） ----------

func _create_test_marble(camp: int = MarbleConst.Camp.RED) -> Marble2D:
	var marble = Marble2D.new()
	marble.hex_grid = grid
	marble.camp = camp
	return marble

func test_place_and_get_marble() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, 1, 2)
	var found = grid.get_marble_at(1, 2)
	assert_eq(found, marble, "放置后应能取回同一节点")
	marble.queue_free()

func test_place_updates_position() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, 0, 0)
	assert_almost_eq(marble.position.x, 0.0, 0.001, "放置后位置应更新")
	assert_almost_eq(marble.position.y, 0.0, 0.001, "放置后位置应更新")
	marble.queue_free()

func test_remove_marble() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, 3, 3)
	grid.remove_marble(3, 3)
	var found = grid.get_marble_at(3, 3)
	assert_null(found, "移除后应查询不到")
	marble.queue_free()

func test_move_marble() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, 0, 0)
	grid.move_marble(marble, Vector2(0, 0), Vector2(1, 0))
	assert_null(grid.get_marble_at(0, 0), "原位置应为空")
	assert_eq(grid.get_marble_at(1, 0), marble, "新位置应为该弹珠")
	marble.queue_free()

func test_place_overwrite_old() -> void:
	var marble1 = _create_test_marble(MarbleConst.Camp.RED)
	var marble2 = _create_test_marble(MarbleConst.Camp.BLUE)
	grid.place_marble(marble1, 2, 2)
	grid.place_marble(marble2, 2, 2)
	assert_eq(grid.get_marble_at(2, 2), marble2, "后放置的应覆盖前者")
	marble1.queue_free()
	marble2.queue_free()

func test_get_marble_hex() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, -2, 3)
	var hex = grid.get_marble_hex(marble)
	assert_eq(hex, Vector2(-2, 3), "应能正确获取弹珠的六边形坐标")
	marble.queue_free()

func test_get_marble_hex_unplaced() -> void:
	var marble = _create_test_marble()
	var hex = grid.get_marble_hex(marble)
	assert_eq(hex, Vector2.ZERO, "未放置的弹珠应返回(0,0)")
	marble.queue_free()

func test_remove_marble_by_node() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, 4, -1)
	grid.remove_marble_by_node(marble)
	assert_null(grid.get_marble_at(4, -1), "通过节点移除后应查询不到")
	marble.queue_free()

# ---------- 多棋子共存测试 ----------

func test_multiple_marbles_on_board() -> void:
	var m1 = _create_test_marble(MarbleConst.Camp.RED)
	var m2 = _create_test_marble(MarbleConst.Camp.RED)
	var m3 = _create_test_marble(MarbleConst.Camp.BLUE)
	grid.place_marble(m1, 0, 0)
	grid.place_marble(m2, 1, 0)
	grid.place_marble(m3, 0, 1)
	assert_eq(grid.marbles.size(), 3, "棋盘上应有3个棋子")
	assert_eq(grid.get_marble_at(0, 0), m1)
	assert_eq(grid.get_marble_at(1, 0), m2)
	assert_eq(grid.get_marble_at(0, 1), m3)
	m1.queue_free()
	m2.queue_free()
	m3.queue_free()

func test_board_state_after_marble_move() -> void:
	var m1 = _create_test_marble()
	var m2 = _create_test_marble()
	grid.place_marble(m1, 0, 0)
	grid.place_marble(m2, 1, 0)
	grid.move_marble(m1, Vector2(0, 0), Vector2(2, 0))
	assert_null(grid.get_marble_at(0, 0), "原位置应为空")
	assert_eq(grid.get_marble_at(1, 0), m2, "未移动棋子应不受影响")
	assert_eq(grid.get_marble_at(2, 0), m1, "新位置应有移动后的棋子")
	assert_eq(grid.marbles.size(), 2, "棋子总数应保持不变")
	m1.queue_free()
	m2.queue_free()

func test_marble_reposition_updates_grid() -> void:
	var marble = _create_test_marble()
	grid.place_marble(marble, 1, 1)
	grid.place_marble(marble, 3, -2)
	assert_null(grid.get_marble_at(1, 1), "旧位置应被清空")
	assert_eq(grid.get_marble_at(3, -2), marble, "新位置应有该棋子")
	assert_eq(grid.marbles.size(), 1, "重新放置不应增加数量")
	marble.queue_free()

# ---------- 边界附近棋子测试 ----------

func test_place_marble_at_edge() -> void:
	var r = MarbleConst.GRID_RADIUS
	var marble = _create_test_marble()
	grid.place_marble(marble, r, -r)
	assert_eq(grid.get_marble_at(r, -r), marble, "边界点应能放置棋子")
	marble.queue_free()

func test_place_marble_out_of_bounds() -> void:
	var marble = _create_test_marble()
	# 虽然 place_marble 不检查边界，但我们可以测试它不会崩溃
	grid.place_marble(marble, 100, 100)
	assert_eq(grid.get_marble_at(100, 100), marble, "界外放置也应记录在字典中")
	marble.queue_free()

# ---------- 棋盘字典一致性测试 ----------

func test_board_dictionary_integrity() -> void:
	var m1 = _create_test_marble()
	var m2 = _create_test_marble()
	grid.place_marble(m1, 0, 0)
	grid.place_marble(m2, 1, 1)
	for hex in grid.marbles.keys():
		var m = grid.marbles[hex]
		assert_not_null(m, "字典中不应有null值")
		assert_eq(grid.get_marble_at(int(hex.x), int(hex.y)), m, "字典应与get_marble_at一致")
	m1.queue_free()
	m2.queue_free()

func test_clear_board_after_removal() -> void:
	var m1 = _create_test_marble()
	var m2 = _create_test_marble()
	grid.place_marble(m1, 0, 0)
	grid.place_marble(m2, 1, 0)
	grid.remove_marble(0, 0)
	grid.remove_marble(1, 0)
	assert_eq(grid.marbles.size(), 0, "全部移除后字典应为空")
	m1.queue_free()
	m2.queue_free()

# ---------- 六边形距离约束测试 ----------

func test_hex_constraint() -> void:
	var r = MarbleConst.GRID_RADIUS
	assert_true(grid.is_out_of_bounds(r, r), "q+r=2r 超出约束应界外")
