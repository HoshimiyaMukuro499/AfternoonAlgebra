# HexGrid3D.gd（3D棋盘控制器脚本）
class_name HexGrid3D
extends Node3D

# 导出配置，方便队友在编辑器里调整参数
@export var grid_radius: int = MarbleConst.GRID_RADIUS
@export var cell_size: float = MarbleConst.CELL_SIZE


# 棋盘数据：key=六边形坐标(q,r)，value=对应位置的弹珠节点
var marbles: Dictionary = {}


# 把六边形坐标(q,r)转换成3D世界坐标（棋盘在XZ平面，Y轴为高度）
func hex_to_world(q: int, r: int) -> Vector3:
	# 轴对齐六边形坐标转世界坐标公式
	var world_x: float = cell_size * (sqrt(3) * q + sqrt(3)/2 * r)
	var world_z: float = cell_size * (1.5 * r)
	return Vector3(world_x, 0, world_z)  # Y轴固定为0，让弹珠落在地面


# 检查六边形坐标是否超出棋盘边界
func is_out_of_bounds(q: int, r: int) -> bool:
	# 六边形坐标边界判定规则
	var s: int = -q - r
	return abs(q) > grid_radius or abs(r) > grid_radius or abs(s) > grid_radius


# 将弹珠放置到指定的六边形坐标上
func place_marble(marble: Node3D, q: int, r: int) -> void:
	# 先移除旧位置的记录（如果有的话）
	if marble.has_meta("hex_pos"):
		var old_pos: Vector2 = marble.get_meta("hex_pos")
		marbles.erase(old_pos)
	
	# 记录新位置并更新弹珠的世界坐标
	var hex_pos: Vector2 = Vector2(q, r)
	marbles[hex_pos] = marble
	marble.set_meta("hex_pos", hex_pos)
	marble.position = hex_to_world(q, r)


# 从棋盘上移除指定坐标的弹珠
func remove_marble(q: int, r: int) -> void:
	var hex_pos: Vector2 = Vector2(q, r)
	if marbles.has(hex_pos):
		marbles.erase(hex_pos)