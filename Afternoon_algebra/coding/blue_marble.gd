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

func _get_game_manager():
	var root = get_tree().current_scene
	if root and root is GameManager:
		return root
	return null
# 新增方法：清除临时随从
func clear_temp_followers() -> void:
	if followers.size() > 0:
		BlueMarbleHelper.clear_followers(self, followers)
		followers = []

func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	
	on_before_move(direction, steps)
	
	# 生成随从（如果没有）
	if followers.is_empty():
		followers = BlueMarbleHelper.spawn_followers(self, direction)
	
	# 获取 GameManager 引用
	var gm = _get_game_manager()
	
	# 逐格移动，每一步同时移动蓝球自身和所有随从
	for step in range(steps):
		if not is_alive:
			break
		
		# 记录移动前的坐标（用于之后的光点）
		var before_hex = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
		
		# 蓝球自身移动一格（同步移动，不产生额外光点，因为我们会手动显示）
		var step_ok = _move_step_by_step(direction, 1)
		if not step_ok:
			break
		
		# 蓝球移动后的新坐标
		var after_hex = hex_coord if hex_coord != Vector2.ZERO else hex_grid.get_marble_hex(self)
		
		# 显示蓝球自身的光点（不等待）
		if gm and before_hex != after_hex:
			gm.show_light_at_no_wait(after_hex)
		
		# 移动所有随从一格，并显示光点（并行）
		var follower_ok = await BlueMarbleHelper.move_followers_one_step_parallel(self, followers, direction, gm)
		if not follower_ok:
			# 随从出界，蓝球死亡
			if not follower_safe:
				die()
				break
		
		# 等待一小段时间，让光点可见（这一步必须等待，否则动画会太快）
		await get_tree().create_timer(0.2).timeout
	
	# 清除所有随从
	BlueMarbleHelper.clear_followers(self, followers)
	
	on_after_move(direction, steps, is_alive)


# 死亡时额外清理随从（防御，避免残留）
func on_death() -> void:
	BlueMarbleHelper.clear_followers(self, followers)
	# 黄球增益：设置随从安全模式
func set_follower_safe(safe: bool) -> void:
	follower_safe = safe
	print("蓝球获得增益：随从出界不再导致死亡")
