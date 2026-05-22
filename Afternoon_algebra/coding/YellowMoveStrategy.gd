# YellowMoveStrategy.gd
# 黄色移动策略：步数随机 ±1
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	var actual_steps = YellowMarbleHelper.get_randomized_steps(steps)
	print("黄球移动：原力度 ", steps, "，实际力度 ", actual_steps)
	return marble._move_step_by_step(direction, actual_steps)

