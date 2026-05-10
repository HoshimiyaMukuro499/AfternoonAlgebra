# GameManager.gd - 游戏主控制器，自动加载单例
extends Node

# ========== 状态枚举 ==========
enum TurnState {
	IDLE,               # 空闲，等待点击己方弹珠
	MARBLE_SELECTED,    # 已选中弹珠，等待选方向
	DIRECTION_SELECTED, # 已选方向，等待选力度/步数
	EXECUTING           # 正在执行移动（禁止操作）
}

# ========== 状态变量 ==========
var current_state: TurnState = TurnState.IDLE
var selected_marble = null      # 当前选中的弹珠节点
var selected_direction = ""     # 当前选中的方向（0~5 方向索引字符串）
var selected_power: int = 0     # 当前选中的力度/步数
var current_team: String = "RED"  # 当前行动方 RED/BLUE
var turn_number: int = 0

# ========== 初始化 ==========
func _ready() -> void:
	print("GameManager 初始化完成")
	print("先手方: ", current_team)
	# 随机决定先后手
	randomize()
	current_team = "RED" if randi() % 2 == 0 else "BLUE"

# ========== 回合管理 ==========
func start_turn():
	current_state = TurnState.IDLE
	selected_marble = null
	selected_direction = ""
	selected_power = 0
	turn_number += 1
	print("第 %d 回合，%s 方行动" % [turn_number, current_team])

func end_turn():
	# 检查胜负
	if check_victory():
		return
	# 切换队伍
	current_team = "BLUE" if current_team == "RED" else "RED"
	start_turn()

func check_victory() -> bool:
	# 获取 Board 节点来检查弹珠存活情况
	var board = get_tree().get_first_node_in_group("board")
	if not board:
		return false
	var red_alive = 0
	var blue_alive = 0
	for marble in board.all_marbles:
		if marble.is_alive:
			if marble.camp == "RED":
				red_alive += 1
			elif marble.camp == "BLUE":
				blue_alive += 1
	if red_alive == 0:
		print("蓝方胜利！")
		return true
	if blue_alive == 0:
		print("红方胜利！")
		return true
	return false

# ========== 执行移动（第5步入口） ==========
func execute_move():
	current_state = TurnState.EXECUTING
	
	if not selected_marble or not selected_marble.is_alive:
		end_turn()
		return
	
	match selected_marble.color:
		"WHITE", "YELLOW":
			_move_basic()
		"BLUE":
			_move_blue()
		"GREEN":
			_move_basic()
			_push_green()
		"RED":
			_move_red()
		"BLACK":
			_move_black()
	
	# 等待移动动画完成后再结束回合
	await get_tree().create_timer(0.5).timeout
	end_turn()

func _move_basic():
	selected_marble.move(int(selected_direction), selected_power)

func _move_blue():
	# 蓝球逻辑：移动前生成随从，调用钩子
	selected_marble.move(int(selected_direction), selected_power)

func _push_green():
	# 绿球推挤在 on_after_move 钩子里处理
	pass

func _move_red():
	# 红球逐步移动在子状态机里处理
	selected_marble.move(int(selected_direction), selected_power)

func _move_black():
	# 黑球强制移动敌方弹珠
	pass
