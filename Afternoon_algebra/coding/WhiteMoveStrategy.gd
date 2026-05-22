# WhiteMoveStrategy.gd
# 白色移动策略：基础移动，被友方碰撞时步数+1
extends "res://MoveStrategyBase.gd"

# 确保 MarbleConst 可用（如果未自动加载）
const MarbleConst = preload("res://MarbleConst.gd.gd")

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	return marble._move_step_by_step(direction, steps)

func on_collision_as_target(marble: Marble2D, collider: Marble2D, incoming_steps: int, direction: int) -> int:
	# 只有当前颜色为白色时才触发步数加成
	if marble.color == MarbleConst.MarbleColor.WHITE and collider.camp == marble.camp:
		return incoming_steps + 1
	return incoming_steps

