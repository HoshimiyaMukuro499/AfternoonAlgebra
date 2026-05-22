# GreenMarbleHelper.gd
# 绿球（推挤）公用逻辑，供 GreenMarble 和 WhiteMarble（变色后）复用
#
# 推挤规则（同时结算）：
# 1. 绿球停止后，检查其相邻6个格点。
# 2. 对每个相邻格上的弹珠（不分敌我），将其沿远离绿球的方向推开1格。
# 3. 若目标格被占据，则推开失败，该弹珠停留在原处且不死亡。
# 4. 若目标格出界，该弹珠死亡。
# 5. 所有推开同时结算（即不会因A推开后占用了B的目标格而影响B）。

class_name GreenMarbleHelper
extends RefCounted

# 推挤相邻格子的弹珠（同时结算）
static func push_neighbors(marble: Marble2D, push_range: int) -> void:
	var current_hex = marble.get_current_hex()
	# 存储推挤数据：{ marble, from_hex, to_hex, will_die }
	var pushes: Array[Dictionary] = []
	
	# 第一步：收集所有推挤信息，基于当前棋盘状态（同时结算）
	for dir in range(6):
		var neighbor_hex = marble.get_neighbor_hex(current_hex, dir)
		var other = marble.hex_grid.get_marble_at(neighbor_hex.x, neighbor_hex.y)
		
		if other == null or not other.is_alive:
			continue
		
		# 推挤方向：从绿球指向相邻弹珠的方向（即远离绿球的方向）
		# 目标格子 = 相邻格子 + (相邻格子 - 绿球格子) = 2*相邻格子 - 绿球格子
		var target_hex = neighbor_hex + (neighbor_hex - current_hex)
		
		var will_die = marble.hex_grid.is_out_of_bounds(target_hex.x, target_hex.y)
		var blocked = false
		if not will_die:
			var occupant = marble.hex_grid.get_marble_at(target_hex.x, target_hex.y)
			if occupant != null and occupant.is_alive:
				blocked = true
		
		pushes.append({
			"marble": other,
			"from": neighbor_hex,
			"to": target_hex,
			"will_die": will_die,
			"blocked": blocked
		})
	
	# 第二步：同时执行所有推挤（不依赖中间状态）
	for push in pushes:
		var pushed: Marble2D = push.marble
		var from_hex: Vector2 = push.from
		var to_hex: Vector2 = push.to
		var will_die: bool = push.will_die
		var blocked: bool = push.blocked
		
		if will_die:
			pushed.die()
		elif blocked:
			# 目标格被占据，推挤失败，弹珠留在原处
			pass
		else:
			# 执行推挤移动
			marble.hex_grid.move_marble(pushed, from_hex, to_hex)


# 计算推挤方向（从推挤源指向被推弹珠的方向）
static func _get_push_direction(from_hex: Vector2, to_hex: Vector2) -> int:
	var diff = to_hex - from_hex
	for dir in range(6):
		if _get_neighbor_hex(Vector2.ZERO, dir) == diff:
			return dir
	return 0


static func _get_neighbor_hex(hex: Vector2, dir: int) -> Vector2:
	var dirs = [
		Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
		Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1)
	]
	return hex + dirs[dir]
