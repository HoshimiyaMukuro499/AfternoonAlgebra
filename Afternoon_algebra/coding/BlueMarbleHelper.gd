# BlueMarbleHelper.gd
# 将蓝球特有的逻辑（随从生成、移动、清除）提取为静态方法，供 BlueMarble 和 WhiteMarble（变色后）复用，
# 避免代码重复。此类不依赖弹珠的具体类型，只需传入一个 Marble2D 实例即可。
#
# 2D 版本：随从使用 Sprite2D + 圆形纹理

class_name BlueMarbleHelper
extends RefCounted


# ---------- 公开工具方法 ----------
# 生成随从列表，返回随从节点数组（Node2D）
# marble: 弹珠实例（蓝球或变为蓝色的白球）
# direction: 移动方向（0~5）
static func spawn_followers(marble: Marble2D, direction: int) -> Array[Node2D]:
	var followers: Array[Node2D] = []
	var spawn_cells = _get_follower_spawn_cells(marble, direction)
	for cell in spawn_cells:
		followers.append(_create_follower(marble, cell))
	return followers


# 移动所有随从，按相同的方向和步数移动
# 返回值：如果所有随从移动过程中均未出界，返回 true；只要有一个出界就返回 false
static func move_followers(marble: Marble2D, followers: Array[Node2D], direction: int, steps: int) -> bool:
	for f in followers:
		var start = marble.hex_grid.get_marble_hex(f)
		var ok = _move_follower(marble, f, start, direction, steps)
		if not ok:
			return false
	return true


# 清除所有随从（从棋盘移除并释放节点）
static func clear_followers(marble: Marble2D, followers: Array[Node2D]) -> void:
	for f in followers:
		if is_instance_valid(f):
			marble.hex_grid.remove_marble_by_node(f)
			f.queue_free()
	followers.clear()


# ---------- 私有实现细节（静态） ----------
# 计算随从生成的位置（与移动方向不共线的相邻格子，最多2个）
static func _get_follower_spawn_cells(marble: Marble2D, dir: int) -> Array[Vector2]:
	# 与移动方向夹角 ±60° 的两个方向
	var left = (dir + 1) % 6
	var right = (dir + 5) % 6
	var candidates: Array[Vector2] = []
	var start = marble.get_current_hex()
	
	# 优先在左右两侧生成
	for d in [left, right]:
		var pos = marble.get_neighbor_hex(start, d)
		if not marble.hex_grid.is_out_of_bounds(pos.x, pos.y) and marble.hex_grid.get_marble_at(pos.x, pos.y) == null:
			candidates.append(pos)
	
	# 如果不足2个，从其他不共线方向随机补足
	if candidates.size() < 2:
		var other_dirs = []
		for d in range(6):
			if d != dir and d != left and d != right:
				other_dirs.append(d)
		other_dirs.shuffle()   # 随机顺序（网络版应由服务器决定）
		for d in other_dirs:
			if candidates.size() >= 2:
				break
			var pos = marble.get_neighbor_hex(start, d)
			if not marble.hex_grid.is_out_of_bounds(pos.x, pos.y) and marble.hex_grid.get_marble_at(pos.x, pos.y) == null:
				candidates.append(pos)
	
	return candidates.slice(0, 2)


# 创建一个随从节点（青色圆形 Sprite2D）
static func _create_follower(marble: Marble2D, cell: Vector2) -> Node2D:
	var follower = Sprite2D.new()
	# 创建圆形纹理（直径 32 像素）
	var texture = _create_circle_texture(16, Color.CYAN)  # 半径 16px
	follower.texture = texture
	follower.centered = true
	follower.scale = Vector2(0.5, 0.5)   # 适当缩放，使其大小与弹珠匹配
	# 添加到棋盘管理器中，并更新其坐标
	marble.hex_grid.add_child(follower)
	marble.hex_grid.place_marble(follower, cell.x, cell.y)
	return follower


# 辅助函数：生成圆形纹理（静态方法，可复用）
static func _create_circle_texture(radius: int, color: Color) -> Texture2D:
	var size = radius * 2
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(size):
		for y in range(size):
			var dx = x - radius
			var dy = y - radius
			if dx*dx + dy*dy <= radius*radius:
				image.set_pixel(x, y, color)
	var texture = ImageTexture.create_from_image(image)
	return texture


# 移动单个随从，返回是否未出界
static func _move_follower(marble: Marble2D, follower: Node2D, start: Vector2, dir: int, steps: int) -> bool:
	var remaining = steps
	var current = start
	while remaining > 0:
		var next = marble.get_neighbor_hex(current, dir)
		# 出界即失败
		if marble.hex_grid.is_out_of_bounds(next.x, next.y):
			return false
		var other = marble.hex_grid.get_marble_at(next.x, next.y)
		if other != null and other.is_alive:
			# 随从撞到其他弹珠：随从停下，对方获得剩余步数继续移动
			other.continue_move(remaining, dir)
			break
		else:
			# 空位：直接移动随从
			marble.hex_grid.move_marble(follower, current, next)
			current = next
			remaining -= 1
	return true
