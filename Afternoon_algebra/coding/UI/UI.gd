extends CanvasLayer

var turn_label: Label
var message_label: Label
var background_panel: Panel
var team_label: Label

# 选珠阶段UI元素
var setup_container: Control
var setup_team_label: Label
var setup_remaining_label: Label
var setup_message_label: Label
var color_buttons: Array[Button] = []
var setup_active = false

# 阵型名称显示标签
var formation_label: Label
var formation_timer: Timer

func _ready():
	# 创建UI结构
	_build_ui()
	
	# 连接信号
	var gm = _find_game_manager()
	if gm:
		if not gm.is_connected("state_changed", _on_state_changed):
			gm.connect("state_changed", _on_state_changed)
		if not gm.is_connected("yellow_boost_requested", _on_yellow_boost_requested):
			gm.connect("yellow_boost_requested", _on_yellow_boost_requested)
		update_turn_display(gm)
		_on_state_changed(gm.current_state)

func _build_ui():
	# 加载自定义字体
	var custom_font_data = load("res://HYPixel11pxU-2.ttf")
	var custom_font = FontFile.new()
	custom_font.font_data = custom_font_data
	
	# 创建容器 Control（固定尺寸）
	var container = Control.new()
	container.name = "UIContainer"
	container.anchor_left = 0.0
	container.anchor_top = 0.0
	container.anchor_right = 0.0
	container.anchor_bottom = 0.0
	container.offset_left = 10
	container.offset_top = 10
	container.offset_right = 400
	container.offset_bottom = 200
	add_child(container)
	
	# 创建背景面板（填充容器）
	background_panel = Panel.new()
	background_panel.name = "Background"
	background_panel.anchor_left = 0.0
	background_panel.anchor_top = 0.0
	background_panel.anchor_right = 1.0
	background_panel.anchor_bottom = 1.0
	# 设置半透明黑色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background_panel.add_theme_stylebox_override("panel", style)
	container.add_child(background_panel)
	
	# 创建回合标签
	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.anchor_left = 0.0
	turn_label.anchor_top = 0.0
	turn_label.anchor_right = 1.0
	turn_label.anchor_bottom = 0.0
	turn_label.offset_left = 10
	turn_label.offset_top = 10
	turn_label.offset_right = -10
	turn_label.offset_bottom = 50
	# 设置字体样式
	turn_label.add_theme_font_override("font", custom_font)
	turn_label.add_theme_font_size_override("font_size", 32)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(turn_label)
	
	# 创建阵营标签
	team_label = Label.new()
	team_label.name = "TeamLabel"
	team_label.anchor_left = 0.0
	team_label.anchor_top = 0.0
	team_label.anchor_right = 1.0
	team_label.anchor_bottom = 0.0
	team_label.offset_left = 10
	team_label.offset_top = 60
	team_label.offset_right = -10
	team_label.offset_bottom = 100
	team_label.add_theme_font_override("font", custom_font)
	team_label.add_theme_font_size_override("font_size", 32)
	team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	team_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(team_label)
	
	# 创建消息标签
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.anchor_left = 0.0
	message_label.anchor_top = 0.0
	message_label.anchor_right = 1.0
	message_label.anchor_bottom = 0.0
	message_label.offset_left = 10
	message_label.offset_top = 110
	message_label.offset_right = -10
	message_label.offset_bottom = -10
	message_label.add_theme_font_override("font", custom_font)
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(message_label)
	
	# 选珠阶段UI（初始隐藏）
	_setup_setup_ui(container)

func _setup_setup_ui(parent: Control):
	setup_container = Control.new()
	setup_container.name = "SetupContainer"
	setup_container.anchor_left = 0.0
	setup_container.anchor_top = 0.0
	setup_container.anchor_right = 1.0
	setup_container.anchor_bottom = 1.0
	setup_container.offset_left = 10
	setup_container.offset_top = 10
	setup_container.offset_right = -10
	setup_container.offset_bottom = -10
	setup_container.visible = false
	parent.add_child(setup_container)
	
	# 当前玩家标签
	setup_team_label = Label.new()
	setup_team_label.name = "SetupTeamLabel"
	setup_team_label.anchor_left = 0.0
	setup_team_label.anchor_top = 0.0
	setup_team_label.anchor_right = 1.0
	setup_team_label.anchor_bottom = 0.0
	setup_team_label.offset_left = 0
	setup_team_label.offset_top = 0
	setup_team_label.offset_right = 0
	setup_team_label.offset_bottom = 40
	setup_team_label.add_theme_font_override("font", load("res://HYPixel11pxU-2.ttf"))
	setup_team_label.add_theme_font_size_override("font_size", 28)
	setup_team_label.add_theme_color_override("font_color", Color.WHITE)
	setup_team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_team_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	setup_container.add_child(setup_team_label)
	
	# 剩余棋子标签
	setup_remaining_label = Label.new()
	setup_remaining_label.name = "SetupRemainingLabel"
	setup_remaining_label.anchor_left = 0.0
	setup_remaining_label.anchor_top = 0.0
	setup_remaining_label.anchor_right = 1.0
	setup_remaining_label.anchor_bottom = 0.0
	setup_remaining_label.offset_left = 0
	setup_remaining_label.offset_top = 45
	setup_remaining_label.offset_right = 0
	setup_remaining_label.offset_bottom = 85
	setup_remaining_label.add_theme_font_override("font", load("res://HYPixel11pxU-2.ttf"))
	setup_remaining_label.add_theme_font_size_override("font_size", 24)
	setup_remaining_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	setup_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_remaining_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	setup_container.add_child(setup_remaining_label)
	
	# 颜色选择按钮（6个）
	var color_names = ["白（遗愿者）", "蓝（统领者）", "绿（推挤者）", "红（定向者）", "黑（干扰者）", "黄（牺牲者）"]
	var color_values = [Color.WHITE, Color.BLUE, Color.GREEN, Color.RED, Color(0.8, 0.8, 0.8), Color.YELLOW]
	var button_container = GridContainer.new()
	button_container.name = "ColorButtonContainer"
	button_container.columns = 3
	button_container.anchor_left = 0.0
	button_container.anchor_top = 0.0
	button_container.anchor_right = 1.0
	button_container.anchor_bottom = 0.0
	button_container.offset_left = 0
	button_container.offset_top = 90
	button_container.offset_right = 0
	button_container.offset_bottom = 180
	setup_container.add_child(button_container)
	
	for i in range(6):
		var btn = Button.new()
		btn.text = color_names[i]
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_color_override("font_color", color_values[i])
		btn.add_theme_font_size_override("font_size", 18)
		btn.connect("pressed", Callable(self, "_on_color_button_pressed").bind(i))
		button_container.add_child(btn)
		color_buttons.append(btn)
	
	# 选珠阶段消息标签
	setup_message_label = Label.new()
	setup_message_label.name = "SetupMessageLabel"
	setup_message_label.anchor_left = 0.0
	setup_message_label.anchor_top = 0.0
	setup_message_label.anchor_right = 1.0
	setup_message_label.anchor_bottom = 0.0
	setup_message_label.offset_left = 0
	setup_message_label.offset_top = 190
	setup_message_label.offset_right = 0
	setup_message_label.offset_bottom = -10
	setup_message_label.add_theme_font_override("font", load("res://HYPixel11pxU-2.ttf"))
	setup_message_label.add_theme_font_size_override("font_size", 22)
	setup_message_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	setup_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	setup_container.add_child(setup_message_label)
	
	# 阵型名称标签（初始隐藏）
	formation_label = Label.new()
	formation_label.name = "FormationLabel"
	formation_label.anchor_left = 0.0
	formation_label.anchor_top = 0.0
	formation_label.anchor_right = 1.0
	formation_label.anchor_bottom = 0.0
	formation_label.offset_left = 0
	formation_label.offset_top = 0
	formation_label.offset_right = 0
	formation_label.offset_bottom = 0
	formation_label.add_theme_font_override("font", load("res://HYPixel11pxU-2.ttf"))
	formation_label.add_theme_font_size_override("font_size", 28)
	formation_label.add_theme_color_override("font_color", Color(1, 0.8, 0))  # 金色
	formation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	formation_label.visible = false
	setup_container.add_child(formation_label)
	
	# 定时器用于自动隐藏阵型名称
	formation_timer = Timer.new()
	formation_timer.name = "FormationTimer"
	formation_timer.one_shot = true
	formation_timer.timeout.connect(_on_formation_timer_timeout)
	add_child(formation_timer)

func _on_color_button_pressed(color_index: int):
	if not setup_active:
		return
	var gm = _find_game_manager()
	if gm:
		gm.setup_select_color(color_index)

func show_setup_phase(team: int, remaining: int):
	setup_active = true
	setup_container.visible = true
	var team_name = "红方" if team == MarbleConst.Camp.RED else "蓝方"
	var team_color = Color.RED if team == MarbleConst.Camp.RED else Color.BLUE
	setup_team_label.text = "当前玩家：%s" % team_name
	setup_team_label.add_theme_color_override("font_color", team_color)
	setup_remaining_label.text = "剩余棋子：%d" % remaining
	# 隐藏正常回合标签
	turn_label.visible = false
	team_label.visible = false
	message_label.visible = false
	# 恢复选珠阶段子节点可见性（可能被 show_formation_name 隐藏）
	setup_team_label.visible = true
	setup_remaining_label.visible = true
	setup_message_label.visible = true
	for btn in color_buttons:
		btn.visible = true
	# 隐藏阵型名称标签
	if formation_label:
		formation_label.visible = false

func hide_setup_phase():
	setup_active = false
	setup_container.visible = false
	turn_label.visible = true
	team_label.visible = true
	message_label.visible = true

func update_setup_message(text: String):
	if setup_message_label:
		setup_message_label.text = text

func update_setup_remaining(remaining: int):
	if setup_remaining_label:
		setup_remaining_label.text = "剩余棋子：%d" % remaining

func highlight_available_positions(positions: Array):
	# 简单实现：在消息中显示可放置位置数量
	if setup_message_label:
		setup_message_label.text = "可放置位置数量：%d" % positions.size()

func show_formation_name(text: String):
	if formation_label:
		formation_label.text = text
		formation_label.visible = true
		# 隐藏其他标签
		setup_team_label.visible = false
		setup_remaining_label.visible = false
		setup_message_label.visible = false
		for btn in color_buttons:
			btn.visible = false
		# 不再启动定时器，由 GameManager 的 await 控制隐藏

func _on_formation_timer_timeout():
	# 不再使用定时器，此函数保留为空
	pass

func _find_game_manager() -> GameManager:
	# 简化查找：直接获取父节点
	var parent = get_parent()
	while parent:
		if parent is GameManager:
			return parent
		parent = parent.get_parent()
	return null

func update_turn(text: String):
	if turn_label:
		turn_label.text = text

func update_message(text: String):
	if message_label:
		message_label.text = text
	else:
		push_error("UI.gd: message_label 为 null，无法更新消息")

func update_turn_display(gm: GameManager):
	if not turn_label or not team_label:
		return
	var team_name = ""
	var team_color = Color.WHITE
	if gm.current_team == MarbleConst.Camp.RED:
		team_name = "红方"
		team_color = Color.RED
	else:
		team_name = "蓝方"
		team_color = Color.BLUE
	turn_label.text = "第 %d 回合行动：" % gm.turn_number
	team_label.text = team_name
	team_label.add_theme_color_override("font_color", team_color)

func show_victory(team_name: String):
	if message_label:
		message_label.text = "%s 获胜！" % team_name
		message_label.add_theme_color_override("font_color", Color(1, 0.8, 0))  # 金色

func enter_black_select_enemy_mode() -> void:
	if message_label:
		message_label.text = "请点击一个敌方弹珠作为目标"

func enter_black_select_direction_mode() -> void:
	if message_label:
		message_label.text = "请指定敌方弹珠的大致移动方向（点击相邻六个方向之一）"

func _on_yellow_boost_requested(dead_yellow: Marble2D, candidates: Array[Marble2D]):
	# 显示增益选择对话框
	show_yellow_boost_dialog(dead_yellow, candidates)

func show_yellow_boost_dialog(dead_yellow: Marble2D, candidates: Array[Marble2D]):
	# 创建弹出对话框
	var dialog = AcceptDialog.new()
	dialog.title = "黄球增益选择"
	dialog.size = Vector2(400, 350)
	add_child(dialog)
	
	# 创建主容器（包含文本和按钮列表）
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.anchor_left = 0.0
	main_vbox.anchor_top = 0.0
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 10
	main_vbox.offset_top = 10
	main_vbox.offset_right = -10
	main_vbox.offset_bottom = -10
	dialog.add_child(main_vbox)
	
	# 添加文本标签
	var text_label = Label.new()
	text_label.text = "黄球已死亡！请选择一个己方弹珠获得增益："
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.custom_minimum_size = Vector2(0, 40)
	main_vbox.add_child(text_label)
	
	# 添加分隔线
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(separator)
	
	# 创建候选按钮列表
	var vbox = VBoxContainer.new()
	vbox.name = "CandidateList"
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_child(vbox)
	
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.is_alive:
			continue
		var btn = Button.new()
		var color_name = MarbleConst.COLOR_NAMES.get(candidate.color, "未知")
		var camp_name = "红" if candidate.camp == MarbleConst.Camp.RED else "蓝"
		var boost_text = ""
		if candidate.boost_count > 0:
			boost_text = " (增益次数: %d)" % candidate.boost_count
		# 显示弹珠编号
		var label_text = ""
		if candidate.label_index > 0:
			var prefix = "R" if candidate.camp == MarbleConst.Camp.RED else "B"
			label_text = "%s%d " % [prefix, candidate.label_index]
		btn.text = "%s%s方 %s%s" % [label_text, camp_name, color_name, boost_text]
		btn.connect("pressed", Callable(self, "_on_boost_target_selected").bind(candidate, dialog))
		vbox.add_child(btn)
	
	dialog.popup_centered()

func _on_boost_target_selected(target: Marble2D, dialog: AcceptDialog):
	var gm = _find_game_manager()
	if gm:
		gm.apply_yellow_boost(target)
	if dialog and is_instance_valid(dialog):
		dialog.queue_free()

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
		GameManager.TurnState.VICTORY:
			# 胜利信息已在 show_victory 中设置
			pass
		GameManager.TurnState.YELLOW_BOOST:
			message_label.text = "请选择增益目标（点击按钮）"
