# test_red_marble.gd
# 测试红球逐格选方向交互逻辑
class_name TestRedMarble
extends "res://tests/base_test.gd"

var gm: GameManager
var grid: HexGrid2D
var red_marble: Marble2D
var blue_marble: Marble2D

func before_each() -> void:
	gm = GameManager.new()
	
	grid = HexGrid2D.new()
	grid.grid_radius = MarbleConst.GRID_RADIUS
	grid.cell_size = MarbleConst.CELL_SIZE
	gm.hex_grid = grid
	
	# 手动创建红球弹珠（使用 Marble2D 但设置 color=RED）
	red_marble = Marble2D.new()
	red_marble.hex_grid = grid
	red_marble.hex_coord = Vector2.ZERO
	red_marble.camp = MarbleConst.Camp.RED
	red_marble.color = MarbleConst.MarbleColor.RED
	red_marble.is_alive = true
	grid.place_marble(red_marble, 0, 0)
	
	# 创建蓝方弹珠（放在远处），防止 _check_victory 误判
	blue_marble = Marble2D.new()
	blue_marble.hex_grid = grid
	blue_marble.hex_coord = Vector2(10, 0)
	blue_marble.camp = MarbleConst.Camp.BLUE
	blue_marble.color = MarbleConst.MarbleColor.WHITE
	blue_marble.is_alive = true
	grid.place_marble(blue_marble, 10, 0)
	
	gm.selected_marble = null
	gm.current_state = GameManager.TurnState.IDLE
	gm.red_step_directions = []
	gm.red_total_steps = 0
	gm.red_current_step_index = 0
	# 将双方弹珠添加到 all_marbles，使 _check_victory 判断无人获胜，从而正常切换回合
	gm.all_marbles = [red_marble, blue_marble]

func after_each() -> void:
	if red_marble:
		red_marble.queue_free()
		red_marble = null
	if blue_marble:
		blue_marble.queue_free()
		blue_marble = null
	if grid:
		grid.queue_free()
		grid = null
	if gm:
		gm.queue_free()
		gm = null

# ========== 红球选中测试 ==========

func test_select_red_marble_enters_marble_selected() -> void:
	gm.current_state = GameManager.TurnState.IDLE
	gm.current_team = MarbleConst.Camp.RED
	gm.select_marble(red_marble)
	assert_eq(gm.current_state, GameManager.TurnState.MARBLE_SELECTED, "红球选中后应进入MARBLE_SELECTED状态")
	assert_eq(gm.selected_marble, red_marble, "应记录选中的红球")

# ========== 红球选力度（步数）测试 ==========

func test_red_select_power_enters_red_direction_picking() -> void:
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	gm.selected_marble = red_marble
	gm.red_select_power(3)
	
	assert_eq(gm.current_state, GameManager.TurnState.RED_DIRECTION_PICKING, "选力度后应进入RED_DIRECTION_PICKING状态")
	assert_eq(gm.red_total_steps, 3, "应记录总步数为3")
	assert_eq(gm.red_step_directions.size(), 0, "方向列表初始应为空")
	assert_eq(gm.red_current_step_index, 0, "当前步数索引初始应为0")

func test_red_select_power_from_wrong_state() -> void:
	gm.current_state = GameManager.TurnState.IDLE
	gm.selected_marble = red_marble
	gm.red_select_power(2)
	
	assert_eq(gm.current_state, GameManager.TurnState.IDLE, "非MARBLE_SELECTED状态不应响应")
	assert_eq(gm.red_total_steps, 0, "不应修改步数")

func test_red_select_power_on_wrong_marble() -> void:
	# 把弹珠颜色改为非红
	red_marble.color = MarbleConst.MarbleColor.BLUE
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	gm.selected_marble = red_marble
	gm.red_select_power(3)
	
	assert_eq(gm.current_state, GameManager.TurnState.MARBLE_SELECTED, "非红球不应进入RED_DIRECTION_PICKING")
	assert_eq(gm.red_total_steps, 0, "不应修改步数")

# ========== 红球追加方向测试 ==========

func test_red_append_direction_one_step() -> void:
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	gm.selected_marble = red_marble
	gm.red_total_steps = 3
	gm.red_step_directions = []
	gm.red_current_step_index = 0
	
	gm.red_append_direction(MarbleConst.HexDirection.RIGHT)
	
	assert_eq(gm.red_step_directions.size(), 1, "应添加一个方向")
	assert_eq(gm.red_step_directions[0], MarbleConst.HexDirection.RIGHT, "方向应为RIGHT(0)")
	assert_eq(gm.red_current_step_index, 1, "步数索引应增加")
	assert_eq(gm.current_state, GameManager.TurnState.RED_DIRECTION_PICKING, "未选满时应保持状态")

func test_red_append_direction_three_steps() -> void:
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	gm.selected_marble = red_marble
	gm.red_total_steps = 3
	gm.red_step_directions = []
	gm.red_current_step_index = 0
	
	# 添加第1步（未满，不触发执行）
	gm.red_append_direction(MarbleConst.HexDirection.RIGHT)
	assert_eq(gm.red_step_directions.size(), 1, "第1步后应有1个方向")
	assert_eq(gm.red_step_directions[0], MarbleConst.HexDirection.RIGHT, "第1步方向RIGHT")
	assert_eq(gm.red_current_step_index, 1, "第1步后索引为1")
	assert_eq(gm.current_state, GameManager.TurnState.RED_DIRECTION_PICKING, "第1步后保持RED_DIRECTION_PICKING")
	
	# 添加第2步（未满，不触发执行）
	gm.red_append_direction(MarbleConst.HexDirection.LEFT)
	assert_eq(gm.red_step_directions.size(), 2, "第2步后应有2个方向")
	assert_eq(gm.red_step_directions[1], MarbleConst.HexDirection.LEFT, "第2步方向LEFT")
	assert_eq(gm.red_current_step_index, 2, "第2步后索引为2")
	assert_eq(gm.current_state, GameManager.TurnState.RED_DIRECTION_PICKING, "第2步后保持RED_DIRECTION_PICKING")
	
	# 添加第3步（满，触发_red_execute_move -> start_turn）
	gm.red_append_direction(MarbleConst.HexDirection.RIGHT_UP)
	# 不在场景树中，立即执行完_red_execute_move和start_turn
	assert_eq(gm.current_state, GameManager.TurnState.IDLE, "第3步后执行完成回到IDLE(新回合)")

func test_red_append_direction_triggers_execution_when_full() -> void:
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	gm.selected_marble = red_marble
	gm.red_total_steps = 1
	gm.red_step_directions = []
	gm.red_current_step_index = 0
	
	# 选满方向后应自动执行
	gm.red_append_direction(MarbleConst.HexDirection.RIGHT)
	# 不在场景树中，立即执行完_red_execute_move和start_turn
	assert_eq(gm.current_state, GameManager.TurnState.IDLE, "执行完成后应开始新回合(IDLE)")

# ========== 红球取消选择测试 ==========

func test_cancel_red_direction_picking() -> void:
	gm.current_state = GameManager.TurnState.RED_DIRECTION_PICKING
	gm.selected_marble = red_marble
	gm.red_total_steps = 3
	gm.red_step_directions = [0, 1]
	gm.red_current_step_index = 2
	
	gm.cancel_selection()
	
	assert_eq(gm.current_state, GameManager.TurnState.IDLE, "取消后应回到IDLE状态")
	assert_null(gm.selected_marble, "应清空选中弹珠")
	assert_eq(gm.red_total_steps, 0, "应重置步数")
	assert_eq(gm.red_step_directions.size(), 0, "应清空方向列表")
	assert_eq(gm.red_current_step_index, 0, "应重置索引")

# ========== 红球方向列表完整流程测试 ==========

func test_red_flow_select_power_then_directions() -> void:
	# 模拟完整红球选择流程
	gm.current_state = GameManager.TurnState.MARBLE_SELECTED
	gm.selected_marble = red_marble
	gm.current_team = MarbleConst.Camp.RED
	
	# 选力度
	gm.red_select_power(2)
	assert_eq(gm.current_state, GameManager.TurnState.RED_DIRECTION_PICKING, "进入逐格选方向模式")
	
	# 选第1步方向（未满）
	gm.red_append_direction(MarbleConst.HexDirection.RIGHT)
	assert_eq(gm.current_state, GameManager.TurnState.RED_DIRECTION_PICKING, "第1步后保持RED_DIRECTION_PICKING")
	assert_eq(gm.red_step_directions.size(), 1, "第1步后有1个方向")
	assert_eq(gm.red_current_step_index, 1, "第1步后索引为1")
	assert_eq(gm.red_step_directions[0], MarbleConst.HexDirection.RIGHT, "第1步方向RIGHT")
	
	# 选第2步方向（满，触发执行）
	gm.red_append_direction(MarbleConst.HexDirection.RIGHT_UP)
	# 执行完成后，不在场景树中跳过await，start_turn将状态变为IDLE
	assert_eq(gm.current_state, GameManager.TurnState.IDLE, "执行完成后应开始新回合(IDLE)")

# ========== 红球移动+碰撞测试 ==========

func test_red_move_with_step_directions() -> void:
	# 测试 RedMarbleHelper.move_with_step_directions
	var dirs: Array[int] = [MarbleConst.HexDirection.RIGHT, MarbleConst.HexDirection.RIGHT]
	
	var success = RedMarbleHelper.move_with_step_directions(red_marble, dirs, 2)
	
	assert_true(success, "红球应成功移动2步")
	assert_eq(red_marble.hex_coord, Vector2(2, 0), "应从(0,0)移动到(2,0)")

func test_red_move_with_different_directions() -> void:
	# 测试每步不同方向
	var dirs: Array[int] = [MarbleConst.HexDirection.RIGHT, MarbleConst.HexDirection.RIGHT_UP]
	
	var success = RedMarbleHelper.move_with_step_directions(red_marble, dirs, 2)
	
	assert_true(success, "红球应成功移动2步不同方向")
	assert_eq(red_marble.hex_coord, Vector2(1, 1), "应从(0,0)经(1,0)到(1,1)")

func test_red_move_out_of_bounds_dies() -> void:
	# 从坐标够远的地方开始，确保出界
	red_marble.hex_coord = Vector2(-8, 0)
	grid.remove_marble_by_node(red_marble)
	grid.place_marble(red_marble, -8, 0)
	
	var dirs: Array[int] = [MarbleConst.HexDirection.LEFT]
	var success = RedMarbleHelper.move_with_step_directions(red_marble, dirs, 1)
	
	assert_false(success, "出界应返回false")
	assert_false(red_marble.is_alive, "出界后弹珠应死亡")

func test_red_move_collision_triggers_continue() -> void:
	# 在(1,0)放置一个敌方弹珠
	var enemy = Marble2D.new()
	enemy.hex_grid = grid
	enemy.hex_coord = Vector2(1, 0)
	enemy.camp = MarbleConst.Camp.BLUE
	enemy.color = MarbleConst.MarbleColor.WHITE
	enemy.is_alive = true
	grid.place_marble(enemy, 1, 0)
	# 加入 all_marbles 以便后续清理
	gm.all_marbles.append(enemy)
	
	var dirs: Array[int] = [MarbleConst.HexDirection.RIGHT, MarbleConst.HexDirection.RIGHT]
	var success = RedMarbleHelper.move_with_step_directions(red_marble, dirs, 2)
	
	assert_true(success, "红球碰撞后应停止移动（不死亡）")
	assert_true(red_marble.is_alive, "红球碰撞后应存活")
	assert_eq(red_marble.hex_coord, Vector2(0, 0), "红球应停在原地（碰撞发生的位置）")
	
	enemy.queue_free()

# ========== 红球与GameManager状态集成测试 ==========

func test_red_select_marble_shows_special_prompt() -> void:
	# 测试选中红球时select_marble的行为
	gm.current_state = GameManager.TurnState.IDLE
	gm.current_team = MarbleConst.Camp.RED
	gm.select_marble(red_marble)
	
	# 红球选中后应仍在MARBLE_SELECTED状态（等待选力度）
	assert_eq(gm.current_state, GameManager.TurnState.MARBLE_SELECTED)
	# red_step相关变量应保持初始值
	assert_eq(gm.red_total_steps, 0)
	assert_eq(gm.red_step_directions.size(), 0)

func test_non_red_marble_uses_normal_flow() -> void:
	# 非红球弹珠选中后 select_marble 的流程不变
	var white_marble = Marble2D.new()
	white_marble.hex_grid = grid
	white_marble.hex_coord = Vector2(2, 0)
	white_marble.camp = MarbleConst.Camp.RED
	white_marble.color = MarbleConst.MarbleColor.WHITE
	white_marble.is_alive = true
	grid.place_marble(white_marble, 2, 0)
	
	gm.current_state = GameManager.TurnState.IDLE
	gm.current_team = MarbleConst.Camp.RED
	gm.select_marble(white_marble)
	
	assert_eq(gm.current_state, GameManager.TurnState.MARBLE_SELECTED)
	
	white_marble.queue_free()
