# AIStrategy.gd
# AI 策略基类，定义所有 AI 策略的接口
class_name AIStrategy
extends RefCounted

# 根据当前 GameManager 状态，返回下一步操作
# 返回值 Dictionary:
#   { "action": "select_marble", "marble": Marble2D }
#   { "action": "select_direction", "direction": int }
#   { "action": "select_power", "power": int }
#   { "action": "red_power", "power": int }
#   { "action": "red_direction", "direction": int }
#   { "action": "setup_color", "color": int }
#   { "action": "setup_place", "q": int, "r": int }
func decide(gm: GameManager) -> Dictionary:
	push_error("AIStrategy.decide() 未实现，请子类重写")
	return {}

# 棋盘评估（用于启发式 / MCTS）
# 返回一个浮点数，越高代表对当前阵营越有利
func evaluate(gm: GameManager, for_camp: int) -> float:
	push_error("AIStrategy.evaluate() 未实现，请子类重写")
	return 0.0

# 获取当前 GameManager 的快照信息（辅助方法）
func get_game_snapshot(gm: GameManager) -> Dictionary:
	var snapshot = {
		"current_team": gm.current_team,
		"current_state": gm.current_state,
		"turn_number": gm.turn_number,
		"setup_state": gm.setup_state if gm.setup_phase_active else -1,
		"setup_current_team": gm.setup_current_team if gm.setup_phase_active else -1,
		"marbles": [],
		"all_marbles": [],
	}
	for marble in gm.all_marbles:
		if not is_instance_valid(marble):
			continue
		var marble_info = {
			"instance_id": marble.get_instance_id(),
			"camp": marble.camp,
			"color": marble.color,
			"is_alive": marble.is_alive,
			"hex_coord": marble.hex_coord,
			"label_index": marble.label_index,
		}
		snapshot.all_marbles.append(marble_info)
		if marble.is_alive:
			snapshot.marbles.append(marble_info)
	return snapshot

# 获取指定阵营的存活弹珠列表
func get_alive_marbles(gm: GameManager, camp: int) -> Array:
	var result = []
	for marble in gm.all_marbles:
		if is_instance_valid(marble) and marble.is_alive and marble.camp == camp:
			result.append(marble)
	return result

# 获取对手阵营
func opponent(camp: int) -> int:
	return MarbleConst.Camp.BLUE if camp == MarbleConst.Camp.RED else MarbleConst.Camp.RED

# 获取棋盘上的弹珠位置字典（hex_coord -> marble）
func get_marble_position_map(gm: GameManager) -> Dictionary:
	var pos_map = {}
	for marble in gm.all_marbles:
		if is_instance_valid(marble) and marble.is_alive:
			pos_map[marble.hex_coord] = marble
	return pos_map
