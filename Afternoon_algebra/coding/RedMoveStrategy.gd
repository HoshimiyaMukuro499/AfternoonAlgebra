# RedMoveStrategy.gd
# 红色移动策略：逐格移动（每步可不同方向）
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	var max_steps = marble.get("max_steps") if "max_steps" in marble else 5
	var actual_steps = min(steps, max_steps)
	# 红球策略（用于白球变色后）使用基础逐格移动，不涉及逐格选方向
	return marble._move_step_by_step(direction, actual_steps)

