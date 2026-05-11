# BlueMarble.gd
# 蓝球（随从）弹珠（2D版），直接使用 BlueMarbleHelper 完成随从生成、移动和清除。
extends Marble2D   # 改为 Marble2D

# 当前回合生成的随从节点列表（2D 节点）
var followers: Array[Node2D] = []


# 重写移动方法
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	
	on_before_move(direction, steps)
	
	# 1. 生成随从
	followers = BlueMarbleHelper.spawn_followers(self, direction)
	
	# 2. 蓝球自身移动（使用基类的逐格移动）
	var self_success = _move_step_by_step(direction, steps)
	
	# 3. 移动所有随从（如果蓝球自身移动后仍存活且成功）
	if is_alive and self_success:
		var ok = BlueMarbleHelper.move_followers(self, followers, direction, steps)
		if not ok:
			# 只要有随从出界，蓝球立即死亡
			die()
	
	# 4. 清除所有随从（无论蓝球是否死亡）
	BlueMarbleHelper.clear_followers(self, followers)
	
	on_after_move(direction, steps, self_success)


# 死亡时额外清理随从（防御，避免残留）
func on_death() -> void:
	BlueMarbleHelper.clear_followers(self, followers)
