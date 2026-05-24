# test_cross_marble_integration.gd
# 跨球集成测试：在实现完整跨球交互前，验证黄球增益对其它颜色弹珠的影响，
# 以及白球变色后各色移动行为的正确性。
class_name TestCrossMarbleIntegration
extends "res://tests/base_test.gd"

const WhiteMarbleScript := preload("res://white_marble.gd")

var grid: HexGrid2D
var white_blue: Marble2D
var white_green: Marble2D
var white_red: Marble2D
var white_black: Marble2D

func before_each() -> void:
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE

func after_each() -> void:
	_cleanup_marble(white_blue)
	_cleanup_marble(white_green)
	_cleanup_marble(white_red)
	_cleanup_marble(white_black)
	if grid:
		for hex in grid.marbles.keys():
			var m = grid.marbles[hex]
			if is_instance_valid(m):
				m.queue_free()
		grid.marbles.clear()
		grid.queue_free()
		grid = null

func _cleanup_marble(m: Marble2D) -> void:
	if m and is_instance_valid(m):
		if "temp_followers" in m:
			BlueMarbleHelper.clear_followers(m, m.temp_followers)
		m.queue_free()

func _make_white_marble(hex: Vector2, camp: int = MarbleConst.Camp.RED) -> Marble2D:
	var w = WhiteMarbleScript.new()
	w.hex_grid = grid
	w.hex_coord = hex
	w.color = MarbleConst.MarbleColor.WHITE
	w.camp = camp
	grid.place_marble(w, int(hex.x), int(hex.y))
	return w

func _make_marble(hex: Vector2, camp: int, color: int) -> Marble2D:
	var m = Marble2D.new()
	m.hex_grid = grid
	m.hex_coord = hex
	m.color = color
	m.camp = camp
	m.is_alive = true
	grid.place_marble(m, int(hex.x), int(hex.y))
	return m

# ========== 第一组：黄球增益分发 ==========

func test_yellow_boost_blue_sets_follower_safe() -> void:
	var target = _make_white_marble(Vector2(0, 0))
	target.change_color(MarbleConst.MarbleColor.BLUE)
	target.push_range = 1
	target.max_steps = 4
	YellowMarbleHelper.apply_boost(target, MarbleConst.MarbleColor.BLUE)
	assert_true(target.follower_safe, "蓝球增益后 follower_safe 应为 true")

func test_yellow_boost_green_increases_push_range() -> void:
	var target = _make_white_marble(Vector2(0, 0))
	target.change_color(MarbleConst.MarbleColor.GREEN)
	target.push_range = 1
	target.max_steps = 4
	YellowMarbleHelper.apply_boost(target, MarbleConst.MarbleColor.GREEN)
	assert_eq(target.push_range, 2, "绿球增益后 push_range 应为 2")

func test_yellow_boost_red_increases_max_steps() -> void:
	var target = _make_white_marble(Vector2(0, 0))
	target.change_color(MarbleConst.MarbleColor.RED)
	target.push_range = 1
	target.max_steps = 4
	YellowMarbleHelper.apply_boost(target, MarbleConst.MarbleColor.RED)
	assert_eq(target.max_steps, 5, "红球增益后 max_steps 应为 5")

func test_yellow_boost_does_not_affect_other_colors() -> void:
	var target = _make_white_marble(Vector2(0, 0))
	target.change_color(MarbleConst.MarbleColor.BLUE)
	target.push_range = 1
	target.max_steps = 4
	target.follower_safe = false
	YellowMarbleHelper.apply_boost(target, MarbleConst.MarbleColor.GREEN)
	assert_false(target.follower_safe, "对蓝球用 Green 增益不应影响 follower_safe")

# ========== 第二组：白球变色为蓝 ==========

func test_white_changed_to_blue_spawns_followers_on_move() -> void:
	white_blue = _make_white_marble(Vector2(0, 0))
	white_blue.change_color(MarbleConst.MarbleColor.BLUE)
	assert_eq(grid.marbles.size(), 1, "移动前只有白球")
	white_blue.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_eq(white_blue.hex_coord, Vector2(2, 0), "变蓝后应移动到(2,0)")
	assert_true(white_blue.is_alive, "变蓝后应存活")

func test_white_changed_to_blue_followers_follow_movement() -> void:
	white_blue = _make_white_marble(Vector2(0, 0))
	white_blue.change_color(MarbleConst.MarbleColor.BLUE)
	var followers = BlueMarbleHelper.spawn_followers(white_blue, MarbleConst.HexDirection.RIGHT)
	assert_eq(followers.size(), 2, "应生成2个随从")
	var ok = BlueMarbleHelper.move_followers(white_blue, followers, MarbleConst.HexDirection.RIGHT, 2)
	assert_true(ok, "随从应成功移动2步")
	BlueMarbleHelper.clear_followers(white_blue, followers)

func test_white_changed_to_blue_move_collision() -> void:
	white_blue = _make_white_marble(Vector2(0, 0))
	white_blue.change_color(MarbleConst.MarbleColor.BLUE)
	var enemy = _make_marble(Vector2(2, 0), MarbleConst.Camp.BLUE, MarbleConst.MarbleColor.WHITE)
	white_blue.move(MarbleConst.HexDirection.RIGHT, 3)
	assert_eq(grid.get_marble_at(1, 0), white_blue, "碰撞后白球应在(1,0)")
	assert_eq(grid.get_marble_at(4, 0), enemy, "被撞者应在(4,0)")
	assert_true(white_blue.is_alive, "碰撞后白球应存活")
	enemy.queue_free()

# ========== 第三组：白球变色为绿 ==========

func test_white_changed_to_green_pushes_neighbors() -> void:
	white_green = _make_white_marble(Vector2(0, 0))
	white_green.change_color(MarbleConst.MarbleColor.GREEN)
	white_green.push_range = 1
	white_green.max_steps = 4
	var neighbor1 = _make_marble(Vector2(1, 0), MarbleConst.Camp.BLUE, MarbleConst.MarbleColor.WHITE)
	var neighbor2 = _make_marble(Vector2(0, 1), MarbleConst.Camp.BLUE, MarbleConst.MarbleColor.WHITE)
	white_green.move(MarbleConst.HexDirection.RIGHT, 1)
	assert_eq(white_green.hex_coord, Vector2(1, 0), "绿球应到(1,0)")
	assert_eq(neighbor1.hex_coord, Vector2(2, 0), "neighbor1 被推至(2,0)")
	assert_eq(neighbor2.hex_coord, Vector2(0, 1), "neighbor2 不应被推")
	neighbor1.queue_free()
	neighbor2.queue_free()

func test_white_changed_to_green_push_kills_if_out_of_bounds() -> void:
	white_green = _make_white_marble(Vector2(0, 0))
	white_green.change_color(MarbleConst.MarbleColor.GREEN)
	white_green.push_range = 1
	white_green.max_steps = 4
	var r = MarbleConst.GRID_RADIUS
	grid.place_marble(white_green, r - 1, 0)
	white_green.hex_coord = Vector2(r - 1, 0)
	var victim = _make_marble(Vector2(r, 0), MarbleConst.Camp.BLUE, MarbleConst.MarbleColor.WHITE)
	white_green.move(MarbleConst.HexDirection.RIGHT, 1)
	assert_true(white_green.is_alive, "绿球应存活")
	assert_false(victim.is_alive, "被推挤出界的弹珠应死亡")

# ========== 第四组：白球变色为红 ==========

func test_white_changed_to_red_move_with_max_steps_limited() -> void:
	white_red = _make_white_marble(Vector2(0, 0))
	white_red.change_color(MarbleConst.MarbleColor.RED)
	white_red.push_range = 1
	white_red.max_steps = 4
	white_red.move(MarbleConst.HexDirection.RIGHT, 5)
	assert_eq(white_red.hex_coord, Vector2(4, 0), "max_steps=4 应到(4,0)")

func test_white_changed_to_red_collision_triggers_continue() -> void:
	white_red = _make_white_marble(Vector2(0, 0))
	white_red.change_color(MarbleConst.MarbleColor.RED)
	white_red.push_range = 1
	white_red.max_steps = 4
	var target = _make_marble(Vector2(2, 0), MarbleConst.Camp.BLUE, MarbleConst.MarbleColor.WHITE)
	white_red.move(MarbleConst.HexDirection.RIGHT, 3)
	assert_eq(white_red.hex_coord, Vector2(1, 0), "红球碰撞后应停(1,0)")
	assert_true(target.is_alive, "被撞者应存活")
	assert_eq(target.hex_coord, Vector2(4, 0), "被撞者应到(4,0)")
	target.queue_free()

# ========== 第五组：白球变色为黑 ==========

func test_white_changed_to_black_cannot_move() -> void:
	white_black = _make_white_marble(Vector2(0, 0))
	white_black.change_color(MarbleConst.MarbleColor.BLACK)
	var old_pos = white_black.hex_coord
	white_black.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_eq(white_black.hex_coord, old_pos, "黑球不应移动")

func test_white_changed_to_black_still_on_grid() -> void:
	white_black = _make_white_marble(Vector2(0, 0))
	white_black.change_color(MarbleConst.MarbleColor.BLACK)
	white_black.move(MarbleConst.HexDirection.RIGHT, 2)
	assert_true(white_black.is_alive, "黑球应存活")
	assert_eq(grid.get_marble_at(0, 0), white_black, "黑球仍在原位置")

func test_white_changed_to_black_can_be_collided_into() -> void:
	white_black = _make_white_marble(Vector2(1, 0))
	white_black.change_color(MarbleConst.MarbleColor.BLACK)
	var attacker = _make_marble(Vector2(0, 0), MarbleConst.Camp.BLUE, MarbleConst.MarbleColor.WHITE)
	attacker.move(MarbleConst.HexDirection.RIGHT, 3)
	assert_true(white_black.is_alive, "碰撞后黑球应存活")
	assert_eq(white_black.hex_coord, Vector2(4, 0), "黑球被碰撞后应到(4,0)")
	attacker.queue_free()

# ========== 第六组：黄球增益+变色 ==========

func test_yellow_boost_then_white_change_preserves_boost() -> void:
	var target = _make_white_marble(Vector2(0, 0))
	target.change_color(MarbleConst.MarbleColor.BLUE)
	target.push_range = 1
	target.max_steps = 4
	target.follower_safe = false
	YellowMarbleHelper.apply_boost(target, MarbleConst.MarbleColor.BLUE)
	assert_true(target.follower_safe, "黄球增益后 follower_safe=true")
	target.change_color(MarbleConst.MarbleColor.GREEN)
	assert_true(target.is_alive, "变色后弹珠存活")
	assert_eq(target.color, MarbleConst.MarbleColor.GREEN, "颜色变为绿色")

func test_white_change_from_boosted_to_red_preserves_max_steps() -> void:
	var target = _make_white_marble(Vector2(0, 0))
	target.change_color(MarbleConst.MarbleColor.RED)
	target.push_range = 1
	target.max_steps = 4
	var initial_max = target.max_steps
	YellowMarbleHelper.apply_boost(target, MarbleConst.MarbleColor.RED)
	assert_eq(target.max_steps, initial_max + 1, "增益后 max_steps+1")
	target.move(MarbleConst.HexDirection.RIGHT, 6)
	assert_eq(target.hex_coord, Vector2(initial_max + 1, 0), "移动受增益后 max_steps 限制")

# ========== 第七组：变色后碰撞交互 ==========

func test_changed_blue_collision_as_target_no_bonus() -> void:
	white_blue = _make_white_marble(Vector2(0, 0))
	white_blue.change_color(MarbleConst.MarbleColor.BLUE)
	var ally = _make_marble(Vector2(-1, 0), MarbleConst.Camp.RED, MarbleConst.MarbleColor.WHITE)
	var steps = white_blue.on_collision_as_target(ally, 2, MarbleConst.HexDirection.RIGHT)
	assert_eq(steps, 2, "变蓝后被友方碰撞不应有步数加成")
	ally.queue_free()

# ========== 第八组：多色白球棋盘状态 ==========

func test_multiple_changed_whites_on_grid() -> void:
	white_blue = _make_white_marble(Vector2(0, 0))
	white_blue.change_color(MarbleConst.MarbleColor.BLUE)
	white_green = _make_white_marble(Vector2(3, 0))
	white_green.change_color(MarbleConst.MarbleColor.GREEN)
	white_green.push_range = 1
	white_green.max_steps = 4
	white_blue.move(MarbleConst.HexDirection.RIGHT, 2)
	white_green.move(MarbleConst.HexDirection.LEFT, 1)
	assert_true(white_blue.is_alive, "变蓝白球存活")
	assert_true(white_green.is_alive, "变绿白球存活")

func test_changed_white_initial_position() -> void:
	white_red = _make_white_marble(Vector2(5, -2))
	white_red.change_color(MarbleConst.MarbleColor.RED)
	white_red.push_range = 1
	white_red.max_steps = 4
	assert_eq(grid.get_marble_at(5, -2), white_red, "变色后弹珠应在初始位置")
