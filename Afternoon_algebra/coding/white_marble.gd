# WhiteMarble.gd
# 白球（变色者）弹珠。
# 特性1：当当前颜色为白色时，被友方碰撞步数+1。
# 特性2：己方其他颜色弹珠死亡时，白球变为该颜色，并继承该颜色的全部移动特性（如变蓝后能生成随从）。
# 特性3：可以多次变色（覆盖）。

extends Marble3D

# 记录是否已经变色过（用于外部优先选择未变色的白球）
var has_changed: bool = false
# 临时存储随从列表（仅当当前颜色为蓝色时使用，每次移动后即清空）
var temp_followers: Array[Node3D] = []


# ---------- 碰撞步数调整 ----------
# 作为被撞者时，如果当前颜色为白色且碰撞者为友方，则步数+1
func on_collision_as_target(collider: Marble3D, incoming_steps: int, direction: int) -> int:
	if color == MarbleConst.MarbleColor.WHITE and collider.camp == camp:
		return incoming_steps + 1
	return incoming_steps


# ---------- 移动分发 ----------
# 根据当前颜色，调用对应的移动实现
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	
	on_before_move(direction, steps)
	var success = false
	match color:
		MarbleConst.MarbleColor.WHITE:
			success = _move_as_white(direction, steps)
		MarbleConst.MarbleColor.BLUE:
			success = _move_as_blue(direction, steps)
		MarbleConst.MarbleColor.GREEN:
			success = _move_as_green(direction, steps)   # TODO: 后续实现
		MarbleConst.MarbleColor.RED:
			success = _move_as_red(direction, steps)     # TODO: 后续实现
		MarbleConst.MarbleColor.BLACK:
			success = _move_as_black(direction, steps)   # 黑球不能主动移动
		MarbleConst.MarbleColor.YELLOW:
			success = _move_as_yellow(direction, steps)  # TODO: 后续实现
		_:
			success = _move_step_by_step(direction, steps)  # 保底
	on_after_move(direction, steps, success)


# ---------- 各颜色移动的具体实现 ----------
# 白色：无额外能力，仅基础移动
func _move_as_white(direction: int, steps: int) -> bool:
	return _move_step_by_step(direction, steps)


# 蓝色：生成随从（复用 BlueMarbleHelper）
func _move_as_blue(direction: int, steps: int) -> bool:
	# 1. 生成随从
	temp_followers = BlueMarbleHelper.spawn_followers(self, direction)
	# 2. 自身移动
	var self_success = _move_step_by_step(direction, steps)
	# 3. 随从移动
	if is_alive and self_success:
		var ok = BlueMarbleHelper.move_followers(self, temp_followers, direction, steps)
		if not ok:
			die()
			return false
	# 4. 清除随从
	BlueMarbleHelper.clear_followers(self, temp_followers)
	return self_success


# 绿色：推挤（暂未实现，占位）
func _move_as_green(direction: int, steps: int) -> bool:
	# TODO: 实现绿球推挤逻辑
	return _move_step_by_step(direction, steps)


# 红色：逐步选方向（暂未实现）
func _move_as_red(direction: int, steps: int) -> bool:
	# TODO: 实现红球每步可选方向
	return _move_step_by_step(direction, steps)


# 黑色：不能主动移动，直接返回失败
func _move_as_black(direction: int, steps: int) -> bool:
	return false


# 黄色：力度随机 ±1（暂未实现）
func _move_as_yellow(direction: int, steps: int) -> bool:
	# TODO: 实现黄球力度随机偏移
	return _move_step_by_step(direction, steps)


# ---------- 变色逻辑 ----------
# 由外部（GameManager / Board）在己方其他颜色弹珠死亡时调用
func on_teammate_died(dead_color: int) -> void:
	if dead_color == MarbleConst.MarbleColor.YELLOW:
		return   # 黄球死亡不触发白球变色
	if not has_changed:
		change_color(dead_color)
		has_changed = true
	else:
		change_color(dead_color)   # 允许覆盖变色


# 改变颜色并更新外观材质
func change_color(new_color: int) -> void:
	color = new_color
	_update_appearance(new_color)
	print("白球变为颜色: ", new_color)


# 根据颜色设置弹珠材质
func _update_appearance(new_color: int) -> void:
	var mat = StandardMaterial3D.new()
	match new_color:
		MarbleConst.MarbleColor.WHITE: mat.albedo_color = Color.WHITE
		MarbleConst.MarbleColor.BLUE:  mat.albedo_color = Color.BLUE
		MarbleConst.MarbleColor.GREEN: mat.albedo_color = Color.GREEN
		MarbleConst.MarbleColor.RED:   mat.albedo_color = Color.RED
		MarbleConst.MarbleColor.BLACK: mat.albedo_color = Color.BLACK
		MarbleConst.MarbleColor.YELLOW:mat.albedo_color = Color.YELLOW
	# 查找弹珠的网格节点（兼容多种命名）
	var mesh_instance = find_child("MeshInstance3D") or $MeshInstance3D
	if mesh_instance:
		mesh_instance.material_override = mat


# 死亡时清理可能残留的随从（防御）
func on_death() -> void:
	BlueMarbleHelper.clear_followers(self, temp_followers)
