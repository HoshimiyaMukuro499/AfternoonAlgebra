# HexGrid2D.gd（2D棋盘控制器脚本）
class_name HexGrid2D
extends Node2D

# 导出配置，方便在编辑器里调整参数
@export var grid_radius: int = MarbleConst.GRID_RADIUS
@export var cell_size: float = MarbleConst.CELL_SIZE

# 棋盘数据：key=六边形坐标(q,r)，value=对应位置的弹珠节点
var marbles: Dictionary = {}


# 把六边形坐标(q,r)转换成2D世界坐标（返回 Vector2）
func hex_to_world(q: int, r: int) -> Vector2:
	# 轴对齐六边形坐标转世界坐标公式（使用 2D 平铺布局）
	var world_x: float = cell_size * (sqrt(3) * q + sqrt(3)/2 * r)
	var world_y: float = cell_size * (3.0/2 * r)
	return Vector2(world_x, world_y)
#与之对应
func world_to_hex(world_pos: Vector2) -> Vector2:
	var sqrt3 = sqrt(3)
	var q = (world_pos.x * sqrt3 / 3 - world_pos.y / 3) / cell_size
	var r = (world_pos.y * 2.0 / 3) / cell_size
	return Vector2(round(q), round(r))

# 检查六边形坐标是否超出棋盘边界
func is_out_of_bounds(q: int, r: int) -> bool:
	# 六边形坐标边界判定规则
	var s: int = -q - r
	return abs(q) > grid_radius or abs(r) > grid_radius or abs(s) > grid_radius


# 将弹珠放置到指定的六边形坐标上
func place_marble(marble: Node2D, q: int, r: int) -> void:
	# 先移除旧位置的记录（如果有的话）
	if marble.has_meta("hex_pos"):
		var old_pos: Vector2 = marble.get_meta("hex_pos")
		marbles.erase(old_pos)
	
	# 记录新位置并更新弹珠的世界坐标
	var hex_pos: Vector2 = Vector2(q, r)
	marbles[hex_pos] = marble
	marble.set_meta("hex_pos", hex_pos)
	marble.position = hex_to_world(q, r)

		# 关键修复：如果是 Marble2D 实例，同步其缓存坐标
	if marble is Marble2D:
		marble.update_hex_coord(hex_pos)

#这里应该是原来的“辅助功能”
# 从棋盘上移除指定坐标的弹珠
func remove_marble(q: int, r: int) -> void:
	var hex_pos: Vector2 = Vector2(q, r)
	if marbles.has(hex_pos):
		marbles.erase(hex_pos)
		# 辅助方法：根据弹珠节点获取其六边形坐标
func get_marble_hex(marble: Node2D) -> Vector2:
	if marble.has_meta("hex_pos"):
		return marble.get_meta("hex_pos")
	return Vector2.ZERO   # 未放置时返回(0,0)作为默认坐标

# 辅助方法：获取指定坐标上的弹珠节点
func get_marble_at(q: int, r: int) -> Node2D:
	return marbles.get(Vector2(q, r), null)

# 辅助方法：移动弹珠到相邻格子（不检查出界，仅更新内部字典和位置）
func move_marble(marble: Node2D, from_hex: Vector2, to_hex: Vector2) -> void:
	marbles.erase(from_hex)
	marbles[to_hex] = marble
	marble.set_meta("hex_pos", to_hex)
	marble.position = hex_to_world(to_hex.x, to_hex.y)

# 辅助方法：根据节点移除弹珠（无需提供坐标）
func remove_marble_by_node(marble: Node2D) -> void:
	var hex = get_marble_hex(marble)
	marbles.erase(hex)

# 选珠阶段区域判定
func is_in_red_zone(q: int, r: int) -> bool:
	var s = -q - r
	var D = max(abs(q), abs(r), abs(s))
	return q >= -7 and q <= -2 and D <= 8

func is_in_blue_zone(q: int, r: int) -> bool:
	var s = -q - r
	var D = max(abs(q), abs(r), abs(s))
	return q >= 2 and q <= 7 and D <= 8

func get_available_positions(camp: int) -> Array:
	var positions = []
	for q in range(-7, 8):
		for r in range(-7, 8):
			if is_out_of_bounds(q, r):
				continue
			if camp == MarbleConst.Camp.RED and is_in_red_zone(q, r):
				positions.append(Vector2(q, r))
			elif camp == MarbleConst.Camp.BLUE and is_in_blue_zone(q, r):
				positions.append(Vector2(q, r))
	return positions

# 高亮显示可放置区域
var highlight_positions: Array = []
var highlight_color: Color = Color(0.5, 0.5, 1.0, 0.3)  # 淡蓝色

func draw_available_positions(camp: int):
	highlight_positions = get_available_positions(camp)
	if camp == MarbleConst.Camp.RED:
		highlight_color = Color(1.0, 0.5, 0.5, 0.3)  # 淡红色
	else:
		highlight_color = Color(0.5, 0.5, 1.0, 0.3)  # 淡蓝色
	queue_redraw()

func clear_highlights():
	highlight_positions.clear()
	queue_redraw()

func _draw():
	if highlight_positions.size() > 0:
		for pos in highlight_positions:
			var world_pos = hex_to_world(int(pos.x), int(pos.y))
			draw_circle(world_pos, cell_size * 0.4, highlight_color)
