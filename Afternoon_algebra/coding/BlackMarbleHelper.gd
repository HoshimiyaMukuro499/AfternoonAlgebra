# BlackMarbleHelper.gd
# 黑球（干扰）公用逻辑，供 BlackMarble 和 WhiteMarble（变色后）复用

class_name BlackMarbleHelper
extends RefCounted

# 强制移动敌方弹珠
# 返回值：是否成功移动
static func force_enemy_move(marble: Marble2D, enemy: Marble2D, approx_direction: int, enhanced: bool) -> bool:
	if not marble.is_alive:
		return false
	if enemy == null or not enemy.is_alive:
		return false
	if enemy.camp == marble.camp:
		return false
	
	# 随机选择实际方向（指定方向 ±60°）
	var actual_dir = _get_random_direction(approx_direction)
	
	# 随机选择移动步数（2或3，增强后固定为3）
	var steps = 3 if enhanced else (2 if randi() % 2 == 0 else 3)
	
	# 强制移动敌方弹珠
	enemy.continue_move(steps, actual_dir)
	return true


# 随机选择方向（从指定方向及其左右偏移）
static func _get_random_direction(base_dir: int) -> int:
	var offset = randi() % 3 - 1
	var result = (base_dir + offset) % 6
	if result < 0:
		result += 6
	return result
