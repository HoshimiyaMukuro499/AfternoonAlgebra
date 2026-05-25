class_name GameManager
extends Node2D

signal state_changed(new_state)
signal yellow_boost_requested(dead_yellow: Marble2D, candidates: Array[Marble2D])
const DIR_OFFSETS = [
	Vector2(1, 0),   # 0: RIGHT
	Vector2(0, 1),   # 1: SE
	Vector2(-1, 1),  # 2: SW
	Vector2(-1, 0),  # 3: LEFT
	Vector2(0, -1),  # 4: NW
	Vector2(1, -1)   # 5: NE
]
const BlueMarbleHelper = preload("res://BlueMarbleHelper.gd")

var hex_grid: HexGrid2D
var all_marbles: Array[Marble2D] = []
var last_alive_status: Dictionary = {}  # 记录每帧/每次移动前的存活状态 { instance_id: true/false }
var ui: CanvasLayer

enum TurnState {
	IDLE,
	MARBLE_SELECTED,
	DIRECTION_SELECTED,
	RED_DIRECTION_PICKING,
	EXECUTING,
	VICTORY,
	YELLOW_BOOST,   # 新增：等待选择黄球增益目标
	BLACK_SELECT_ENEMY,   # 选择敌方弹珠
	BLACK_SELECT_DIRECTION,# 选择大致方向
}
var current_state = TurnState.IDLE
var selected_marble = null
var selected_direction: int = -1
var selected_power: int = 0
var selected_enemy: Marble2D = null   # 黑球选中的敌方弹珠
var current_team = MarbleConst.Camp.RED
var turn_number: int = 0

# 红球逐格选方向专用变量
var red_step_directions: Array[int] = []
var red_total_steps: int = 0
var red_current_step_index: int = 0
var red_moved_steps: int = 0
var red_start_position: Vector2 = Vector2.ZERO  # 红球开始移动时的初始位置（用于取消时回退）

# 选珠布阵阶段变量
enum SetupState { COLOR_SELECT, PLACEMENT, FINISHED }
var setup_state = SetupState.COLOR_SELECT
var setup_current_team = MarbleConst.Camp.RED
var setup_remaining_marbles = { MarbleConst.Camp.RED: 6, MarbleConst.Camp.BLUE: 6 }
var setup_selected_color = -1
var setup_phase_active = false

# 随机阵型名称列表
const FORMATION_NAMES = [
	"天使夜莺阵",
	"刻刻帝阵",
	"冰结傀儡阵",
	"破军歌姬阵",
	"赝造魔女阵",
	"飓风骑士阵",
	"灼烂歼鬼阵",
	"鏖杀公阵",
	"神威灵装阵",
	"从零开始阵",
	"帕克冰封阵",
	"雷姆流星锤阵",
	"拉姆风刃阵",
	"爱蜜莉雅冰阵",
	"碧翠丝门阵",
	"剑圣加护阵",
	"嫉妒魔女阵",
	"强欲魔女阵",
	"为美好世界阵",
	"爆裂魔法阵",
	"惠惠爆裂阵",
	"阿库娅神光阵",
	"达克妮斯铁壁阵",
	"悠悠上级魔法阵",
	"维兹死亡冰阵",
	"巴尼尔面具阵",
	"御坂妹妹阵",
	"超电磁炮阵",
	"一方通行阵",
	"未元物质阵",
	"原子崩坏阵",
	"心中探测阵",
	"黑子瞬移阵",
	"佐天泪子阵",
	"初春饰利阵",
	"北冥神功阵",
	"八荒六合阵",
	"小无相功阵",
	"天山折梅阵",
	"生死符法阵",
	"化功大法阵",
	"吸星大法阵",
	"辟邪剑阵",
	"葵花宝典阵",
	"玉女素心阵",
	"左右互搏阵",
	"空明拳阵",
	"黯然销魂阵",
	"玄铁重剑阵",
	"金蛇迷踪阵",
	"神行百变阵",
	"凝血神爪阵",
	"化骨绵掌阵",
	"吸功大法阵"
]

func _ready():
	hex_grid = $HexGrid2D
	
	# 将棋盘居中
	var screen_size = get_viewport().get_visible_rect().size
	hex_grid.position = Vector2(screen_size.x / 2, screen_size.y / 2)
	
	# 清理场景中的旧测试弹珠
	if has_node("Marble_Rigid"):
		$Marble_Rigid.queue_free()
	
	# 创建背景
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color.WHITE  # 白色背景
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)
	# 将背景移到最底层
	move_child(background, 0)
	
	# 初始化 UI
	_init_ui()
	
	randomize()
	# 先手随机
	current_team = MarbleConst.Camp.RED if randi() % 2 == 0 else MarbleConst.Camp.BLUE
	setup_current_team = current_team
	start_setup_phase()

func start_setup_phase():
	setup_phase_active = true
	setup_state = SetupState.COLOR_SELECT
	setup_selected_color = -1
	setup_remaining_marbles = { MarbleConst.Camp.RED: 6, MarbleConst.Camp.BLUE: 6 }
	all_marbles.clear()
	
	if ui:
		ui.show_setup_phase(setup_current_team, setup_remaining_marbles[setup_current_team])
		ui.update_setup_message("请选择弹珠颜色（点击颜色按钮或按数字键1-6）")
	
	print("选珠阶段开始，%s 方先选" % ("红" if setup_current_team == MarbleConst.Camp.RED else "蓝"))

func setup_select_color(color: int):
	if not setup_phase_active:
		return
	if setup_state != SetupState.COLOR_SELECT:
		return
	if color < 0 or color >= MarbleConst.MarbleColor.size():
		return
	
	setup_selected_color = color
	setup_state = SetupState.PLACEMENT
	
	# 显示可放置区域高亮
	hex_grid.draw_available_positions(setup_current_team)
	
	if ui:
		ui.update_setup_message("请点击棋盘上的可放置位置（己方区域）")
		ui.highlight_available_positions(hex_grid.get_available_positions(setup_current_team))
	
	print("已选择颜色 %d，请放置" % color)

func setup_place_marble(q: int, r: int):
	if not setup_phase_active:
		return
	if setup_state != SetupState.PLACEMENT:
		return
	if setup_selected_color < 0:
		return
	
	# 检查是否已放置满6个弹珠
	var current_count = 0
	for m in all_marbles:
		if m.camp == setup_current_team:
			current_count += 1
	if current_count >= MarbleConst.TOTAL_MARBLE_COUNT:
		if ui:
			ui.update_setup_message("该方已放置满6个弹珠，请等待对方完成")
		return
	
	# 检查是否在己方区域内
	var in_zone = false
	if setup_current_team == MarbleConst.Camp.RED:
		in_zone = hex_grid.is_in_red_zone(q, r)
	else:
		in_zone = hex_grid.is_in_blue_zone(q, r)
	
	if not in_zone:
		if ui:
			ui.update_setup_message("此处为不可放置地块，可放置地块位于己方区域")
		return
	
	# 检查是否已被占用
	if hex_grid.get_marble_at(q, r) != null:
		if ui:
			ui.update_setup_message("该位置已被占用，请选择其他位置")
		return
	
	# 创建弹珠
	var marble = BoardInitializer.create_marble_for_setup(setup_selected_color, setup_current_team, hex_grid, q, r)
	all_marbles.append(marble)
	
	# 编号
	var count = 0
	for m in all_marbles:
		if m.camp == setup_current_team:
			count += 1
	marble.label_index = count
	marble.update_label()
	
	# 减少剩余数量
	setup_remaining_marbles[setup_current_team] -= 1
	
	if ui:
		ui.update_setup_remaining(setup_remaining_marbles[setup_current_team])
	
	# 清除高亮
	hex_grid.clear_highlights()
	
	# 检查是否完成
	if setup_remaining_marbles[setup_current_team] <= 0:
		# 生成随机阵型名称并显示
		var formation_name = FORMATION_NAMES[randi() % FORMATION_NAMES.size()]
		var team_name = "红方" if setup_current_team == MarbleConst.Camp.RED else "蓝方"
		if ui:
			ui.show_formation_name("哇，%s 竟然成功摆出了「%s」！" % [team_name, formation_name])
		
		# 等待阵型名称显示完毕（3秒）后再继续
		await get_tree().create_timer(3.0).timeout
		
		# 切换到对方
		if setup_current_team == MarbleConst.Camp.RED:
			setup_current_team = MarbleConst.Camp.BLUE
		else:
			setup_current_team = MarbleConst.Camp.RED
		
		if setup_remaining_marbles[setup_current_team] <= 0:
			# 双方都完成
			finish_setup_phase()
		else:
			setup_state = SetupState.COLOR_SELECT
			setup_selected_color = -1
			if ui:
				ui.show_setup_phase(setup_current_team, setup_remaining_marbles[setup_current_team])
				ui.update_setup_message("请选择弹珠颜色（点击颜色按钮或按数字键1-6）")
			print("轮到 %s 方选珠" % ("红" if setup_current_team == MarbleConst.Camp.RED else "蓝"))
	else:
		# 继续选择颜色
		setup_state = SetupState.COLOR_SELECT
		setup_selected_color = -1
		if ui:
			ui.update_setup_message("请选择弹珠颜色（点击颜色按钮或按数字键1-6）")

func finish_setup_phase():
	# 后手方阵型名称已在 setup_place_marble 中显示，此处不再重复显示
	
	setup_phase_active = false
	setup_state = SetupState.FINISHED
	
	# 清除高亮
	hex_grid.clear_highlights()
	
	# 调整弹珠视觉
	_adjust_marble_visuals()
	
	# 监听弹珠销毁事件
	for marble in all_marbles:
		marble.tree_exited.connect(_on_marble_freed.bind(marble))
	
	if ui:
		ui.hide_setup_phase()
		ui.update_message("布阵完成，游戏开始！")
	
	print("布阵完成，游戏开始")
	
	# 等待1秒让玩家看到消息
	await get_tree().create_timer(1.0).timeout
	
	# 开始正常回合
	current_team = setup_current_team  # 先手方
	turn_number = 0
	# 先显示新手文档，再开始游戏
	show_tutorial()

func _unhandled_input(event: InputEvent):
	if not setup_phase_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = hex_grid.to_local(get_global_mouse_position())
		var hex_coord = hex_grid.world_to_hex(local_pos)
		var q = round(hex_coord.x)
		var r = round(hex_coord.y)
		setup_place_marble(q, r)
	# 键盘 1~6 对应颜色选择
	if event is InputEventKey and event.pressed and not event.echo:
		var key_to_color = {
			KEY_1: 0,  # 白
			KEY_2: 1,  # 蓝
			KEY_3: 2,  # 绿
			KEY_4: 3,  # 红
			KEY_5: 4,  # 黑
			KEY_6: 5   # 黄
		}
		if event.keycode in key_to_color:
			var color_index = key_to_color[event.keycode]
			if setup_state == SetupState.COLOR_SELECT:
				setup_select_color(color_index)


func _adjust_marble_visuals():
	if not hex_grid:
		return
	var target_size = hex_grid.cell_size * 1.2
	for marble in all_marbles:
		# 调整 Sprite 大小使其在棋盘上可见
		var sprite = marble._get_sprite_node()
		if sprite and sprite.texture:
			var tex_size = sprite.texture.get_size()
			var scale_factor = target_size / max(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)
		# 重置碰撞体到弹珠中心
		for child in marble.get_children():
			if child is CollisionShape2D:
				child.position = Vector2.ZERO

func _init_ui():
	# 查找或创建 UI 节点
	var ui_node = get_node_or_null("UI")
	var need_add_child = false
	if not ui_node:
		ui_node = CanvasLayer.new()
		ui_node.name = "UI"
		need_add_child = true
	
	# 确保 UI 挂载了 UI.gd 脚本
	if ui_node.get_script() == null:
		var ui_script = load("res://UI/UI.gd")
		if ui_script:
			ui_node.set_script(ui_script)
	
	if need_add_child:
		add_child(ui_node)
	
	# 保存引用以便后续使用
	ui = ui_node

func start_turn():
	current_state = TurnState.IDLE
	selected_marble = null
	selected_direction = -1
	selected_power = 0
	red_step_directions = []
	red_total_steps = 0
	red_current_step_index = 0
	red_moved_steps = 0
	turn_number += 1
	var turn_text = "第 %d 回合，%s 方行动" % [turn_number, "红" if current_team == MarbleConst.Camp.RED else "蓝"]
	print(turn_text)
	if ui:
		ui.update_turn_display(self)
	state_changed.emit(current_state)

func select_marble(marble):
	if current_state != TurnState.IDLE or current_state == TurnState.VICTORY: return
	if marble.camp != current_team or not marble.is_alive: return
	selected_marble = marble
	selected_marble.highlight()
	
	# 红球特殊处理
	if marble.color == MarbleConst.MarbleColor.RED:
		current_state = TurnState.MARBLE_SELECTED
		print("红球：请选择力度（按 1~5 键确定步数）")
	# 黑球特殊处理
	elif marble.color == MarbleConst.MarbleColor.BLACK:
		current_state = TurnState.BLACK_SELECT_ENEMY
		print("黑球：请点击一个敌方弹珠作为目标")
		# 通知 UI 进入黑球选择模式（例如高亮敌方弹珠）
		if ui and ui.has_method("enter_black_select_enemy_mode"):
			ui.enter_black_select_enemy_mode()
	else:
		current_state = TurnState.MARBLE_SELECTED
		print("选中弹珠，请选择方向")
	
	state_changed.emit(current_state)

func select_direction(direction: int):
	if current_state != TurnState.MARBLE_SELECTED or current_state == TurnState.VICTORY: return
	selected_direction = direction
	current_state = TurnState.DIRECTION_SELECTED
	print("已选方向，请选择力度")
	state_changed.emit(current_state)
	
	# 蓝球（或变色后具有蓝色特性的白球）在选定方向后立即生成随从
	if selected_marble and selected_marble.is_alive:
		var is_blue = false
		if selected_marble.color == MarbleConst.MarbleColor.BLUE:
			is_blue = true
		elif selected_marble is WhiteMarble and selected_marble.current_strategy is BlueMoveStrategy:
			is_blue = true
		if is_blue:
			var followers = BlueMarbleHelper.spawn_followers(selected_marble, direction)
			# 存储到弹珠的临时变量中
			if selected_marble.has_method("set_temp_followers"):
				selected_marble.set_temp_followers(followers)
			elif "temp_followers" in selected_marble:
				selected_marble.temp_followers = followers
			elif "followers" in selected_marble:
				selected_marble.followers = followers

# 红球选择力度（步数），然后进入逐格选方向模式
func red_select_power(power: int):
	if current_state != TurnState.MARBLE_SELECTED or current_state == TurnState.VICTORY: return
	if selected_marble == null or selected_marble.color != MarbleConst.MarbleColor.RED:
		return
	
	red_total_steps = power
	red_step_directions = []
	red_current_step_index = 0
	red_moved_steps = 0
	# 保存起始位置（用于取消时回退）
	red_start_position = selected_marble.hex_coord if selected_marble.hex_coord != Vector2.ZERO else selected_marble.hex_grid.get_marble_hex(selected_marble)
	# 调用移动前钩子（方向暂时用0，后续每步会更新）
	if selected_marble.is_alive:
		selected_marble.on_before_move(0, power)
	current_state = TurnState.RED_DIRECTION_PICKING
	print("红球：请选择第 1 步的方向（点击相邻格子）")
	state_changed.emit(current_state)

# 红球追加一个方向
func red_append_direction(direction: int):
	if current_state != TurnState.RED_DIRECTION_PICKING or current_state == TurnState.VICTORY: return
	if selected_marble == null: return
	
	red_step_directions.append(direction)
	red_current_step_index += 1
	
	# 执行一步移动
	var success = _red_execute_single_step(direction)
	
	if not success:
		# 移动失败（死亡），结束回合
		_red_finish_turn()
		return
	
	red_moved_steps += 1
	
	if red_moved_steps >= red_total_steps or not selected_marble.is_alive:
		# 所有步数完成或死亡，结束回合
		_red_finish_turn()
	else:
		print("红球：请选择第 %d 步的方向（点击相邻格子）" % (red_moved_steps + 1))
		state_changed.emit(current_state)

# 红球执行移动（传入方向列表）
func _red_execute_single_step(direction: int) -> bool:
	if not selected_marble or not selected_marble.is_alive:
		return false
	var success = selected_marble._move_step_by_step(direction, 1)
	return success

func _red_finish_turn():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	
	if selected_marble and is_instance_valid(selected_marble):
		var last_dir = red_step_directions[-1] if red_step_directions.size() > 0 else 0
		selected_marble.on_after_move(last_dir, red_total_steps, selected_marble.is_alive)
		selected_marble.unhighlight()
	
	# 在不处于场景树中的测试环境里，同步执行后续逻辑
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	
	_finish_turn()

func select_power(power: int):
	if current_state != TurnState.DIRECTION_SELECTED or current_state == TurnState.VICTORY: return
	selected_power = power
	execute_move()
# 黑球选择敌方弹珠
func select_black_enemy(enemy: Marble2D):
	if current_state != TurnState.BLACK_SELECT_ENEMY:
		return
	if enemy == null or not enemy.is_alive or enemy.camp == current_team:
		print("请选择敌方存活弹珠")
		return
	# 记录选中的敌方弹珠
	selected_enemy = enemy
	# 进入选方向状态
	current_state = TurnState.BLACK_SELECT_DIRECTION
	print("请指定敌方弹珠的大致移动方向（点击相邻六个方向之一）")
	# 通知 UI 进入方向选择模式（如果有 UI 方法）
	if ui and ui.has_method("enter_black_select_direction_mode"):
		ui.enter_black_select_direction_mode()
	state_changed.emit(current_state)
# 黑球选择大致方向（0~5）
func select_black_direction(direction: int):
	if current_state != TurnState.BLACK_SELECT_DIRECTION:
		return
	if selected_marble and selected_marble.is_alive and selected_enemy:
		selected_marble.unhighlight()
		var success = selected_marble.force_enemy_move(selected_enemy, direction)
		if success:
			print("黑球强制移动成功")
		else:
			print("强制移动失败")
	# 清理状态并结束回合
	selected_marble = null
	selected_enemy = null
	current_state = TurnState.EXECUTING
	_finish_turn()
func execute_move():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	
	if selected_marble and selected_marble.is_alive:
		var marble = selected_marble
		var direction = selected_direction
		var steps = selected_power
		
		var start_hex = marble.get_current_hex()
		
		# 记录移动前的存活状态
		last_alive_status.clear()
		for m in all_marbles:
			if is_instance_valid(m):
				last_alive_status[m.get_instance_id()] = m.is_alive
		
		marble.move(direction, steps)
		
		# 处理死亡与白球变色
		if get_tree() != null:
			await _handle_deaths_and_white_change()
		else:
			_handle_deaths_and_white_change()
		
		var end_hex = marble.get_current_hex() if marble.is_alive else start_hex
		var path = _get_actual_path(start_hex, end_hex, direction)
		if get_tree() != null:
			await _play_path_animation(path)
	
	_finish_turn()
# 处理死亡事件和白球变色
# 播放路径动画：在每个格子上依次显示一个黄色光点
func _play_path_animation(path: Array[Vector2]) -> void:
	if path.is_empty():
		return
	var circle_texture = null
	var create_texture = func():
		var size = 32
		var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var center = size / 2
		var radius = center - 2
		for x in range(size):
			for y in range(size):
				var dx = x - center
				var dy = y - center
				if dx*dx + dy*dy <= radius*radius:
					image.set_pixel(x, y, Color.YELLOW)
		return ImageTexture.create_from_image(image)
	
	for hex in path:
		var world_pos = hex_grid.hex_to_world(int(hex.x), int(hex.y))
		var marker = Sprite2D.new()
		if circle_texture == null:
			circle_texture = create_texture.call()
		marker.texture = circle_texture
		marker.centered = true
		marker.position = world_pos
		marker.z_index = 10
		hex_grid.add_child(marker)
		await get_tree().create_timer(0.2).timeout
		marker.queue_free()

# 处理死亡事件、白球变色、黄球增益。返回 true 表示发生了黄球死亡且进入了增益选择状态（暂停回合）
func _handle_deaths_and_white_change() -> bool:
	var death_events: Array = []
	var yellow_deaths: Array[Marble2D] = []
	
	# 收集死亡的弹珠
	for m in all_marbles:
		if not is_instance_valid(m):
			continue
		var id = m.get_instance_id()
		var was_alive = last_alive_status.get(id, false)
		if was_alive and not m.is_alive:
			if m.color == MarbleConst.MarbleColor.YELLOW:
				yellow_deaths.append(m)
			elif m.color != MarbleConst.MarbleColor.WHITE:
				death_events.append({
					"color": m.color,
					"camp": m.camp
				})
	
	# 1. 处理白球变色
	if not death_events.is_empty():
		var white_marbles_info: Array = []
		for m in all_marbles:
			if is_instance_valid(m) and m.is_alive and m.color == MarbleConst.MarbleColor.WHITE:
				var has_changed = false
				if m.has_method("has_changed"):
					has_changed = m.has_changed
				elif "has_changed" in m:
					has_changed = m.has_changed
				white_marbles_info.append({
					"id": m.get_instance_id(),
					"camp": m.camp,
					"has_changed": has_changed,
					"current_color": MarbleConst.MarbleColor.WHITE
				})
		var changes = DeathResolver.resolve_simultaneous_deaths(death_events, white_marbles_info)
		for change in changes:
			var white_id = change["white_id"]
			var to_color = change["to_color"]
			for m in all_marbles:
				if is_instance_valid(m) and m.get_instance_id() == white_id:
					if m.has_method("on_teammate_died"):
						m.on_teammate_died(to_color)
					break
	
	# 2. 处理黄球死亡增益
	if not yellow_deaths.is_empty():
		var dead_yellow = yellow_deaths[0]  # 一次回合最多一个黄球死亡，取第一个
		# 收集候选目标
		var candidates: Array[Marble2D] = []
		for m in all_marbles:
			if is_instance_valid(m) and m.is_alive and m.camp == dead_yellow.camp and m != dead_yellow:
				if m.color != MarbleConst.MarbleColor.WHITE and m.color != MarbleConst.MarbleColor.YELLOW:
					candidates.append(m)
		if candidates.is_empty():
			print("黄球死亡，但无有效增益目标，跳过")
			return false
		else:
			# 进入等待增益选择状态
			current_state = TurnState.YELLOW_BOOST
			state_changed.emit(current_state)
			yellow_boost_requested.emit(dead_yellow, candidates)
			return true   # 表示暂停回合，等待 UI 选择
	return false

# 应用黄球增益到指定目标
func apply_yellow_boost(target: Marble2D):
	if current_state != TurnState.YELLOW_BOOST:
		return
	if not is_instance_valid(target) or not target.is_alive:
		print("增益目标无效")
		return
	if target.color == MarbleConst.MarbleColor.WHITE or target.color == MarbleConst.MarbleColor.YELLOW:
		print("不能对白球或黄球施加增益")
		return
	
	# 增加增益计数
	target.boost_count += 1
	target.update_boost_label()
	
	print("黄球增益已施加到 %s，当前增益次数：%d" % [target.get_class(), target.boost_count])
	
	# 恢复回合
	current_state = TurnState.IDLE
	state_changed.emit(current_state)
	_finish_turn()
# 提取回合结束公共逻辑，方便测试和代码复用
# 根据起点、终点和方向反推实际经过的格子（不包括起点，包括终点）
func _get_actual_path(start: Vector2, end: Vector2, direction: int) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current = start
	var offset = DIR_OFFSETS[direction]   # 需要确保 DIR_OFFSETS 已定义
	while current != end and path.size() < 20:
		current += offset
		path.append(current)
	return path
func _finish_turn():
	var winner = _check_victory()
	if winner != -1:
		_on_victory(winner)
		return
	# 切换回合
	current_team = MarbleConst.Camp.BLUE if current_team == MarbleConst.Camp.RED else MarbleConst.Camp.RED
	start_turn()

func cancel_selection():
	if current_state == TurnState.IDLE or current_state == TurnState.EXECUTING or current_state == TurnState.VICTORY: 
		return
	
	# 红球逐格选方向模式取消
	if current_state == TurnState.RED_DIRECTION_PICKING:
		if selected_marble:
			selected_marble.unhighlight()
			# 恢复红球到起始位置
			var current_hex = selected_marble.hex_coord if selected_marble.hex_coord != Vector2.ZERO else selected_marble.hex_grid.get_marble_hex(selected_marble)
			if current_hex != red_start_position and selected_marble.hex_grid:
				# 需要把红球移回起始位置（交换位置，因为起始位置可能已被其他球占据或已清除）
				# 先从当前位置移除
				selected_marble.hex_grid.remove_marble_by_node(selected_marble)
				# 放回起始位置（如果起始位置空闲）
				if selected_marble.hex_grid.get_marble_at(red_start_position.x, red_start_position.y) == null:
					selected_marble.hex_grid.place_marble(selected_marble, red_start_position.x, red_start_position.y)
					selected_marble.hex_coord = red_start_position
				else:
					# 起始位置已被占用，重新放置到空位置
					selected_marble.hex_grid.place_marble(selected_marble, red_start_position.x, red_start_position.y)
					selected_marble.hex_coord = red_start_position
		selected_marble = null
		selected_direction = -1
		selected_power = 0
		red_step_directions = []
		red_total_steps = 0
		red_current_step_index = 0
		red_moved_steps = 0
		current_state = TurnState.IDLE
		print("已取消选择")
		if ui:
			ui.update_message("已取消选择，请点击己方弹珠")
		state_changed.emit(current_state)
		return
	# 黑球逐格选择模式取消
	if current_state == TurnState.BLACK_SELECT_ENEMY or current_state == TurnState.BLACK_SELECT_DIRECTION:
		if selected_marble:
			selected_marble.unhighlight()
		selected_marble = null
		selected_enemy = null
		selected_direction = -1
		selected_power = 0
		current_state = TurnState.IDLE
		print("已取消黑球操作")
		if ui:
			ui.update_message("已取消选择，请点击己方弹珠")
		state_changed.emit(current_state)
		return
	# 普通球取消选择
	if selected_marble:
		selected_marble.unhighlight()
		# 清除蓝球随从
		if selected_marble.has_method("clear_temp_followers"):
			selected_marble.clear_temp_followers()
		elif "temp_followers" in selected_marble and selected_marble.temp_followers.size() > 0:
			BlueMarbleHelper.clear_followers(selected_marble, selected_marble.temp_followers)
			selected_marble.temp_followers = []
		elif "followers" in selected_marble and selected_marble.followers.size() > 0:
			BlueMarbleHelper.clear_followers(selected_marble, selected_marble.followers)
			selected_marble.followers = []
	selected_marble = null
	selected_direction = -1
	selected_power = 0
	current_state = TurnState.IDLE
	print("已取消选择")
	if ui:
		ui.update_message("已取消选择，请点击己方弹珠")
	state_changed.emit(current_state)

func _check_victory() -> int:
	var red_alive = false
	var blue_alive = false
	for marble in all_marbles:
		if not is_instance_valid(marble):
			continue
		if marble.is_alive:
			if marble.camp == MarbleConst.Camp.RED:
				red_alive = true
			else:
				blue_alive = true
	if not red_alive:
		return MarbleConst.Camp.BLUE
	if not blue_alive:
		return MarbleConst.Camp.RED
	return -1

func _on_victory(winner: int):
	current_state = TurnState.VICTORY
	state_changed.emit(current_state)
	var winner_name = "红方" if winner == MarbleConst.Camp.RED else "蓝方"
	print("游戏结束，%s 获胜！" % winner_name)
	if ui:
		ui.show_victory(winner_name)

func _on_marble_freed(marble: Marble2D):
	var idx = all_marbles.find(marble)
	if idx != -1:
		all_marbles.remove_at(idx)

func remove_marble(marble: Marble2D):
	# 供外部（如 DeathResolver）调用，手动移除弹珠
	var idx = all_marbles.find(marble)
	if idx != -1:
		all_marbles.remove_at(idx)

# 新手文档环节
func show_tutorial():
	# 加载教程场景
	var tutorial_scene = load("res://UI/Tutorial.tscn")
	if tutorial_scene == null:
		push_error("无法加载教程场景")
		start_turn()
		return
	
	var tutorial_instance = tutorial_scene.instantiate()
	add_child(tutorial_instance)
	
	# 连接信号
	tutorial_instance.tutorial_finished.connect(_on_tutorial_finished)

func _on_tutorial_finished():
	# 跳转到主游戏场景
	get_tree().change_scene_to_file("res://main.tscn")
