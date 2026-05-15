# GameManager.gd - 合并版
class_name GameManager
extends Node2D

# ====== 原有：棋盘引用 ======
var hex_grid: HexGrid2D
var test_marble: Marble2D
var all_marbles: Array[Marble2D] = []
# ====== 新增：状态机 ======
enum TurnState {
	IDLE,
	MARBLE_SELECTED,
	DIRECTION_SELECTED,
	EXECUTING
}
var current_state = TurnState.IDLE
var selected_marble = null
var selected_direction: int = -1
var selected_power: int = 0
var current_team = MarbleConst.Camp.RED
var turn_number: int = 0

func _ready():
	# ====== 原有：获取节点 ======
	hex_grid = $HexGrid2D
	if hex_grid:
		all_marbles = BoardInitializer.initialize_board(hex_grid)
		print("棋盘初始化完成，弹珠数量: ", all_marbles.size())
	else:
		push_error("GameManager: 找不到 HexGrid2D 节点")
		
	test_marble = $Marble_Rigid/Marble/WhiteMarble  # 改成你在场景里的实际节点名
	
	if hex_grid and test_marble:
		hex_grid.place_marble(test_marble, 0, 0)
		print("弹珠已放置到棋盘中心坐标(0,0)")
	
	# ====== 新增：开始回合 ======
	randomize()
	current_team = MarbleConst.Camp.RED if randi() % 2 == 0 else MarbleConst.Camp.BLUE
	start_turn()

# ====== 原有：回车测试 ======
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if current_state == TurnState.IDLE:
			test_marble.move(MarbleConst.HexDirection.RIGHT, 2)

# ====== 新增：状态机方法 ======
func start_turn():
	current_state = TurnState.IDLE
	selected_marble = null
	selected_direction = -1
	selected_power = 0
	turn_number += 1
	print("第 %d 回合，%s 方行动" % [turn_number, "红" if current_team == MarbleConst.Camp.RED else "蓝"])

# 修改 select_marble 方法，添加更多安全检查和调试信息
func select_marble(marble):
	
	if current_state != TurnState.IDLE:
		print("当前状态不能选择弹珠: ", current_state)
		return
	if not marble or not marble.is_alive:
		print("弹珠无效或已死亡")
		return
	if marble.camp != current_team:
		print("不是当前回合方的弹珠")
		return
	
	selected_marble = marble
	current_state = TurnState.MARBLE_SELECTED
	marble.highlight()
	print("选中弹珠，请选择方向")

func select_direction(direction: int):
	if current_state != TurnState.MARBLE_SELECTED: return
	selected_direction = direction
	current_state = TurnState.DIRECTION_SELECTED
	print("已选方向，请选择力度")

func select_power(power: int):
	if current_state != TurnState.DIRECTION_SELECTED: return
	selected_power = power
	execute_move()

func execute_move():
	current_state = TurnState.EXECUTING
	if selected_marble and selected_marble.is_alive:
		selected_marble.move(selected_direction, selected_power)
	await get_tree().create_timer(0.5).timeout
	# 检查胜负 + 切换回合
	current_team = MarbleConst.Camp.BLUE if current_team == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	start_turn()

# 改进 cancel_selection
func cancel_selection():
	if current_state == TurnState.IDLE or current_state == TurnState.EXECUTING:
		return
	if selected_marble and is_instance_valid(selected_marble):
		selected_marble.unhighlight()
	selected_marble = null
	current_state = TurnState.IDLE
	print("已取消选择")
