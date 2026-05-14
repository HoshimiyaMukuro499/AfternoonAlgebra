# test_hex_grid.gd
# 测试 HexGrid2D 六边形棋盘的核心功能
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

# ---------- 弹珠放置与查询测试 ----------

func test_place_and_get_marble() -> void:
	var marble = Area2D.new()
	grid.place_marble(marble, 1, 2)
	var found = grid.get_marble_at(1, 2)
	assert_eq(found, marble, "放置后应能取回同一节点")
	marble.queue_free()

func test_place_updates_position() -> void:
	var marble = Area2D.new()
	grid.place_marble(marble, 0, 0)
	assert_almost_eq(marble.position.x, 0.0, 0.001, "放置后位置应更新")
	assert_almost_eq(marble.position.y, 0.0, 0.001, "放置后位置应更新")
	marble.queue_free()

func test_remove_marble() -> void:
	var marble = Area2D.new()
	grid.place_marble(marble, 3, 3)
	grid.remove_marble(3, 3)
	var found = grid.get_marble_at(3, 3)
	assert_null(found, "移除后应查询不到")
	marble.queue_free()

func test_move_marble() -> void:
	var marble = Area2D.new()
	grid.place_marble(marble, 0, 0)
	grid.move_marble(marble, Vector2(0, 0), Vector2(1, 0))
	assert_null(grid.get_marble_at(0, 0), "原位置应为空")
	assert_eq(grid.get_marble_at(1, 0), marble, "新位置应为该弹珠")
	marble.queue_free()

func test_place_overwrite_old() -> void:
	var marble1 = Area2D.new()
	var marble2 = Area2D.new()
	grid.place_marble(marble1, 2, 2)
	grid.place_marble(marble2, 2, 2)
	assert_eq(grid.get_marble_at(2, 2), marble2, "后放置的应覆盖前者")
	marble1.queue_free()
	marble2.queue_free()

# ---------- 六边形距离约束测试 ----------

func test_hex_constraint() -> void:
	var r = MarbleConst.GRID_RADIUS
	assert_true(grid.is_out_of_bounds(r, r), "q+r=2r 超出约束应界外")
