extends CanvasLayer

@onready var turn_label: Label = $TurnLabel
@onready var message_label: Label = $MessageLabel

func _ready():
	# 延迟一帧连接信号，确保 GameManager 已就绪
	await get_tree().process_frame
	
	var gm = _find_game_manager()
	if gm:
		if not gm.is_connected("state_changed", _on_state_changed):
			gm.connect("state_changed", _on_state_changed)
		update_turn_display(gm)
		_on_state_changed(gm.current_state)

func _find_game_manager() -> GameManager:
	# 尝试多种路径找到 GameManager
	var gm = get_node_or_null("/root/Node2D")
	if gm is GameManager:
		return gm
	gm = get_node_or_null("/root/Main")
	if gm is GameManager:
		return gm
	gm = get_tree().get_first_node_in_group("game_manager")
	if gm is GameManager:
		return gm
	# 向上查找父节点
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
	
	match new_state:
		GameManager.TurnState.IDLE:
			message_label.text = "请点击己方弹珠"
		GameManager.TurnState.MARBLE_SELECTED:
			message_label.text = "请选择移动方向 (点击相邻格子)"
		GameManager.TurnState.DIRECTION_SELECTED:
			message_label.text = "请选择力度 (按 1~5)"
		GameManager.TurnState.EXECUTING:
			message_label.text = "移动中..."
