# WhiteMoveStrategy.gd
# 白色移动策略：基础移动，被友方碰撞时步数+1
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	return marble._move_step_by_step(direction, steps)

func on_collision_as_target(marble: Marble2D, collider: Marble2D, incoming_steps: int, direction: int) -> int:
	if collider.camp == marble.camp:
		return incoming_steps + 1
	return incoming_steps

