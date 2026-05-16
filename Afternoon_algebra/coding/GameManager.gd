class_name GameManager
extends Node2D

signal state_changed(new_state)

var hex_grid: HexGrid2D
var all_marbles: Array[Marble2D] = []

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
	hex_grid = $HexGrid2D
	
	# 清理场景中的旧测试弹珠
	if has_node("Marble_Rigid"):
		$Marble_Rigid.queue_free()
	
	# 使用 BoardInitializer 初始化标准棋盘
	if hex_grid:
		all_marbles = BoardInitializer.initialize_board(hex_grid)
		_adjust_marble_visuals()
	
	# 初始化 UI
	_init_ui()
	
	randomize()
	current_team = MarbleConst.Camp.RED if randi() % 2 == 0 else MarbleConst.Camp.BLUE
	start_turn()

func _adjust_marble_visuals():
	if not hex_grid:
		return
	var target_size = hex_grid.cell_size * 1.2
	for marble in all_marbles:
		# 调整 Sprite 大小使其在棋盘上可见
		var sprite = marble._get_sprite_node()
		if sprite and sprite.texture:
			var tex_size = sprite.texture.get_size()
			var scale_factor = target_size / max(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)
		# 重置碰撞体到弹珠中心
		for child in marble.get_children():
			if child is CollisionShape2D:
				child.position = Vector2.ZERO

func _init_ui():
	# 查找或创建 UI 节点（先不加入场景树，等脚本挂载后再加入）
	var ui = get_node_or_null("UI")
	var need_add_child = false
	if not ui:
		ui = CanvasLayer.new()
		ui.name = "UI"
		need_add_child = true
	
	# 确保 UI 挂载了 UI.gd 脚本（在加入场景树前挂载，确保 _ready 被触发）
	if ui.get_script() == null:
		var ui_script = load("res://UI/UI.gd")
		if ui_script:
			ui.set_script(ui_script)
	
	if need_add_child:
		add_child(ui)
	
	# 创建或查找 TurnLabel
	var turn_label = ui.get_node_or_null("TurnLabel")
	if not turn_label:
		turn_label = Label.new()
		turn_label.name = "TurnLabel"
		turn_label.position = Vector2(20, 20)
		ui.add_child(turn_label)
	
	# 创建或查找 MessageLabel
	var message_label = ui.get_node_or_null("MessageLabel")
	if not message_label:
		message_label = Label.new()
		message_label.name = "MessageLabel"
		message_label.position = Vector2(20, 50)
		ui.add_child(message_label)

func start_turn():
	current_state = TurnState.IDLE
	selected_marble = null
	selected_direction = -1
	selected_power = 0
	turn_number += 1
	print("第 %d 回合，%s 方行动" % [turn_number, "红" if current_team == MarbleConst.Camp.RED else "蓝"])
	state_changed.emit(current_state)

func select_marble(marble):
	if current_state != TurnState.IDLE: return
	if marble.camp != current_team or not marble.is_alive: return
	selected_marble = marble
	current_state = TurnState.MARBLE_SELECTED
	marble.highlight()
	print("选中弹珠，请选择方向")
	state_changed.emit(current_state)

func select_direction(direction: int):
	if current_state != TurnState.MARBLE_SELECTED: return
	selected_direction = direction
	current_state = TurnState.DIRECTION_SELECTED
	print("已选方向，请选择力度")
	state_changed.emit(current_state)

func select_power(power: int):
	if current_state != TurnState.DIRECTION_SELECTED: return
	selected_power = power
	execute_move()

func execute_move():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	if selected_marble and selected_marble.is_alive:
		selected_marble.move(selected_direction, selected_power)
	await get_tree().create_timer(0.5).timeout
	# 检查胜负 + 切换回合
	current_team = MarbleConst.Camp.BLUE if current_team == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	start_turn()

func cancel_selection():
	if current_state == TurnState.IDLE or current_state == TurnState.EXECUTING: return
	if selected_marble:
		selected_marble.unhighlight()
	selected_marble = null
	current_state = TurnState.IDLE
	print("已取消选择")
	state_changed.emit(current_state)
