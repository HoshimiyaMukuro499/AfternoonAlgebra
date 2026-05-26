extends Marble2D

func move(direction: int, steps: int) -> void:
	var actual_steps = YellowMarbleHelper.get_randomized_steps(steps)
	super.move(direction, actual_steps)

func on_death() -> void:
	print("黄球死亡，等待选择增益目标")
	# 通知 GameManager 进入黄球增益选择流程
	var gm = _find_game_manager()
	if gm and gm.has_method("notify_yellow_death"):
		gm.notify_yellow_death(camp)

func _find_game_manager():
	var root = get_tree().current_scene
	if root and root is GameManager:
		return root
	if root:
		var gm_node = root.find_child("GameManager", true, false)
		if gm_node:
			return gm_node
	return null

# 由 GameManager 调用，对目标弹珠施加增益
func apply_boost(target: Marble2D) -> void:
	match target.color:
		MarbleConst.MarbleColor.BLUE:
			if target.has_method("set_follower_safe"):
				target.set_follower_safe(true)
		MarbleConst.MarbleColor.GREEN:
			if target.has_method("increase_push_range"):
				target.increase_push_range(1)
		MarbleConst.MarbleColor.RED:
			if target.has_method("increase_max_steps"):
				target.increase_max_steps(1)
		MarbleConst.MarbleColor.BLACK:
			if target.has_method("set_enhanced"):
				target.set_enhanced(true)
		_:
			print("黄球增益只能用于蓝、绿、红、黑球")
