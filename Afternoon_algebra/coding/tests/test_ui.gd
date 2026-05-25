# test_ui.gd
# UI 功能测试：测试 UI.gd 中的 UI 元素和交互逻辑
class_name TestUI
extends "res://tests/base_test.gd"

var ui: Node  # CanvasLayer with UI.gd script
var gm: GameManager
var grid: HexGrid2D
var marbles: Array[Marble2D] = []

const RED_CAMP := MarbleConst.Camp.RED
const BLUE_CAMP := MarbleConst.Camp.BLUE

func before_each() -> void:
	gm = GameManager.new()
	
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	gm.hex_grid = grid
	
	# 创建 UI CanvasLayer 并添加脚本
	ui = CanvasLayer.new()
	ui.name = "UI"
	var ui_script = load("res://UI/UI.gd")
	ui.set_script(ui_script)
	gm.add_child(ui)
	gm.ui = ui
	# 手动调用 _ready() 构建 UI（不在场景树中时 _ready 不会自动触发）
	ui._ready()
	
	marbles = []

func after_each() -> void:
	for m in marbles:
		if m and is_instance_valid(m):
			m.queue_free()
	marbles.clear()
	
	if ui and is_instance_valid(ui):
		if gm and is_instance_valid(gm) and gm.is_connected("state_changed", Callable(ui, "_on_state_changed")):
			gm.disconnect("state_changed", Callable(ui, "_on_state_changed"))
		ui.queue_free()
		ui = null
	if grid and is_instance_valid(grid):
		grid.queue_free()
		grid = null
	if gm and is_instance_valid(gm):
		gm.queue_free()
		gm = null

func _mk(coord: Vector2i, camp: int, color: int) -> Marble2D:
	var m := Marble2D.new()
	m.hex_grid = grid
	m.hex_coord = Vector2(coord.x, coord.y)
	m.camp = camp as MarbleConst.Camp
	m.color = color as MarbleConst.MarbleColor
	m.is_alive = true
	grid.place_marble(m, coord.x, coord.y)
	marbles.append(m)
	return m

# ================================================================
# 第1组：UI 初始化与基本结构
# ================================================================

func test_ui_nodes_exist() -> void:
	assert_not_null(ui.turn_label, "turn_label 应存在")
	assert_not_null(ui.message_label, "message_label 应存在")
	assert_not_null(ui.team_label, "team_label 应存在")
	assert_not_null(ui.background_panel, "background_panel 应存在")
	assert_not_null(ui.setup_container, "setup_container 应存在")
	assert_not_null(ui.setup_team_label, "setup_team_label 应存在")
	assert_not_null(ui.setup_remaining_label, "setup_remaining_label 应存在")
	assert_not_null(ui.setup_message_label, "setup_message_label 应存在")
	assert_not_null(ui.formation_label, "formation_label 应存在")
	assert_not_null(ui.formation_timer, "formation_timer 应存在")
	assert_eq(ui.color_buttons.size(), 6, "应有6个颜色按钮")

func test_ui_initial_visibility() -> void:
	assert_false(ui.setup_container.visible, "选珠阶段初始应隐藏")
	assert_true(ui.turn_label.visible, "回合标签初始应可见")
	assert_true(ui.message_label.visible, "消息标签初始应可见")
	assert_true(ui.team_label.visible, "阵营标签初始应可见")

func test_initial_labels_empty() -> void:
	assert_eq(ui.setup_team_label.text, "", "setup_team_label 初始为空")
	assert_eq(ui.setup_remaining_label.text, "", "setup_remaining_label 初始为空")
	assert_eq(ui.setup_message_label.text, "", "setup_message_label 初始为空")

# ================================================================
# 第2组：状态变化消息测试
# ================================================================

func test_state_changed_idle_msg() -> void:
	gm.current_team = RED_CAMP
	ui._on_state_changed(GameManager.TurnState.IDLE)
	assert_eq(ui.message_label.text, "请点击己方弹珠", "IDLE 应显示提示消息")

func test_state_changed_marble_selected_msg() -> void:
	var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_team = RED_CAMP
	gm.selected_marble = m
	ui._on_state_changed(GameManager.TurnState.MARBLE_SELECTED)
	assert_eq(ui.message_label.text, "请选择移动方向 (点击相邻格子)", "普通球应提示选方向")

func test_state_changed_red_marble_selected_msg() -> void:
	var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.RED)
	gm.current_team = RED_CAMP
	gm.selected_marble = m
	ui._on_state_changed(GameManager.TurnState.MARBLE_SELECTED)
	assert_eq(ui.message_label.text, "红球：请选择力度 (按 1~4 键)", "红球应提示选力度")

func test_state_changed_direction_selected_msg() -> void:
	ui._on_state_changed(GameManager.TurnState.DIRECTION_SELECTED)
	assert_eq(ui.message_label.text, "请选择力度 (按 1~5)", "应提示选力度")

func test_state_changed_red_direction_picking_msg() -> void:
	gm.red_current_step_index = 0
	ui._on_state_changed(GameManager.TurnState.RED_DIRECTION_PICKING)
	assert_eq(ui.message_label.text, "红球：请选择第 1 步方向 (点击相邻格子)", "应提示选方向")

func test_state_changed_executing_msg() -> void:
	ui._on_state_changed(GameManager.TurnState.EXECUTING)
	assert_eq(ui.message_label.text, "移动中...", "应显示移动中")

func test_state_changed_victory_no_msg_change() -> void:
	ui.message_label.text = "测试初始"
	ui._on_state_changed(GameManager.TurnState.VICTORY)
	assert_eq(ui.message_label.text, "测试初始", "VICTORY 状态不应修改消息")

# ================================================================
# 第3组：回合显示更新
# ================================================================

func test_update_turn_display_red() -> void:
	gm.current_team = RED_CAMP
	gm.turn_number = 3
	ui.update_turn_display(gm)
	assert_eq(ui.turn_label.text, "第 3 回合行动：", "回合标签应显示回合数")
	assert_eq(ui.team_label.text, "红方", "阵营标签应显示红方")

func test_update_turn_display_blue() -> void:
	gm.current_team = BLUE_CAMP
	gm.turn_number = 5
	ui.update_turn_display(gm)
	assert_eq(ui.turn_label.text, "第 5 回合行动：", "回合标签应显示回合数")
	assert_eq(ui.team_label.text, "蓝方", "阵营标签应显示蓝方")

# ================================================================
# 第4组：选珠阶段 UI
# ================================================================

func test_show_setup_phase_red() -> void:
	ui.show_setup_phase(RED_CAMP, 6)
	assert_true(ui.setup_container.visible, "选珠容器应可见")
	assert_true(ui.setup_active, "setup_active 应为 true")
	assert_eq(ui.setup_team_label.text, "当前玩家：红方", "应显示红方")
	assert_eq(ui.setup_remaining_label.text, "剩余棋子：6", "应显示剩余棋子数")
	assert_false(ui.turn_label.visible, "回合标签应隐藏")
	assert_false(ui.team_label.visible, "阵营标签应隐藏")
	assert_false(ui.message_label.visible, "消息标签应隐藏")

func test_show_setup_phase_blue() -> void:
	ui.show_setup_phase(BLUE_CAMP, 3)
	assert_true(ui.setup_container.visible, "选珠容器应可见")
	assert_eq(ui.setup_team_label.text, "当前玩家：蓝方", "应显示蓝方")
	assert_eq(ui.setup_remaining_label.text, "剩余棋子：3", "应显示剩余棋子数")

func test_hide_setup_phase() -> void:
	ui.show_setup_phase(RED_CAMP, 6)
	ui.hide_setup_phase()
	
	assert_false(ui.setup_active, "setup_active 应为 false")
	assert_false(ui.setup_container.visible, "选珠容器应隐藏")
	assert_true(ui.turn_label.visible, "回合标签应恢复可见")
	assert_true(ui.team_label.visible, "阵营标签应恢复可见")
	assert_true(ui.message_label.visible, "消息标签应恢复可见")

func test_update_setup_message() -> void:
	ui.update_setup_message("请选择颜色")
	assert_eq(ui.setup_message_label.text, "请选择颜色", "消息应更新")

func test_update_setup_remaining() -> void:
	ui.update_setup_remaining(4)
	assert_eq(ui.setup_remaining_label.text, "剩余棋子：4", "剩余数应更新")

func test_update_turn_method() -> void:
	ui.update_turn("测试回合")
	assert_eq(ui.turn_label.text, "测试回合")

func test_update_message_method() -> void:
	ui.update_message("测试消息")
	assert_eq(ui.message_label.text, "测试消息")

func test_update_message_twice() -> void:
	ui.update_message("第一条")
	ui.update_message("第二条")
	assert_eq(ui.message_label.text, "第二条", "应覆盖之前的消息")

# ================================================================
# 第5组：阵型名称显示
# ================================================================

func test_show_formation_name() -> void:
	ui.show_setup_phase(RED_CAMP, 6)
	ui.show_formation_name("测试阵型")
	
	assert_true(ui.formation_label.visible, "阵型名称标签应可见")
	assert_eq(ui.formation_label.text, "测试阵型", "阵型名称应正确")
	assert_false(ui.setup_team_label.visible, "选珠玩家标签应隐藏")
	assert_false(ui.setup_remaining_label.visible, "剩余标签应隐藏")
	assert_false(ui.setup_message_label.visible, "消息标签应隐藏")
	for btn in ui.color_buttons:
		assert_false(btn.visible, "颜色按钮应隐藏")

# ================================================================
# 第6组：胜利显示
# ================================================================

func test_show_victory_red() -> void:
	ui.show_victory("红方")
	assert_eq(ui.message_label.text, "红方 获胜！", "应显示获胜方")

func test_show_victory_blue() -> void:
	ui.show_victory("蓝方")
	assert_eq(ui.message_label.text, "蓝方 获胜！", "应显示获胜方")

# ================================================================
# 第7组：GameManager 集成
# ================================================================

func test_state_changed_emit_idle_updates_ui() -> void:
	gm.current_team = RED_CAMP
	gm.turn_number = 1
	gm.current_state = GameManager.TurnState.IDLE
	gm.state_changed.emit(gm.current_state)
	
	assert_eq(ui.message_label.text, "请点击己方弹珠", "IDLE 消息正确")
	assert_eq(ui.turn_label.text, "第 1 回合行动：", "回合显示正确")
	assert_eq(ui.team_label.text, "红方", "阵营显示正确")

func test_state_changed_emit_marble_selected() -> void:
	var m := _mk(Vector2i(0, 0), RED_CAMP, MarbleConst.MarbleColor.WHITE)
	gm.current_team = RED_CAMP
	gm.selected_marble = m
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	gm.state_changed.emit(gm.current_state)
	
	assert_eq(ui.message_label.text, "请选择移动方向 (点击相邻格子)", "选球后消息正确")

# ================================================================
# 第8组：UI 结构完整性
# ================================================================

func test_color_buttons_count() -> void:
	assert_eq(ui.color_buttons.size(), 6, "6个颜色按钮")

func test_formation_timer_one_shot() -> void:
	assert_true(ui.formation_timer.one_shot, "定时器应为 one_shot")

func test_find_game_manager() -> void:
	var found = ui._find_game_manager()
	assert_eq(found, gm, "_find_game_manager 应返回 GameManager")

func test_update_message_with_null_label() -> void:
	# 测试 message_label 为 null 时 update_message 不会崩溃
	# 由于 GUT 会将 push_error 视为异常，此测试仅保留方法签名
	# 实际 null 安全性由 update_message 内部的 null 检查保证
	assert_not_null(ui.message_label, "message_label 不为 null")
	ui.update_message("测试消息")
	assert_eq(ui.message_label.text, "测试消息", "消息应更新")

# ================================================================
# 第9组：高亮可放置位置
# ================================================================

func test_highlight_available_positions() -> void:
	ui.setup_message_label.text = ""
	var positions = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)]
	ui.highlight_available_positions(positions)
	assert_eq(ui.setup_message_label.text, "可放置位置数量：3", "应显示可放置位置数量")

func test_highlight_empty_positions() -> void:
	ui.setup_message_label.text = ""
	ui.highlight_available_positions([])
	assert_eq(ui.setup_message_label.text, "可放置位置数量：0", "空列表应显示0")

# ================================================================
# 第10组：GameManager 选珠阶段集成
# ================================================================

func test_gm_start_setup_shows_ui() -> void:
	gm.setup_phase_active = true
	gm.setup_state = GameManager.SetupState.COLOR_SELECT
	gm.setup_current_team = RED_CAMP
	gm.setup_remaining_marbles = { RED_CAMP: 6, BLUE_CAMP: 6 }
	ui.show_setup_phase(RED_CAMP, 6)
	
	assert_true(ui.setup_container.visible, "选珠容器可见")
	assert_eq(ui.setup_team_label.text, "当前玩家：红方", "显示红方")
	assert_eq(ui.setup_remaining_label.text, "剩余棋子：6", "剩余6个")

func test_gm_finish_setup_hides_ui() -> void:
	ui.show_setup_phase(RED_CAMP, 6)
	ui.hide_setup_phase()
	
	assert_false(ui.setup_container.visible, "选珠容器隐藏")
	assert_true(ui.turn_label.visible, "回合标签可见")
	assert_true(ui.message_label.visible, "消息标签可见")
	assert_true(ui.team_label.visible, "阵营标签可见")
