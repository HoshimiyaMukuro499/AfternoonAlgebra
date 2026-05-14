# RedMarble.gd
extends Marble2D

# 最大移动步数（可被黄球增益提升，初始为4）
var max_steps: int = 4

func move(direction: int, steps: int) -> void:
	var actual_steps = min(steps, max_steps)
	var dirs = []
	for i in range(actual_steps):
		dirs.append(direction)
	on_before_move(direction, actual_steps)
	var success = RedMarbleHelper.move_with_step_directions(self, dirs, actual_steps)
	on_after_move(direction, actual_steps, success)

# 黄球增益：增加最大步数
func increase_max_steps(amount: int = 1) -> void:
	max_steps += amount
	print("红球最大步数增加至: ", max_steps)
