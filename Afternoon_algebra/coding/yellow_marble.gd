extends Marble2D

func move(direction: int, steps: int) -> void:
	var actual_steps = YellowMarbleHelper.get_randomized_steps(steps)
	super.move(direction, actual_steps)

func on_death() -> void:
	print("黄球死亡，等待选择增益目标")

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
