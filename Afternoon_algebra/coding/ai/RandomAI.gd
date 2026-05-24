# RandomAI.gd
# 随机 AI 策略：所有决策点均随机选择合法操作
extends AIStrategy

var _used_colors_red: Array = []
var _used_colors_blue: Array = []

func _init():
	randomize()

func decide(gm: GameManager) -> Dictionary:
	if gm.setup_phase_active:
		return _decide_setup(gm)
	match gm.current_state:
		GameManager.TurnState.IDLE:
			return _decide_select_marble(gm)
		GameManager.TurnState.MARBLE_SELECTED:
			if gm.selected_marble and gm.selected_marble.color == MarbleConst.MarbleColor.RED:
				return _decide_red_power(gm)
			else:
				return _decide_direction(gm)
		GameManager.TurnState.DIRECTION_SELECTED:
			return _decide_power(gm)
		GameManager.TurnState.RED_DIRECTION_PICKING:
			return _decide_red_direction(gm)
	return {}

func _decide_setup(gm: GameManager) -> Dictionary:
	match gm.setup_state:
		GameManager.SetupState.COLOR_SELECT:
			return _decide_setup_color(gm)
		GameManager.SetupState.PLACEMENT:
			return _decide_setup_placement(gm)
	return {}

func _decide_setup_color(gm: GameManager) -> Dictionary:
	var camp = gm.setup_current_team
	var used = _used_colors_red if camp == MarbleConst.Camp.RED else _used_colors_blue
	var available_colors = []
	for c in range(MarbleConst.MarbleColor.size()):
		if c not in used:
			available_colors.append(c)
	var color
	if available_colors.size() > 0:
		color = available_colors[randi() % available_colors.size()]
	else:
		color = randi() % MarbleConst.MarbleColor.size()
	used.append(color)
	return {"action": "setup_color", "color": color}

func _decide_setup_placement(gm: GameManager) -> Dictionary:
	var positions = gm.hex_grid.get_available_positions(gm.setup_current_team)
	var available = []
	for pos in positions:
		var q = int(pos.x)
		var r = int(pos.y)
		if gm.hex_grid.get_marble_at(q, r) == null:
			available.append(pos)
	if available.size() == 0:
		push_error("RandomAI: 没有可放置的位置，跳过决策")
		return {}  # 返回空字典，让上层停止 AI 决策循环
	var chosen = available[randi() % available.size()]
	return {"action": "setup_place", "q": int(chosen.x), "r": int(chosen.y)}

func _decide_select_marble(gm: GameManager) -> Dictionary:
	var my_marbles = get_alive_marbles(gm, gm.current_team)
	if my_marbles.size() == 0:
		push_error("RandomAI: 没有可选的己方弹珠")
		return {}
	var chosen = my_marbles[randi() % my_marbles.size()]
	return {"action": "select_marble", "marble": chosen}

func _decide_direction(gm: GameManager) -> Dictionary:
	return {"action": "select_direction", "direction": randi() % 6}

func _decide_power(gm: GameManager) -> Dictionary:
	return {"action": "select_power", "power": (randi() % 5) + 1}

func _decide_red_power(gm: GameManager) -> Dictionary:
	return {"action": "red_power", "power": (randi() % 5) + 1}

func _decide_red_direction(gm: GameManager) -> Dictionary:
	return {"action": "red_direction", "direction": randi() % 6}
