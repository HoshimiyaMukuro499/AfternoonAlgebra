# YellowMarbleHelper.gd
# 黄球（死亡增益）公用逻辑，供 YellowMarble 和 WhiteMarble（变色后）复用

class_name YellowMarbleHelper
extends RefCounted

# 计算随机偏移后的步数（±1，范围1~5）
static func get_randomized_steps(steps: int) -> int:
	var actual = steps + randi() % 3 - 1
	return clamp(actual, 1, 5)


# 应用增益到目标弹珠
static func apply_boost(target: Marble2D, boost_type: int) -> void:
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
