# RedMarbleHelper.gd
# 红球（定向步进）公用逻辑，供 RedMarble 和 WhiteMarble（变色后）复用

class_name RedMarbleHelper
extends RefCounted

# 红球逐格移动（支持每步不同方向）
static func move_with_step_directions(marble: Marble2D, step_dirs: Array[int], total_steps: int) -> bool:
	if step_dirs.size() != total_steps:
		return false
	
	var remaining = total_steps
	var current = marble.get_current_hex()
	var step_index = 0
	
	while remaining > 0:
		var direction = step_dirs[step_index]
		var next = marble.get_neighbor_hex(current, direction)
		
		if marble.hex_grid.is_out_of_bounds(next.x, next.y):
			marble.die()
			return false
		
		var other = marble.hex_grid.get_marble_at(next.x, next.y)
		if other != null and other.is_alive:
			other.continue_move(remaining, direction)
			break
		else:
			marble.hex_grid.move_marble(marble, current, next)
			current = next
			remaining -= 1
			step_index += 1
			marble.hex_coord = current
			marble.on_step_moved(current)
	
	return true
