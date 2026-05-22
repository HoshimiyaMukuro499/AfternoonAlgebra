# HexGridDrawer.gd
# 独立绘制六边形棋盘，不修改 HexGrid2D 原有代码

extends Node2D

# 要绘制的棋盘节点（在场景中指定）
@export var hex_grid: HexGrid2D

# 绘制颜色和线宽
@export var grid_color: Color = Color.WHITE
@export var line_width: float = 1.5

func _ready() -> void:
	if not hex_grid:
		var parent = get_parent()
		if parent is HexGrid2D:
			hex_grid = parent
		elif parent:
			hex_grid = parent.get_node_or_null("HexGrid2D")
	queue_redraw()

func _draw() -> void:
	if not hex_grid:
		return

	var radius: int = hex_grid.grid_radius       # 棋盘半径（默认7）
	var cell_size: float = hex_grid.cell_size     # HexGrid2D 的 cell_size（建议设为64）

	# 遍历棋盘范围内的所有六边形坐标
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s = -q - r
			if abs(s) > radius:
				continue      # 跳过棋盘外的格子

			var center = hex_grid.hex_to_world(q, r)
			var points = PackedVector2Array()

			# 尖顶六边形顶点（顶点朝上），偏移 30° 开始
			for i in range(6):
				var angle = deg_to_rad(30 + i * 60)
				var x = center.x + cell_size * cos(angle)
				var y = center.y + cell_size * sin(angle)
				points.append(Vector2(x, y))
			points.append(points[0])   # 闭合

			draw_polyline(points, grid_color, line_width)
