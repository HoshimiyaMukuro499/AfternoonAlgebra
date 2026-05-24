# GreenMarbleHelper.gd
# 绿球（推挤）公用逻辑，供 GreenMarble 和 WhiteMarble（变色后）复用
#
# 推挤规则（同时结算）：
# 1. 绿球停止后，检查其相邻6个格点。
# 2. 对每个相邻格上的弹珠（不分敌我），调用其 continue_move(1, direction) 向外移动一格。
# 3. 返回被推挤弹珠移动后的坐标列表（顺序对应方向0~5，无弹珠则跳过）。

class_name GreenMarbleHelper
extends RefCounted

# 推挤相邻格子的弹珠（同时结算），返回被推挤弹珠移动后的坐标列表
static func push_neighbors(marble: Marble2D, push_range: int) -> Array[Vector2]:
	var current_hex = marble.get_current_hex()
	var result: Array[Vector2] = []
	
	for dir in range(6):
		var neighbor_hex = marble.get_neighbor_hex(current_hex, dir)
		var other = marble.hex_grid.get_marble_at(neighbor_hex.x, neighbor_hex.y)
		
		if other == null or not other.is_alive:
			continue
		
		# 方向 dir 即为远离绿球的方向
		var success = other.continue_move(1, dir)
		if success and other.is_alive:
			result.append(other.get_current_hex())
		else:
			# 移动失败（死亡），记录 Vector2.ZERO 表示无效
			result.append(Vector2.ZERO)
	
	return result
