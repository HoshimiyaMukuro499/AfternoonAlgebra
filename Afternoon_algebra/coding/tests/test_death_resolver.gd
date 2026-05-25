# test_death_resolver.gd
# 测试 DeathResolver.resolve_simultaneous_deaths 纯函数逻辑
class_name TestDeathResolver
extends "res://tests/base_test.gd"

const DeathResolverScript = preload("res://DeathResolver.gd")

# ---------- 辅助方法 ----------

func _make_death(color: int, camp: int) -> Dictionary:
	return { "color": color, "camp": camp }

func _make_white(id: int, camp: int, has_changed: bool = false, current_color: int = -1) -> Dictionary:
	if current_color == -1:
		current_color = MarbleConst.MarbleColor.WHITE
	return { "id": id, "camp": camp, "has_changed": has_changed, "current_color": current_color }

func call_resolve(death_events: Array, white_marbles: Array) -> Array:
	return DeathResolverScript.resolve_simultaneous_deaths(death_events, white_marbles)

# ---------- 基础功能测试 ----------

func test_no_deaths_returns_empty() -> void:
	var result = call_resolve([], [])
	assert_eq(result.size(), 0, "无死亡事件应返回空列表")

func test_no_white_marbles_returns_empty() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)]
	var result = call_resolve(deaths, [])
	assert_eq(result.size(), 0, "无白球时应返回空列表")

func test_single_death_single_white() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)]
	var whites = [_make_white(1, MarbleConst.Camp.RED)]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 1, "应返回一个变色事件")
	assert_eq(result[0]["white_id"], 1, "白球ID应为1")
	assert_eq(result[0]["from_color"], MarbleConst.MarbleColor.WHITE, "原色应为白色")
	assert_eq(result[0]["to_color"], MarbleConst.MarbleColor.BLUE, "目标色应为蓝色")

# ---------- 阵营分组测试 ----------

func test_only_same_camp_white_changes() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)]
	var whites = [
		_make_white(1, MarbleConst.Camp.BLUE),
		_make_white(2, MarbleConst.Camp.RED)
	]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 1, "只应红方有变色")
	assert_eq(result[0]["white_id"], 2, "应选红方白球")
	assert_eq(result[0]["to_color"], MarbleConst.MarbleColor.BLUE, "目标色应为蓝色")

func test_two_camps_death_each() -> void:
	var deaths = [
		_make_death(MarbleConst.MarbleColor.RED, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.BLUE)
	]
	var whites = [
		_make_white(1, MarbleConst.Camp.RED),
		_make_white(2, MarbleConst.Camp.BLUE)
	]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 2, "双方都应变色")
	
	var red_change = result[0] if result[0]["white_id"] == 1 else result[1]
	var blue_change = result[0] if result[0]["white_id"] == 2 else result[1]
	assert_eq(red_change["to_color"], MarbleConst.MarbleColor.RED)
	assert_eq(blue_change["to_color"], MarbleConst.MarbleColor.BLUE)

# ---------- 黄球过滤测试 ----------

func test_yellow_death_no_trigger() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.YELLOW, MarbleConst.Camp.RED)]
	var whites = [_make_white(1, MarbleConst.Camp.RED)]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 0, "黄球死亡不应触发变色")

func test_mixed_yellow_and_other() -> void:
	var deaths = [
		_make_death(MarbleConst.MarbleColor.YELLOW, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)
	]
	var whites = [_make_white(1, MarbleConst.Camp.RED)]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 1, "只有非黄球死亡触发变色")
	assert_eq(result[0]["to_color"], MarbleConst.MarbleColor.BLUE, "目标色应为蓝色")

# ---------- 优先未变色白球测试 ----------

func test_prefer_uncolored_white() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)]
	var whites = [
		_make_white(1, MarbleConst.Camp.RED, true, MarbleConst.MarbleColor.GREEN),
		_make_white(2, MarbleConst.Camp.RED, false)
	]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 1, "应返回一个变色事件")
	assert_eq(result[0]["white_id"], 2, "应优先选未变色白球")

func test_fallback_to_colored_white() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)]
	var whites = [
		_make_white(1, MarbleConst.Camp.RED, true, MarbleConst.MarbleColor.GREEN),
		_make_white(2, MarbleConst.Camp.RED, true, MarbleConst.MarbleColor.RED)
	]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 1, "应返回一个变色事件")
	assert_eq(result[0]["white_id"], 1, "应选第一个已变色白球覆盖")
	assert_eq(result[0]["to_color"], MarbleConst.MarbleColor.BLUE, "目标色应为蓝色")
	assert_eq(result[0]["from_color"], MarbleConst.MarbleColor.GREEN, "原色应为被覆盖的颜色")

# ---------- 多死亡事件 vs 多白球测试 ----------
# 注意：规则规定同一时刻多颗死亡只变一个白球，且随机选一种死亡颜色。
# 以下测试验证这个行为。

func test_two_deaths_two_whites() -> void:
	# 多个死亡同时发生时，只产生一个变色事件（随机选一种颜色）
	var deaths = [
		_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.GREEN, MarbleConst.Camp.RED)
	]
	var whites = [
		_make_white(1, MarbleConst.Camp.RED),
		_make_white(2, MarbleConst.Camp.RED)
	]
	var result = call_resolve(deaths, whites)
	
	# 同一时刻多颗死亡，只变一个白球
	assert_eq(result.size(), 1, "两个同时死亡只应产生一个变色事件")
	
	# 目标色应该是蓝色或绿色（随机选择）
	var ok_color = (result[0]["to_color"] == MarbleConst.MarbleColor.BLUE or
					result[0]["to_color"] == MarbleConst.MarbleColor.GREEN)
	assert_true(ok_color, "目标色应为蓝色或绿色之一（随机）")
	
	# 应该优先选未变色的白球
	assert_eq(result[0]["white_id"], 1, "应优先选编号小的未变色白球")

func test_two_deaths_one_white() -> void:
	# 多个死亡同时发生，只有一个白球：只产生一个变色事件
	var deaths = [
		_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.GREEN, MarbleConst.Camp.RED)
	]
	var whites = [_make_white(1, MarbleConst.Camp.RED)]
	var result = call_resolve(deaths, whites)
	
	# 只产生一个变色事件（随机选一种死亡颜色）
	assert_eq(result.size(), 1, "两个同时死亡只应产生一个变色事件")
	
	assert_eq(result[0]["white_id"], 1, "变色应为白球1")
	assert_eq(result[0]["from_color"], MarbleConst.MarbleColor.WHITE, "原色为白色")
	
	# 目标色应该是蓝色或绿色（随机选择）
	var ok_color = (result[0]["to_color"] == MarbleConst.MarbleColor.BLUE or
					result[0]["to_color"] == MarbleConst.MarbleColor.GREEN)
	assert_true(ok_color, "目标色应为蓝色或绿色之一（随机）")

# ---------- 多个阵营各自处理测试 ----------

func test_complex_multi_camp() -> void:
	# 同一时刻多个死亡：红方2死、蓝方3死（含1黄球）
	# 规则：每个阵营只产生一个变色事件，黄球死亡不触发变色
	# 红方：从 {RED, BLUE} 中随机选一种 → 白球1或2变色
	# 蓝方：从 {GREEN, BLACK} 中随机选一种（YELLOW被过滤）→ 白球3变色
	var deaths = [
		_make_death(MarbleConst.MarbleColor.RED, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.GREEN, MarbleConst.Camp.BLUE),
		_make_death(MarbleConst.MarbleColor.YELLOW, MarbleConst.Camp.BLUE),
		_make_death(MarbleConst.MarbleColor.BLACK, MarbleConst.Camp.BLUE)
	]
	var whites = [
		_make_white(1, MarbleConst.Camp.RED),
		_make_white(2, MarbleConst.Camp.RED),
		_make_white(3, MarbleConst.Camp.BLUE)
	]
	var result = call_resolve(deaths, whites)
	
	# 每个阵营只产生一个变色事件，共2个
	assert_eq(result.size(), 2, "应有2个变色事件（每个阵营1个）")
	
	var red_change = result.filter(func(c): return c["white_id"] == 1 or c["white_id"] == 2)
	assert_eq(red_change.size(), 1, "红方应有1个变色")
	var red_color_ok = (red_change[0]["to_color"] == MarbleConst.MarbleColor.RED or
						red_change[0]["to_color"] == MarbleConst.MarbleColor.BLUE)
	assert_true(red_color_ok, "红方目标色应为红色或蓝色之一（随机）")
	
	var blue_change = result.filter(func(c): return c["white_id"] == 3)
	assert_eq(blue_change.size(), 1, "蓝方应有1个变色")
	var blue_color_ok = (blue_change[0]["to_color"] == MarbleConst.MarbleColor.GREEN or
						 blue_change[0]["to_color"] == MarbleConst.MarbleColor.BLACK)
	assert_true(blue_color_ok, "蓝方目标色应为绿色或黑色之一（随机，黄球被过滤）")

# ---------- 边界情况测试 ----------

func test_wrong_camp_death_ignored() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.BLUE, MarbleConst.Camp.RED)]
	var whites = [_make_white(1, MarbleConst.Camp.BLUE)]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 0, "红方死亡不应触发蓝方白球变色")

func test_empty_death_events_still_ok() -> void:
	var whites = [_make_white(1, MarbleConst.Camp.RED)]
	var result = call_resolve([], whites)
	
	assert_eq(result.size(), 0, "无死亡事件应返回空列表")

func test_only_yellow_deaths_returns_empty() -> void:
	var deaths = [
		_make_death(MarbleConst.MarbleColor.YELLOW, MarbleConst.Camp.RED),
		_make_death(MarbleConst.MarbleColor.YELLOW, MarbleConst.Camp.BLUE)
	]
	var whites = [_make_white(1, MarbleConst.Camp.RED), _make_white(2, MarbleConst.Camp.BLUE)]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 0, "只有黄球死亡应返回空列表")

# ---------- 不变色情况测试 ----------

func test_white_death_self_does_not_change() -> void:
	var deaths = [_make_death(MarbleConst.MarbleColor.WHITE, MarbleConst.Camp.RED)]
	var whites = [_make_white(2, MarbleConst.Camp.RED)]
	var result = call_resolve(deaths, whites)
	
	assert_eq(result.size(), 1, "白球死亡仍可触发其他存活白球变色")
	assert_eq(result[0]["white_id"], 2, "存活白球应变色")
	assert_eq(result[0]["to_color"], MarbleConst.MarbleColor.WHITE, "目标色应为白色")
