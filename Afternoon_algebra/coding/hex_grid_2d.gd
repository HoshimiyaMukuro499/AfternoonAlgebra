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

#这里应该是原来的“辅助功能”
# 从棋盘上移除指定坐标的弹珠
func remove_marble(q: int, r: int) -> void:
	var hex_pos: Vector2 = Vector2(q, r)
	if marbles.has(hex_pos):
		marbles.erase(hex_pos)

func get_marble_hex(marble: Node2D) -> Vector2:
	return marble.get_meta("hex_pos")

func get_marble_at(q: int, r: int) -> Node2D:
	return marbles.get(Vector2(q, r), null)

func move_marble(marble: Node2D, from_hex: Vector2, to_hex: Vector2) -> void:
	marbles.erase(from_hex)
	marbles[to_hex] = marble
	marble.set_meta("hex_pos", to_hex)
	marble.position = hex_to_world(to_hex.x, to_hex.y)

func remove_marble_by_node(marble: Node2D) -> void:
	var hex = get_marble_hex(marble)
	marbles.erase(hex)
