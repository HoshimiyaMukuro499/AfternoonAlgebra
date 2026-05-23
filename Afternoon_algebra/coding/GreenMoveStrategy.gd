# GreenMoveStrategy.gd
# 绿色移动策略：移动时的推挤行为
# 绿球每步移动时，如果目标格子有棋子，将该棋子沿移动方向推开（推挤），然后绿球移入目标格子。
extends "res://MoveStrategyBase.gd"

func execute(marble: Marble2D, direction: int, steps: int) -> bool:
	# 重写移动逻辑：绿球推开路径上的棋子，而不是被碰撞挡住
	var remaining = steps
	var current = marble.hex_coord if marble.hex_coord != Vector2.ZERO else marble.hex_grid.get_marble_hex(marble)

	while remaining > 0:
		var next = marble.get_neighbor_hex(current, direction)

		# 边界检查
		if marble.hex_grid.is_out_of_bounds(next.x, next.y):
			marble.die()
			return false

		# 检查目标格子是否有棋子
		var other = marble.hex_grid.get_marble_at(next.x, next.y)
		if other != null and other.is_alive:
			# 绿球推挤：将目标棋子沿相同方向推一格
			other.continue_move(1, direction)
			# 如果目标棋子被推走后格子空了（没死亡或被阻挡），绿球移入
			if marble.hex_grid.get_marble_at(next.x, next.y) == null:
				marble.hex_grid.move_marble(marble, current, next)
				current = next
				remaining -= 1
				marble.hex_coord = current
				marble.on_step_moved(current)
			else:
				# 目标棋子未被推开（死亡或被阻挡），绿球停止
				break
		else:
			# 空位：直接移动
			marble.hex_grid.move_marble(marble, current, next)
			current = next
			remaining -= 1
			marble.hex_coord = current
			marble.on_step_moved(current)

	# 返回 true 表示未死亡（即使未完成所有步数也没关系）
	return marble.is_alive

