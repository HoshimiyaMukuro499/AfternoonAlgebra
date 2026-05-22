# GreenMoveStrategy.gd
# 绿色移动策略：移动后推挤相邻弹珠
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	var success = marble._move_step_by_step(direction, steps)
	if success and marble.is_alive:
		var push_range = marble.get("push_range") if "push_range" in marble else 1
		GreenMarbleHelper.push_neighbors(marble, push_range)
	return success

