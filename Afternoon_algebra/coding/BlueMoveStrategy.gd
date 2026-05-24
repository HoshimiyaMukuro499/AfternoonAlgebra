# BlueMoveStrategy.gd
# 蓝色移动策略：使用已生成的随从（由 GameManager 在选定方向后生成），自身移动、随从移动、清除随从
class_name BlueMoveStrategy
extends "res://MoveStrategyBase.gd"

const BlueMarbleHelper = preload("res://BlueMarbleHelper.gd")

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	# 获取已生成的随从列表
	var followers: Array[Node2D] = []
	if marble.has_method("get_temp_followers"):
		followers = marble.get_temp_followers()
	elif "temp_followers" in marble:
		followers = marble.temp_followers
	elif "followers" in marble:
		followers = marble.followers
	
	# 如果没有随从（可能因为取消选择等原因），则生成（防御）
	if followers.is_empty():
		followers = BlueMarbleHelper.spawn_followers(marble, direction)
	
	var self_success = marble._move_step_by_step(direction, steps)
	if marble.is_alive and self_success:
		var ok = BlueMarbleHelper.move_followers(marble, followers, direction, steps)
		if not ok:
			marble.die()
	BlueMarbleHelper.clear_followers(marble, followers)
	return self_success

func on_death(marble: Marble2D) -> void:
	# 清除可能残留的随从
	if marble.has_method("clear_temp_followers"):
		marble.clear_temp_followers()
	elif "temp_followers" in marble and marble.temp_followers.size() > 0:
		BlueMarbleHelper.clear_followers(marble, marble.temp_followers)
		marble.temp_followers = []
	elif "followers" in marble and marble.followers.size() > 0:
		BlueMarbleHelper.clear_followers(marble, marble.followers)
		marble.followers = []

