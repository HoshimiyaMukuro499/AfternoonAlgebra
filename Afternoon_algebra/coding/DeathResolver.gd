# DeathResolver.gd
# 死亡结算工具：处理同时发生的多个死亡事件，为阵营按规则分配白球变色。
#
# 规则说明（详见 game_rule.md 第五节第1条）：
# 1. 按阵营分组处理，每组内对每个死亡事件找一个己方存活白球变色。
# 2. 优先选未变色（has_changed == false）的白球；若已无未变色白球，则覆盖已变色白球。
# 3. 黄球死亡不触发变色（YellowMarbleHelper 专门处理黄球增益）。
#
# 此类为纯函数工具，不依赖场景树或节点生命周期。

class_name DeathResolver
extends RefCounted

# ---------- 数据结构 ----------

# 死亡事件结构：谁死了、什么颜色、什么阵营
# 使用 Dictionary 模拟结构体：
# { "marble_id": int, "color": MarbleConst.MarbleColor, "camp": MarbleConst.Camp }
# marble_id 可用 instance_id 或自定义 ID，用于日志/追踪

# 变色事件结构：哪个白球变色、从什么颜色变成什么颜色
# { "white_marble_id": int, "from_color": MarbleConst.MarbleColor, "to_color": MarbleConst.MarbleColor }


# ---------- 核心算法 ----------

# 结算同时死亡，返回变色事件列表。
#
# 参数：
#   death_events: Array[Dictionary] - 死亡事件列表，每个事件包含：
#       { "color": MarbleConst.MarbleColor, "camp": MarbleConst.Camp }
#   white_marbles: Array[Dictionary] - 场上所有存活白球信息，每个包含：
#       { "id": int, "camp": MarbleConst.Camp, "has_changed": bool, "current_color": MarbleConst.MarbleColor }
#
# 返回：
#   Array[Dictionary] - 变色事件列表，每条包含：
#       { "white_id": int, "from_color": MarbleConst.MarbleColor, "to_color": MarbleConst.MarbleColor }
#
# 注意：此函数不会修改传入的 white_marbles，仅返回需要执行的变色事件。
# 调用方（如 GameManager）应根据返回结果逐一调用 white_marble.on_teammate_died()。
static func resolve_simultaneous_deaths(death_events: Array, white_marbles: Array) -> Array:
	var color_changes: Array = []
	
	# 1. 过滤掉黄球死亡（黄球不触发变色）
	var filtered_deaths: Array = []
	for ev in death_events:
		if ev.get("color", -1) != MarbleConst.MarbleColor.YELLOW:
			filtered_deaths.append(ev)
	
	if filtered_deaths.is_empty():
		return color_changes
	
	# 2. 死亡事件按阵营分组
	var deaths_by_camp: Dictionary = {}  # camp -> Array[death_event]
	for ev in filtered_deaths:
		var camp = ev.get("camp", -1)
		if not deaths_by_camp.has(camp):
			deaths_by_camp[camp] = []
		deaths_by_camp[camp].append(ev)
	
	# 3. 白球按阵营分组
	var whites_by_camp: Dictionary = {}  # camp -> Array[white_info]
	for w in white_marbles:
		var camp = w.get("camp", -1)
		if not whites_by_camp.has(camp):
			whites_by_camp[camp] = []
		whites_by_camp[camp].append(w)
	
	# 4. 对每个阵营，逐个处理死亡事件
	for camp in deaths_by_camp.keys():
		var camp_deaths: Array = deaths_by_camp[camp]
		var camp_whites: Array = whites_by_camp.get(camp, []).duplicate()
		
		if camp_whites.is_empty():
			# 该阵营没有白球，无法变色
			continue
		
		# 对该阵营的每个死亡事件，分配一个白球
		for ev in camp_deaths:
			var dead_color = ev.get("color", -1)
			if dead_color == -1:
				continue
			
			# 找一个合适的白球：优先未变色，若全部已变色则选第一个覆盖
			var chosen_white = _pick_white_for_change(camp_whites)
			if chosen_white.is_empty():
				continue
			
			# 记录变色事件
			var from_color = chosen_white.get("current_color", MarbleConst.MarbleColor.WHITE)
			color_changes.append({
				"white_id": chosen_white.get("id", -1),
				"from_color": from_color,
				"to_color": dead_color
			})
			
			# 更新副本状态：标记为已变色（后续死亡事件优先选其他未变色白球）
			chosen_white["has_changed"] = true
			chosen_white["current_color"] = dead_color
	
	return color_changes


# 从白球列表中选出一个用于变色的白球。
# 优先选 has_changed == false 的；若全部已变色，则选第一个（覆盖）。
# 返回选中的白球信息（引用，可修改），不删除列表中的元素。
static func _pick_white_for_change(whites: Array) -> Dictionary:
	if whites.is_empty():
		return {}
	
	# 先找未变色的
	for i in range(whites.size()):
		var w = whites[i]
		if not w.get("has_changed", false):
			return w
	
	# 全部已变色，取第一个覆盖
	return whites[0]
