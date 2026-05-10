# Board.gd - 挂载在棋盘场景的 Node2D 上
extends Node2D

# ========== 棋盘参数 ==========
@export var hex_size: float = 30.0  # 六边形边长（像素），可调整
var board_center: Vector2           # 屏幕中心点，运行时自动计算

# ========== 弹珠列表 ==========
var all_marbles: Array = []

# ========== 方向环和力度条 ==========
var direction_buttons: Array = []  # [{position, direction}]
var power_buttons: Array = []      # [{position, value}]


func _ready():
	# 自动计算屏幕中心
	board_center = get_viewport().get_visible_rect().size / 2
	
	# 收集场景中所有弹珠节点
	for child in get_tree().get_nodes_in_group("marbles"):
		all_marbles.append(child)


# ========== 坐标转换 ==========

func hex_to_pixel(hex: Vector2) -> Vector2:
	"""六边形坐标 (q, r) 转屏幕像素坐标"""
	var sqrt3 = 1.73205
	var px = board_center.x + hex_size * sqrt3 * (hex.x + hex.y / 2.0)
	var py = board_center.y + hex_size * (3.0 / 2.0) * hex.y
	return Vector2(px, py)


func pixel_to_hex(pixel: Vector2) -> Vector2:
	"""屏幕像素坐标转六边形坐标 (q, r)"""
	var sqrt3 = 1.73205
	var dx = pixel.x - board_center.x
	var dy = pixel.y - board_center.y
	var r = round(dy / (hex_size * 1.5))
	var q = round((dx / hex_size - sqrt3 / 2.0 * r) / sqrt3)
	return Vector2(q, r)


# ========== 鼠标输入 ==========

func _unhandled_input(event):
	var gm = get_node("/root/GameManager")
	if gm.current_state == gm.EXECUTING:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		handle_click(event.position)


func handle_click(pos: Vector2):
	var gm = get_node("/root/GameManager")
	
	match gm.current_state:
		gm.IDLE:
			_try_select_marble(pos)
		gm.MARBLE_SELECTED:
			_try_select_direction(pos)
		gm.DIRECTION_SELECTED:
			_try_select_power(pos)


func _try_select_marble(pos: Vector2):
	var gm = get_node("/root/GameManager")
	for marble in all_marbles:
		if marble.camp == gm.current_team and marble.is_alive:
			var marble_pixel = hex_to_pixel(marble.hex_coord)
			if pos.distance_to(marble_pixel) < hex_size:
				gm.selected_marble = marble
				gm.current_state = gm.MARBLE_SELECTED
				marble.highlight()
				print("请选择移动方向")
				queue_redraw()
				return


func _try_select_direction(pos: Vector2):
	var gm = get_node("/root/GameManager")
	var dir = _get_clicked_direction(pos)
	if dir:
		gm.selected_direction = dir
		gm.current_state = gm.DIRECTION_SELECTED
		print("请选择力度")
		queue_redraw()
	else:
		# 点空白取消选择
		gm.selected_marble.unhighlight()
		gm.selected_marble = null
		gm.current_state = gm.IDLE
		queue_redraw()


func _try_select_power(pos: Vector2):
	var gm = get_node("/root/GameManager")
	var power = _get_clicked_power(pos)
	if power > 0:
		gm.selected_power = power
		gm.execute_move()
	else:
		# 点空白退回选方向
		gm.current_state = gm.MARBLE_SELECTED
		queue_redraw()


# ========== 方向环点击判定 ==========

func _get_clicked_direction(pos: Vector2) -> String:
	for btn in direction_buttons:
		if pos.distance_to(btn["position"]) < 22:
			return btn["direction"]
	return ""


func _get_clicked_power(pos: Vector2) -> int:
	for btn in power_buttons:
		if pos.distance_to(btn["position"]) < 20:
			return btn["value"]
	return 0

# ========== 新增：棋盘数据管理（从 HexGrid3D 合并） ==========

var grid_radius: int = 8   # 棋盘半径（D < 8，即最大7）
var marbles_dict: Dictionary = {}  # key=Vector2(q,r), value=弹珠节点

# 检查坐标是否在棋盘内
func is_on_board(hex: Vector2) -> bool:
	var q = int(hex.x)
	var r = int(hex.y)
	var s = -q - r
	return abs(q) <= grid_radius and abs(r) <= grid_radius and abs(s) <= grid_radius

# 获取指定坐标上的弹珠（没有则返回 null）
func get_marble_at_hex(hex: Vector2):
	return marbles_dict.get(hex, null)

# 移动弹珠（从旧坐标到新坐标）
func move_marble_on_board(marble, from_hex: Vector2, to_hex: Vector2):
	marbles_dict.erase(from_hex)
	marbles_dict[to_hex] = marble
	marble.hex_coord = to_hex
	marble.position = hex_to_pixel(to_hex)

# 放置弹珠到棋盘
func place_marble_on_board(marble, hex: Vector2):
	marbles_dict[hex] = marble
	marble.hex_coord = hex
	marble.position = hex_to_pixel(hex)

# 移除弹珠
func remove_marble_from_board(marble):
	for key in marbles_dict.keys():
		if marbles_dict[key] == marble:
			marbles_dict.erase(key)
			break
