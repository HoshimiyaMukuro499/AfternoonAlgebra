# GreenMarble.gd
extends Marble2D

# 推挤范围（可被黄球增益提升，初始为1）
@export var push_range: int = 1

func on_after_move(direction: int, steps: int, success: bool) -> void:
	if success and is_alive:
		var _coords = GreenMarbleHelper.push_neighbors(self, push_range)

# 黄球增益：增加推挤范围
func increase_push_range(amount: int = 1) -> void:
	push_range += amount
	print("绿球推挤范围增加至: ", push_range)

# 直接设置推挤范围（用于调试或重置）
func set_push_range(value: int) -> void:
	push_range = value
	print("绿球推挤范围设置为: ", push_range)
