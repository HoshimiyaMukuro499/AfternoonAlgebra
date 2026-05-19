# RedMoveStrategy.gd
# 红色移动策略：逐格移动（每步可不同方向）
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	var max_steps = marble.get("max_steps") if "max_steps" in marble else 4
	var actual_steps = min(steps, max_steps)
	var dirs = []
	for i in range(actual_steps):
		dirs.append(direction)
	return RedMarbleHelper.move_with_step_directions(marble, dirs, actual_steps)

