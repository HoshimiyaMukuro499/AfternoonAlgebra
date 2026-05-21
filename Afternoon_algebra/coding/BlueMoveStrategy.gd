# BlueMoveStrategy.gd
# 蓝色移动策略：生成随从、自身移动、随从移动、清除随从
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	var followers = BlueMarbleHelper.spawn_followers(marble, direction)
	var self_success = marble._move_step_by_step(direction, steps)
	if marble.is_alive and self_success:
		var ok = BlueMarbleHelper.move_followers(marble, followers, direction, steps)
		if not ok:
			marble.die()
	BlueMarbleHelper.clear_followers(marble, followers)
	return self_success

func on_death(marble: Marble2D) -> void:
	# BlueMarble 自己管理 followers，BlueMoveStrategy 不直接访问 temp_followers
	pass

