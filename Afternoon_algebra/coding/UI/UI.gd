extends CanvasLayer

@onready var turn_label = $TurnLabel
@onready var message_label = $MessageLabel

func _ready():
	var gm = get_node("/root/Main/GameManager")  # 根据你的场景路径调整
	if gm:
		gm.connect("state_changed", _on_state_changed)
	update_turn_display(gm)

func update_turn_display(gm):
	var team_name = "红方" if gm.current_team == MarbleConst.Camp.RED else "蓝方"
	turn_label.text = "当前回合: " + team_name

func _on_state_changed(new_state):
	var gm = get_node("/root/Main/GameManager")
	update_turn_display(gm)
	match new_state:
		gm.IDLE:
			message_label.text = "请点击己方弹珠"
		gm.MARBLE_SELECTED:
			message_label.text = "请选择移动方向 (点击相邻格子)"
		gm.DIRECTION_SELECTED:
			message_label.text = "请选择力度 (按 1~5)"
		gm.EXECUTING:
			message_label.text = "移动中..."
