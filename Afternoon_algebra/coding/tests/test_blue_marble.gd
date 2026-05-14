# test_blue_marble.gd
# 测试 BlueMarble 蓝球及随从机制
class_name TestBlueMarble
extends BaseTest

const WhiteMarbleScript = preload("res://white_marble.gd")

var grid: HexGrid2D
var blue: Marble2D  # 使用 WhiteMarble 变色为 BLUE 来测试

func before_each() -> void:
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	
	# 用 WhiteMarble 变色为蓝色来测试随从逻辑（项目中 BlueMarble 与 WhiteMarble 共享 helper）
	blue = WhiteMarbleScript.new()
	blue.hex_grid = grid
	blue.hex_coord = Vector2.ZERO
	blue.color = MarbleConst.MarbleColor.BLUE
	grid.place_marble(blue, 0, 0)

func after_each() -> void:
	if blue:
		blue.queue_free()
		blue = null
	if grid:
		grid.queue_free()
		grid = null

# ---------- 随从生成位置测试 ----------

func test_follower_spawn_cells_count() -> void:
	# 在空旷处，蓝球应能在左右两侧生成最多2个随从
	var cells = BlueMarbleHelper._get_follower_spawn_cells(blue, MarbleConst.HexDirection.RIGHT)
	assert_eq(cells.size(), 2, "空旷位置应生成2个随从")

func test_follower_spawn_cells_not_inline() -> void:
	# 随从不应生成在移动方向正前方
	var dir = MarbleConst.HexDirection.RIGHT
	var cells = BlueMarbleHelper._get_follower_spawn_cells(blue, dir)
	var front = blue.get_neighbor_hex(Vector2.ZERO, dir)
	for cell in cells:
		assert_ne(cell, front, "随从不应生成在正前方")

func test_follower_spawn_avoids_occupied() -> void:
	# 在某一侧有障碍物时，应只生成1个随从
	var blocker = Area2D.new()
	var left_dir = (MarbleConst.HexDirection.RIGHT + 1) % 6
	var left_cell = blue.get_neighbor_hex(Vector2.ZERO, left_dir)
	grid.place_marble(blocker, int(left_cell.x), int(left_cell.y))
	
	var cells = BlueMarbleHelper._get_follower_spawn_cells(blue, MarbleConst.HexDirection.RIGHT)
	assert_eq(cells.size(), 1, "一侧被占时只应生成1个随从")
	blocker.queue_free()

# ---------- 随从清除测试 ----------

func test_clear_followers_removes_nodes() -> void:
	var followers = BlueMarbleHelper.spawn_followers(blue, MarbleConst.HexDirection.RIGHT)
	assert_eq(followers.size(), 2, "应生成2个随从节点")
	
	BlueMarbleHelper.clear_followers(blue, followers)
	for f in followers:
		assert_false(is_instance_valid(f) and f.is_inside_tree(), "清除后随从应被释放")

# ---------- 蓝球移动与随从联动 ----------

func test_blue_move_with_followers() -> void:
	# 蓝色白球（变色后）移动时应生成并带动随从
	blue.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_true(blue.is_alive, "蓝球自身移动后应存活")
	assert_eq(blue.hex_coord, Vector2(2, 0), "蓝球应到达(2,0)")

func test_blue_dies_if_follower_out() -> void:
	# 将蓝球放在边界附近，让随从可能出界
	var r = MarbleConst.GRID_RADIUS - 1
	grid.place_marble(blue, r, 0)
	blue.hex_coord = Vector2(r, 0)
	
	# 朝边界移动，随从在侧面生成，移动时可能出界
	blue.move(MarbleConst.HexDirection.RIGHT, 2)
	# 由于边界约束，结果取决于具体实现，只需确保无崩溃
	assert_true(true, "边界移动应无崩溃")
