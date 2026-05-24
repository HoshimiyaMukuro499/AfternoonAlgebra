# RedMarble.gd
extends Marble2D

# 最大移动步数（可被黄球增益提升，初始为4）
var max_steps: int = 4

func move(direction: int, steps: int) -> void:
	# 红球移动由 GameManager 通过 RedMarbleHelper 逐格控制，此方法不应被直接调用
	print("红球移动应由 GameManager 控制，请勿直接调用 move()")

# 黄球增益：增加最大步数
func increase_max_steps(amount: int = 1) -> void:
	max_steps += amount
	print("红球最大步数增加至: ", max_steps)
