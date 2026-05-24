# BlueMarble.gd
# 蓝球（随从）弹珠（2D版），直接使用 BlueMarbleHelper 完成随从生成、移动和清除。
extends Marble2D   # 改为 Marble2D

# 当前回合生成的随从节点列表（2D 节点）
var followers: Array[Node2D] = []
var follower_safe: bool = false   # 黄球增益：随从出界是否导致死亡

# 新增方法：设置临时随从列表（由 GameManager 在选定方向后调用）
func set_temp_followers(f: Array[Node2D]) -> void:
	followers = f

# 新增方法：获取临时随从列表
func get_temp_followers() -> Array[Node2D]:
	return followers

# 新增方法：清除临时随从
func clear_temp_followers() -> void:
	if followers.size() > 0:
		BlueMarbleHelper.clear_followers(self, followers)
		followers = []

# 重写移动方法（随从与蓝球同步逐格移动）
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	
	on_before_move(direction, steps)
	
	# 1. 生成随从（如果还没有，即未通过 select_direction 生成）
	if followers.is_empty():
		followers = BlueMarbleHelper.spawn_followers(self, direction)
	
	var remaining = steps
	while remaining > 0 and is_alive:
		var before_hex = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
		
		# 蓝球自身移动一格
		var step_ok = _move_step_by_step(direction, 1)
		if not step_ok:
			# 蓝球在这一格死亡
			break
		
		var after_hex = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
		if before_hex == after_hex:
			# 蓝球未移动（碰撞导致停下），停止后续步数
			break
		
		# 随从同步移动一格
		var follower_ok = BlueMarbleHelper.move_followers(self, followers, direction, 1)
		if not follower_ok:
			# 随从出界 → 蓝球死亡
			die()
			break
		
		remaining -= 1
	
	# 清除所有随从（无论蓝球是否死亡）
	BlueMarbleHelper.clear_followers(self, followers)
	
	on_after_move(direction, steps, is_alive)


# 死亡时额外清理随从（防御，避免残留）
func on_death() -> void:
	BlueMarbleHelper.clear_followers(self, followers)
	# 黄球增益：设置随从安全模式
func set_follower_safe(safe: bool) -> void:
	follower_safe = safe
	print("蓝球获得增益：随从出界不再导致死亡")
