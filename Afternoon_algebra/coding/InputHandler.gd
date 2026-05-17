extends Node2D

# 六边形轴向坐标的六个邻居偏移量（点顶朝向）
const NEIGHBOR_OFFSETS = [
	Vector2(1, 0),   # 0: 东
	Vector2(0, 1),   # 1: 东南
	Vector2(-1, 1),  # 2: 西南
	Vector2(-1, 0),  # 3: 西
	Vector2(0, -1),  # 4: 西北
	Vector2(1, -1)   # 5: 东北
]

var game_manager: GameManager

func _ready():
	game_manager = get_node_or_null("/root/Node2D")
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 将全局鼠标坐标转换为 HexGrid2D 的局部坐标
		var local_pos = game_manager.hex_grid.to_local(get_global_mouse_position())
		_handle_click(local_pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		game_manager.cancel_selection()

func _handle_click(pos: Vector2):
	match game_manager.current_state:
		GameManager.TurnState.IDLE:
			_try_select_marble(pos)
		GameManager.TurnState.MARBLE_SELECTED:
			_try_select_direction(pos)
		GameManager.TurnState.DIRECTION_SELECTED:
			_try_select_power(pos)

func _try_select_marble(pos: Vector2):
	var hex = game_manager.hex_grid.world_to_hex(pos)
	var marble = game_manager.hex_grid.get_marble_at(int(hex.x), int(hex.y))
	if marble and marble.is_alive and marble.camp == game_manager.current_team:
		game_manager.select_marble(marble)
		return

func _try_select_direction(pos: Vector2):
	if not game_manager.selected_marble:
		return
	var current_hex = game_manager.selected_marble.get_current_hex()
	for dir in range(6):
		# 直接使用已知的偏移量计算邻居坐标，避免依赖 get_neighbor_hex 可能存在的错误
		var neighbor = current_hex + NEIGHBOR_OFFSETS[dir]
		var neighbor_pos = game_manager.hex_grid.hex_to_world(neighbor.x, neighbor.y)
		if pos.distance_to(neighbor_pos) < 25:
			game_manager.select_direction(dir)
			return
	game_manager.cancel_selection()

func _try_select_power(pos: Vector2):
	pass

func _input(event):
	if game_manager.current_state != GameManager.TurnState.DIRECTION_SELECTED:
		return
	if event is InputEventKey and event.pressed:
		var key_map = {
			KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5
		}
		if event.keycode in key_map:
			game_manager.select_power(key_map[event.keycode])
