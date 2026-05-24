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
	
	# 记录移动前的位置
	var before_pos = marble.hex_coord if marble.hex_coord != Vector2.ZERO else marble.hex_grid.get_marble_hex(marble)
	
	# 蓝球自身一次性移动所有步数（包含碰撞处理）
	# 使用一次性 _move_step_by_step 而非逐1步移动，以确保碰撞时剩余步数正确传递
	marble._move_step_by_step(direction, steps)
	
	# 计算蓝球实际移动的步数（用于随从同步移动）
	var after_pos = marble.hex_coord if marble.hex_coord != Vector2.ZERO else marble.hex_grid.get_marble_hex(marble)
	var actual_steps = max(0, int(abs(after_pos.x - before_pos.x) + abs(after_pos.y - before_pos.y)))
	
	# 蓝球移动完成后，一次性移动随从（一起结算）
	if marble.is_alive and followers.size() > 0 and actual_steps > 0:
		var follower_ok = BlueMarbleHelper.move_followers(marble, followers, direction, actual_steps)
		if not follower_ok:
			# 检查 follower_safe 标志：如果为 true，随从出界不导致蓝球死亡
			var is_safe = false
			if "follower_safe" in marble:
				is_safe = marble.follower_safe
			if not is_safe:
				marble.die()
	
	BlueMarbleHelper.clear_followers(marble, followers)
	return marble.is_alive

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
