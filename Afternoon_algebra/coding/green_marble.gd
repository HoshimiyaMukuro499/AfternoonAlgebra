# GreenMarble.gd
extends Marble2D

# 推挤范围（可被黄球增益提升，初始为1）
var push_range: int = 1

func on_after_move(direction: int, steps: int, success: bool) -> void:
	if success and is_alive:
		GreenMarbleHelper.push_neighbors(self, push_range)

# 黄球增益：增加推挤范围
func increase_push_range(amount: int = 1) -> void:
	push_range += amount
	print("绿球推挤范围增加至: ", push_range)
