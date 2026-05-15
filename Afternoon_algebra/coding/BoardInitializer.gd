# BoardInitializer.gd
class_name BoardInitializer
extends Node

# 初始化双方弹珠
static func initialize_board(hex_grid: HexGrid2D) -> Array[Marble2D]:
	var all_marbles: Array[Marble2D] = []
	
	# 红方起始位置（左侧）
	var red_positions = [
		Vector2(-3, 0), Vector2(-3, 1), Vector2(-2, -1),
		Vector2(-2, 0), Vector2(-2, 1), Vector2(-1, -1)
	]
	
	# 蓝方起始位置（右侧）
	var blue_positions = [
		Vector2(3, -1), Vector2(3, 0), Vector2(2, -2),
		Vector2(2, -1), Vector2(2, 0), Vector2(1, -2)
	]
	
	# 每方的弹珠颜色配置（可根据需求调整）
	var red_colors = [
		MarbleConst.MarbleColor.WHITE,
		MarbleConst.MarbleColor.BLUE,
		MarbleConst.MarbleColor.GREEN,
		MarbleConst.MarbleColor.RED,
		MarbleConst.MarbleColor.BLACK,
		MarbleConst.MarbleColor.YELLOW
	]
	
	var blue_colors = [
		MarbleConst.MarbleColor.WHITE,
		MarbleConst.MarbleColor.BLUE,
		MarbleConst.MarbleColor.GREEN,
		MarbleConst.MarbleColor.RED,
		MarbleConst.MarbleColor.BLACK,
		MarbleConst.MarbleColor.YELLOW
	]
	
	# 创建红方弹珠
	for i in range(red_positions.size()):
		var marble = _create_marble(red_colors[i], MarbleConst.Camp.RED)
		hex_grid.place_marble(marble, red_positions[i].x, red_positions[i].y)
		all_marbles.append(marble)
	
	# 创建蓝方弹珠
	for i in range(blue_positions.size()):
		var marble = _create_marble(blue_colors[i], MarbleConst.Camp.BLUE)
		hex_grid.place_marble(marble, blue_positions[i].x, blue_positions[i].y)
		all_marbles.append(marble)
	
	print("初始化完成：创建了 %d 个弹珠" % all_marbles.size())
	return all_marbles

# 创建弹珠实例
static func _create_marble(color: int, camp: int) -> Marble2D:
	var scene_path = _get_marble_scene_path(color)
	var scene = load(scene_path)
	var marble: Marble2D
	
	if scene:
		marble = scene.instantiate()
	else:
		# 如果找不到专用场景，使用通用的 Marble2D 节点
		marble = Marble2D.new()
		
		# 添加 Sprite2D 子节点
		var sprite = Sprite2D.new()
		sprite.name = "Sprite"
		marble.add_child(sprite)
		
		# 添加 CollisionShape2D
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 16
		collision.shape = shape
		marble.add_child(collision)
	
	marble.color = color
	marble.camp = camp
	marble.is_alive = true
	
	return marble

static func _get_marble_scene_path(color: int) -> String:
	match color:
		MarbleConst.MarbleColor.WHITE:
			return "res://scenes/WhiteMarble.tscn"
		MarbleConst.MarbleColor.BLUE:
			return "res://scenes/BlueMarble.tscn"
		MarbleConst.MarbleColor.GREEN:
			return "res://scenes/GreenMarble.tscn"
		MarbleConst.MarbleColor.RED:
			return "res://scenes/RedMarble.tscn"
		MarbleConst.MarbleColor.BLACK:
			return "res://scenes/BlackMarble.tscn"
		MarbleConst.MarbleColor.YELLOW:
			return "res://scenes/YellowMarble.tscn"
		_:
			return ""
