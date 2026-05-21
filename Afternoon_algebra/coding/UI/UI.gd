extends CanvasLayer

# 节点引用
var turn_label: Label
var message_label: Label
var background_panel: Panel

func _ready():
	# 获取场景中已有的节点，添加错误检查
	turn_label = get_node_or_null("UIContainer/Background/VBoxContainer/TurnLabel")
	message_label = get_node_or_null("UIContainer/Background/VBoxContainer/MessageLabel")
	background_panel = get_node_or_null("UIContainer/Background")
	
	if not turn_label:
		push_error("UI.gd: 找不到 TurnLabel 节点")
	if not message_label:
		push_error("UI.gd: 找不到 MessageLabel 节点")
	if not background_panel:
		push_error("UI.gd: 找不到 Background 节点")
	
	# 连接信号
	var gm = _find_game_manager()
	if gm:
		if not gm.is_connected("state_changed", _on_state_changed):
			gm.connect("state_changed", _on_state_changed)
		update_turn_display(gm)
		_on_state_changed(gm.current_state)

func _find_game_manager() -> GameManager:
	# 简化查找：直接获取父节点
	var parent = get_parent()
	while parent:
		if parent is GameManager:
			return parent
		parent = parent.get_parent()
	return null

func update_turn_display(gm: GameManager):
	if not turn_label:
		return
	var team_name = "红方" if gm.current_team == MarbleConst.Camp.RED else "蓝方"
	turn_label.text = "当前回合: " + team_name

func _on_state_changed(new_state):
	if not message_label:
		return
	
	var gm = _find_game_manager()
	if gm:
		update_turn_display(gm)
		
		# 红球在MARBLE_SELECTED状态下提示选力度
		if new_state == GameManager.TurnState.MARBLE_SELECTED and gm.selected_marble and gm.selected_marble.color == MarbleConst.MarbleColor.RED:
			message_label.text = "红球：请选择力度 (按 1~5 键)"
			return
	
	match new_state:
		GameManager.TurnState.IDLE:
			message_label.text = "请点击己方弹珠"
		GameManager.TurnState.MARBLE_SELECTED:
			message_label.text = "请选择移动方向 (点击相邻格子)"
		GameManager.TurnState.DIRECTION_SELECTED:
			message_label.text = "请选择力度 (按 1~5)"
		GameManager.TurnState.RED_DIRECTION_PICKING:
			if gm:
				message_label.text = "红球：请选择第 %d 步方向 (点击相邻格子)" % (gm.red_current_step_index + 1)
			else:
				message_label.text = "红球：请选择方向 (点击相邻格子)"
		GameManager.TurnState.EXECUTING:
			message_label.text = "移动中..."
