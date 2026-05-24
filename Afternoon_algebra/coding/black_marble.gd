# BlackMarble.gd
extends Marble2D

# 黄球增益：是否增强（强制移动距离固定为3）
var enhanced: bool = false

# 黑球不能主动移动
func move(direction: int, steps: int) -> void:
	print("黑球不能主动移动，请使用 force_enemy_move() 方法")

# 强制移动敌方弹珠
func force_enemy_move(enemy: Marble2D, approx_direction: int) -> bool:
	return BlackMarbleHelper.force_enemy_move(self, enemy, approx_direction, enhanced)

# 黄球增益：设置增强状态
func set_enhanced(value: bool = true) -> void:
	enhanced = value
	print("黑球已增强，强制移动距离固定为3")
