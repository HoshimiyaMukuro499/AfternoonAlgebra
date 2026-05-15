# test_blue_marble.gd
# 测试 BlueMarble 蓝球及随从机制（验证棋盘状态）
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
	# 清理所有可能残留的随从
	if blue and is_instance_valid(blue):
		BlueMarbleHelper.clear_followers(blue, blue.temp_followers)
		blue.queue_free()
		blue = null
	if grid:
		for hex in grid.marbles.keys():
			var m = grid.marbles[hex]
			if is_instance_valid(m) and m != blue:
				m.queue_free()
		grid.marbles.clear()
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
	# 在某一侧有障碍物时，应从其他方向补足到2个
	var blocker = Area2D.new()
	var left_dir = (MarbleConst.HexDirection.RIGHT + 1) % 6
	var left_cell = blue.get_neighbor_hex(Vector2.ZERO, left_dir)
	grid.place_marble(blocker, int(left_cell.x), int(left_cell.y))
	
	var cells = BlueMarbleHelper._get_follower_spawn_cells(blue, MarbleConst.HexDirection.RIGHT)
	# 代码会从其他不共线方向随机补足到2个
	assert_eq(cells.size(), 2, "一侧被占时会从其他方向补足到2个")
	# 确保没有生成在被占据的格子上
	for cell in cells:
		assert_ne(cell, left_cell, "不应生成在被占据的格子上")
	blocker.queue_free()

# ---------- 随从在棋盘上的生成与位置测试 ----------

func test_followers_are_placed_on_grid() -> void:
	var followers = BlueMarbleHelper.spawn_followers(blue, MarbleConst.HexDirection.RIGHT)
	assert_eq(followers.size(), 2, "应生成2个随从节点")
	
	for f in followers:
		var hex = grid.get_marble_hex(f)
		assert_not_null(grid.get_marble_at(int(hex.x), int(hex.y)), "每个随从应在棋盘上有记录")
		assert_eq(grid.get_marble_at(int(hex.x), int(hex.y)), f, "棋盘上记录的应是该随从节点")
	
	BlueMarbleHelper.clear_followers(blue, followers)

func test_follower_positions_match_hex_coords() -> void:
	var followers = BlueMarbleHelper.spawn_followers(blue, MarbleConst.HexDirection.RIGHT)
	for f in followers:
		var hex = grid.get_marble_hex(f)
		var expected_world = grid.hex_to_world(int(hex.x), int(hex.y))
		assert_almost_eq(f.position.x, expected_world.x, 0.001, "随从世界x坐标应与六边形坐标匹配")
		assert_almost_eq(f.position.y, expected_world.y, 0.001, "随从世界y坐标应与六边形坐标匹配")
	
	BlueMarbleHelper.clear_followers(blue, followers)

# ---------- 随从清除测试 ----------

func test_clear_followers_removes_nodes() -> void:
	var followers = BlueMarbleHelper.spawn_followers(blue, MarbleConst.HexDirection.RIGHT)
	assert_eq(followers.size(), 2, "应生成2个随从节点")
	
	BlueMarbleHelper.clear_followers(blue, followers)
	for f in followers:
		assert_false(is_instance_valid(f) and f.is_inside_tree(), "清除后随从应被释放")

func test_clear_followers_removes_from_grid() -> void:
	var followers = BlueMarbleHelper.spawn_followers(blue, MarbleConst.HexDirection.RIGHT)
	var follower_hexes = []
	for f in followers:
		follower_hexes.append(grid.get_marble_hex(f))
	
	BlueMarbleHelper.clear_followers(blue, followers)
	
	for hex in follower_hexes:
		assert_null(grid.get_marble_at(int(hex.x), int(hex.y)), "清除后随从应从棋盘消失")

# ---------- 蓝球移动与随从联动（棋盘状态验证） ----------

func test_blue_move_with_followers() -> void:
	# 蓝色白球（变色后）移动时应生成并带动随从
	blue.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_true(blue.is_alive, "蓝球自身移动后应存活")
	assert_eq(blue.hex_coord, Vector2(2, 0), "蓝球应到达(2,0)")
	# 随从应在移动后被清除
	assert_eq(blue.temp_followers.size(), 0, "移动后随从列表应被清空")

func test_blue_move_updates_follower_grid_positions() -> void:
	# 生成随从并记录它们在棋盘上的初始位置
	var followers = BlueMarbleHelper.spawn_followers(blue, MarbleConst.HexDirection.RIGHT)
	var old_hexes = []
	for f in followers:
		old_hexes.append(grid.get_marble_hex(f))
	
	# 移动蓝球和随从
	BlueMarbleHelper.move_followers(blue, followers, MarbleConst.HexDirection.RIGHT, 2)
	
	# 验证旧位置已空
	for hex in old_hexes:
		assert_null(grid.get_marble_at(int(hex.x), int(hex.y)), "随从移动后旧位置应为空")
	
	# 验证随从到达新位置
	for f in followers:
		var new_hex = grid.get_marble_hex(f)
		assert_eq(grid.get_marble_at(int(new_hex.x), int(new_hex.y)), f, "随从新位置应在棋盘上")
	
	BlueMarbleHelper.clear_followers(blue, followers)

func test_blue_dies_if_follower_out() -> void:
	# 将蓝球放在边界附近，让随从可能出界
	var r = MarbleConst.GRID_RADIUS - 1
	grid.place_marble(blue, r, 0)
	blue.hex_coord = Vector2(r, 0)
	
	# 朝边界移动，随从在侧面生成，移动时可能出界
	blue.move(MarbleConst.HexDirection.RIGHT, 2)
	# 蓝球或随从出界时蓝球应死亡
	assert_false(blue.is_alive, "随从出界时蓝球应死亡")

func test_blue_survives_when_followers_safe() -> void:
	# 将蓝球放在中心附近，随从不会出界
	grid.place_marble(blue, 0, 0)
	blue.hex_coord = Vector2.ZERO
	
	blue.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_true(blue.is_alive, "中心位置移动后蓝球应存活")
	assert_eq(blue.hex_coord, Vector2(2, 0), "蓝球应正确移动")

func test_board_clean_after_blue_move() -> void:
	# 验证蓝球移动后棋盘上只有蓝球，没有残留随从
	grid.place_marble(blue, 0, 0)
	blue.hex_coord = Vector2.ZERO
	
	blue.move(MarbleConst.HexDirection.RIGHT, 2)
	
	# 统计棋盘上活着的节点
	var alive_count = 0
	for hex in grid.marbles.keys():
		var m = grid.marbles[hex]
		if is_instance_valid(m):
			alive_count += 1
	
	assert_eq(alive_count, 1, "移动后棋盘上只应有蓝球自己")
	assert_eq(grid.get_marble_at(2, 0), blue, "蓝球应在最终位置")
