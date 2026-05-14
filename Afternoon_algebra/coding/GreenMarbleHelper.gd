# GreenMarbleHelper.gd
# 绿球（推挤）公用逻辑，供 GreenMarble 和 WhiteMarble（变色后）复用

class_name GreenMarbleHelper
extends RefCounted

# 推挤相邻格子的弹珠（同时结算）
static func push_neighbors(marble: Marble2D, push_range: int) -> void:
	var current_hex = marble.get_current_hex()
	var pushes = []  # 存储 (弹珠, 从格子, 到格子)
	
	# 检查6个方向
	for dir in range(6):
		var neighbor_hex = marble.get_neighbor_hex(current_hex, dir)
		var other = marble.hex_grid.get_marble_at(neighbor_hex.x, neighbor_hex.y)
		
		if other != null and other.is_alive:
			var push_dir = _get_push_direction(current_hex, neighbor_hex)
			var target_hex = marble.get_neighbor_hex(neighbor_hex, push_dir)
			
			pushes.append({
				"marble": other,
				"from": neighbor_hex,
				"to": target_hex
			})
	
	# 同时结算所有推挤
	for push in pushes:
		_execute_push(marble, push.marble, push.from, push.to)


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


# 执行单个推挤
static func _execute_push(marble: Marble2D, pushed: Marble2D, from_hex: Vector2, to_hex: Vector2) -> void:
	# 检查目标格子是否出界
	if marble.hex_grid.is_out_of_bounds(to_hex.x, to_hex.y):
		pushed.die()
		return
	
	# 检查目标格子是否被占据
	var occupant = marble.hex_grid.get_marble_at(to_hex.x, to_hex.y)
	if occupant != null and occupant.is_alive:
		return  # 推挤失败
	
	# 执行推挤移动
	marble.hex_grid.move_marble(pushed, from_hex, to_hex)
