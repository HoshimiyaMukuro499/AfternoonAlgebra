extends CanvasLayer

var turn_label: RichTextLabel
var message_label: RichTextLabel
var background_panel: Panel

func _ready():
	# 创建UI结构
	_build_ui()
	
	# 连接信号
	var gm = _find_game_manager()
	if gm:
		if not gm.is_connected("state_changed", _on_state_changed):
			gm.connect("state_changed", _on_state_changed)
		update_turn_display(gm)
		_on_state_changed(gm.current_state)

func _build_ui():
	# 加载自定义字体
	var custom_font_data = load("res://HYPixel11pxU-2.ttf")
	var custom_font = FontFile.new()
	custom_font.font_data = custom_font_data
	
	# 创建容器 Control（用于自适应布局）
	var container = Control.new()
	container.name = "UIContainer"
	container.anchor_left = 0.0
	container.anchor_top = 0.0
	container.anchor_right = 0.0
	container.anchor_bottom = 0.0
	container.offset_left = 10
	container.offset_top = 10
	container.offset_right = 300
	container.offset_bottom = 120
	add_child(container)
	
	# 创建背景面板
	background_panel = Panel.new()
	background_panel.name = "Background"
	background_panel.anchor_left = 0.0
	background_panel.anchor_top = 0.0
	background_panel.anchor_right = 1.0
	background_panel.anchor_bottom = 1.0
	background_panel.offset_left = -5
	background_panel.offset_top = -5
	background_panel.offset_right = 5
	background_panel.offset_bottom = 5
	# 设置半透明黑色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background_panel.add_theme_stylebox_override("panel", style)
	container.add_child(background_panel)
	
	# 创建回合标签（使用 RichTextLabel 以支持 BBCode）
	turn_label = RichTextLabel.new()
	turn_label.name = "TurnLabel"
	turn_label.anchor_left = 0.0
	turn_label.anchor_top = 0.0
	turn_label.anchor_right = 1.0
	turn_label.anchor_bottom = 0.0
	turn_label.offset_left = 10
	turn_label.offset_top = 10
	turn_label.offset_right = -10
	turn_label.offset_bottom = 40
	# 设置字体样式
	turn_label.add_theme_font_override("normal_font", custom_font)
	turn_label.add_theme_font_size_override("normal_font_size", 32)
	turn_label.add_theme_color_override("default_color", Color.WHITE)
	turn_label.bbcode_enabled = true
	container.add_child(turn_label)
	
	# 创建消息标签（使用 RichTextLabel 以支持 BBCode）
	message_label = RichTextLabel.new()
	message_label.name = "MessageLabel"
	message_label.anchor_left = 0.0
	message_label.anchor_top = 0.0
	message_label.anchor_right = 1.0
	message_label.anchor_bottom = 0.0
	message_label.offset_left = 10
	message_label.offset_top = 50
	message_label.offset_right = -10
	message_label.offset_bottom = 80
	message_label.add_theme_font_override("normal_font", custom_font)
	message_label.add_theme_font_size_override("normal_font_size", 32)
	message_label.add_theme_color_override("default_color", Color(1, 1, 0.8))
	message_label.bbcode_enabled = true
	container.add_child(message_label)

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
	var team_name = ""
	if gm.current_team == MarbleConst.Camp.RED:
		team_name = "[color=red]红方[/color]"
	else:
		team_name = "[color=blue]蓝方[/color]"
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
