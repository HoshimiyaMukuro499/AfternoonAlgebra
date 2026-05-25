# BlackMoveStrategy.gd
# 黑色移动策略：不能主动移动
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	print("当前颜色为黑色，不能主动移动")
	return false
