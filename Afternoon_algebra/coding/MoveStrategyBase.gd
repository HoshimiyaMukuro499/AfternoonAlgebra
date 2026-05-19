# MoveStrategyBase.gd
# 弹珠移动策略基类，定义各颜色移动行为的接口
extends RefCounted

# 执行移动，返回是否成功
func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	push_error("MoveStrategyBase.execute() 未实现")
	return false

# 碰撞目标时步数调整
func on_collision_as_target(marble: Marble2D, collider: Marble2D, incoming_steps: int, direction: int) -> int:
	return incoming_steps

# 死亡清理钩子
func on_death(marble: Marble2D) -> void:
	pass

