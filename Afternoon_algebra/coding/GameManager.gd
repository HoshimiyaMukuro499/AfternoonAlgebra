class_name GameManager
extends Node2D

signal state_changed(new_state)
signal ai_turn_started(camp)  # AI 开始决策

const BlueMarbleHelper = preload("res://BlueMarbleHelper.gd")
const RandomAIScript = preload("res://ai/RandomAI.gd")
# GameModeManager 已注册为 Autoload，可直接通过全局名称访问

var hex_grid: HexGrid2D
var all_marbles: Array[Marble2D] = []
var ui: CanvasLayer

# AI 相关变量
var ai_enabled: bool = false
var ai_teams: Array[int] = []  # AI 控制的阵营列表
var ai_strategies: Dictionary = {}  # camp -> AI策略实例
var _ai_pending: bool = false  # 防止重复触发 AI

enum TurnState {
	IDLE,
	MARBLE_SELECTED,
	DIRECTION_SELECTED,
	RED_DIRECTION_PICKING,  # 红球逐格选方向状态
	BLACK_MARBLE_SELECTED,  # 黑球已被选中，等待选择目标
	BLACK_TARGET_PICKING,   # 黑球已选目标，等待选方向
	BLACK_DIRECTION_PICKING, # 黑球方向已选，执行强制移动
	EXECUTING,
	VICTORY
}
var current_state = TurnState.IDLE
var selected_marble = null
var selected_direction: int = -1
var selected_power: int = 0
var current_team = MarbleConst.Camp.RED
var turn_number: int = 0

# 红球逐格选方向专用变量
var red_step_directions: Array[int] = []
var red_total_steps: int = 0
var red_current_step_index: int = 0
var red_moved_steps: int = 0
var red_start_position: Vector2 = Vector2.ZERO  # 红球开始移动时的初始位置（用于取消时回退）

# 黑球专用变量
var black_target_marble = null      # 黑球选择的敌方目标弹珠
var black_approx_direction: int = -1  # 黑球选择的大致方向

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
	
	# 读取菜单选择的游戏模式并配置 AI
	_setup_ai_from_menu_mode()
	
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
	
	# 如果当前阵营是 AI，自动触发 AI 选珠
	if ai_enabled and setup_current_team in ai_teams:
		_trigger_ai_turn.call_deferred()

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
	# 如果是 AI 对战，跳过后手文档
	if ai_enabled and current_team in ai_teams:
		start_turn()
		return
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
	# 重置黑球状态
	black_target_marble = null
	black_approx_direction = -1
	turn_number += 1
	var turn_text = "第 %d 回合，%s 方行动" % [turn_number, "红" if current_team == MarbleConst.Camp.RED else "蓝"]
	print(turn_text)
	if ui:
		ui.update_turn_display(self)
	state_changed.emit(current_state)
	
	# AI 回合触发
	if ai_enabled and current_team in ai_teams:
		_trigger_ai_turn.call_deferred()

func select_marble(marble):
	if current_state != TurnState.IDLE or current_state == TurnState.VICTORY: return
	if marble.camp != current_team or not marble.is_alive: return
	selected_marble = marble
	selected_marble.highlight()
	
	# 黑球特殊处理：不能主动移动，进入选择敌方目标模式
	if marble.color == MarbleConst.MarbleColor.BLACK:
		current_state = TurnState.BLACK_MARBLE_SELECTED
		print("黑球：请选择一个敌方弹珠作为目标")
	elif marble.color == MarbleConst.MarbleColor.RED:
		# 红球特殊处理：先选力度（步数），再逐格选方向
		current_state = TurnState.MARBLE_SELECTED
		print("红球：请选择力度（按 1~5 键确定步数）")
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

# ── 黑球行动方法 ──

# 黑球选择目标敌方弹珠
func black_select_target(target: Marble2D):
	if current_state != TurnState.BLACK_MARBLE_SELECTED or current_state == TurnState.VICTORY:
		return
	if selected_marble == null or selected_marble.color != MarbleConst.MarbleColor.BLACK:
		return
	if target == null or not target.is_alive or target.camp == current_team:
		print("黑球目标无效：不能选择己方或已死亡弹珠")
		return
	
	black_target_marble = target
	current_state = TurnState.BLACK_TARGET_PICKING
	print("黑球：请选择一个大致方向（6个主方向之一）")
	state_changed.emit(current_state)

# 黑球选择大致方向，执行强制移动
func black_select_approx_direction(direction: int):
	if current_state != TurnState.BLACK_TARGET_PICKING or current_state == TurnState.VICTORY:
		return
	if selected_marble == null or black_target_marble == null:
		return
	
	black_approx_direction = direction
	current_state = TurnState.BLACK_DIRECTION_PICKING
	state_changed.emit(current_state)
	
	# 执行强制移动
	_execute_black_move()

# 执行黑球强制移动
func _execute_black_move():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	
	if selected_marble and selected_marble.is_alive:
		var black_marble = selected_marble
		var enemy = black_target_marble
		
		# 使用 BlackMarbleHelper 执行强制移动
		if black_marble.has_method("force_enemy_move"):
			black_marble.force_enemy_move(enemy, black_approx_direction)
		elif enemy.is_alive:
			# 兜底：直接调用 continue_move
			enemy.continue_move(3, black_approx_direction)
		
		black_marble.unhighlight()
	
	# 等待一下
	if is_inside_tree():
		await get_tree().create_timer(0.3).timeout
	
	_finish_turn()

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


func execute_move():
	current_state = TurnState.EXECUTING
	state_changed.emit(current_state)
	
	if selected_marble and selected_marble.is_alive:
		var marble = selected_marble
		var direction = selected_direction
		var steps = selected_power
		
		# 红球特殊处理：保持原有逐格移动逻辑
		if marble.color == MarbleConst.MarbleColor.RED:
			# 移动前钩子（红球在 red_select_power 中已调用）
			marble.on_before_move(direction, steps)
			
			for step in range(steps):
				if not marble.is_alive:
					break
				var success = marble._move_step_by_step(direction, 1)
				if not success:
					break
				if is_inside_tree():
					await get_tree().create_timer(0.15).timeout
			
			marble.on_after_move(direction, steps, marble.is_alive)
		else:
			# 非红球：使用弹珠自身的 move() 方法（蓝球、白球等）
			marble.move(direction, steps)
	
	# 再稍微等一下，确保所有动画效果结束
	if is_inside_tree():
		await get_tree().create_timer(0.1).timeout
	
	_finish_turn()

# 提取回合结束公共逻辑，方便测试和代码复用
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
	
	# 黑球选择模式取消
	if current_state in [TurnState.BLACK_MARBLE_SELECTED, TurnState.BLACK_TARGET_PICKING, TurnState.BLACK_DIRECTION_PICKING]:
		if selected_marble:
			selected_marble.unhighlight()
		selected_marble = null
		black_target_marble = null
		black_approx_direction = -1
		current_state = TurnState.IDLE
		print("黑球：已取消选择")
		if ui:
			ui.update_message("已取消选择，请点击己方弹珠")
		state_changed.emit(current_state)
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
		selected_direction = -1   # 添加：重置方向
		selected_power = 0         # 添加：重置力度
		red_step_directions = []
		red_total_steps = 0
		red_current_step_index = 0
		red_moved_steps = 0
		current_state = TurnState.IDLE
		print("已取消选择")
		if ui:
			ui.update_message("已取消选择，请点击己方弹珠")
		state_changed.emit(current_state)
		return  # 这里的 return 是正确的，避免执行后面的通用代码
	
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

# 从菜单模式配置 AI
func _setup_ai_from_menu_mode():
	var mode = GameModeManager.mode
	
	match mode:
		GameModeManager.GameMode.PVAI_BLUE:
			# 蓝方 AI（玩家 VS AI）
			var ai = RandomAIScript.new()
			set_ai_for_camp(MarbleConst.Camp.BLUE, ai)
			print("[AI模式] 蓝方由 AI 控制")
		GameModeManager.GameMode.PVAI_RED:
			# 红方 AI（AI VS 玩家）
			var ai = RandomAIScript.new()
			set_ai_for_camp(MarbleConst.Camp.RED, ai)
			print("[AI模式] 红方由 AI 控制")
		GameModeManager.GameMode.AIVS_AI:
			# 双方都是 AI
			var ai_red = RandomAIScript.new()
			var ai_blue = RandomAIScript.new()
			set_ai_for_camp(MarbleConst.Camp.RED, ai_red)
			set_ai_for_camp(MarbleConst.Camp.BLUE, ai_blue)
			print("[AI模式] 双方都由 AI 控制")
		_:
			# PvP 模式，不需要 AI
			print("[PvP模式] 玩家对战")

# ── AI 相关方法 ──

# 设置 AI 策略
func set_ai_for_camp(camp: int, strategy):
	ai_strategies[camp] = strategy
	if camp not in ai_teams:
		ai_teams.append(camp)
	ai_enabled = true

# 移除 AI 设置
func remove_ai_for_camp(camp: int):
	ai_strategies.erase(camp)
	ai_teams.erase(camp)
	if ai_teams.size() == 0:
		ai_enabled = false

# 检查当前回合是否是 AI 控制
func is_ai_turn() -> bool:
	return ai_enabled and current_team in ai_teams

# 触发 AI 决策
func _trigger_ai_turn():
	if _ai_pending:
		return
	if not ai_enabled:
		return
	
	# 选珠阶段使用 setup_current_team，正常回合使用 current_team
	var active_team = setup_current_team if setup_phase_active else current_team
	if active_team not in ai_teams:
		return
	if current_state == TurnState.VICTORY:
		return
	
	_ai_pending = true
	ai_turn_started.emit(active_team)
	
	var strategy = ai_strategies.get(active_team)
	if not strategy:
		_ai_pending = false
		return
	
	var action = strategy.decide(self)
	if action.is_empty():
		_ai_pending = false
		return
	
	# 需要用 await 来执行，因为 setup_place 分支含有 await 协程
	await _execute_ai_action(action)
	_ai_pending = false

# 执行 AI 动作（async 函数，因为 setup_place 分支需要 await setup_place_marble）
func _execute_ai_action(action: Dictionary):
	match action.get("action"):
		"select_marble":
			select_marble(action.marble)
			# 选中后，根据不同颜色进入不同状态，AI 需要继续决策
			if ai_enabled and current_team in ai_teams:
				_trigger_ai_turn.call_deferred()
		"select_direction":
			select_direction(action.direction)
			# 选完方向后进入 DIRECTION_SELECTED，AI 需要继续选力度
			if ai_enabled and current_team in ai_teams:
				_trigger_ai_turn.call_deferred()
		"select_power":
			select_power(action.power)
			# select_power 会触发 execute_move，然后 _finish_turn -> start_turn
			# start_turn 中会再次触发 AI
		"red_power":
			red_select_power(action.power)
			# 进入 RED_DIRECTION_PICKING，AI 需要继续选方向（逐格）
			if ai_enabled and current_team in ai_teams:
				_trigger_ai_turn.call_deferred()
		"red_direction":
			red_append_direction(action.direction)
			# red_append_direction 内部可能会调用 _red_finish_turn -> _finish_turn
			# 如果红球还没走完，留在 RED_DIRECTION_PICKING，需要继续触发 AI
			if ai_enabled and current_team in ai_teams and current_state == TurnState.RED_DIRECTION_PICKING:
				_trigger_ai_turn.call_deferred()
		# 黑球动作
		"select_enemy":
			black_select_target(action.marble)
			if ai_enabled and current_team in ai_teams:
				_trigger_ai_turn.call_deferred()
		"select_approx_direction":
			black_select_approx_direction(action.direction)
			# black_select_approx_direction 内部会调用 _execute_black_move，然后 _finish_turn
		# 选珠动作
		"setup_color":
			setup_select_color(action.color)
			# 选完颜色后进入 PLACEMENT，AI 需要继续放置
			if ai_enabled and setup_phase_active and setup_current_team in ai_teams:
				_trigger_ai_turn.call_deferred()
		"setup_place":
			# 必须 await：setup_place_marble 是协程（含有 await），
			# 不 await 的话最后一颗弹珠显示阵型名称时的3秒等待会触发并发 AI 决策，
			# 导致 AI 在无可用位置时反复尝试（返回无效的(0,0)），造成死循环
			await setup_place_marble(action.q, action.r)
			# setup_place_marble 会内部切换颜色选择或切换阵营，AI 继续
			if ai_enabled and setup_phase_active:
				if setup_current_team in ai_teams:
					_trigger_ai_turn.call_deferred()
				# 如果 setup_current_team 切换到另一方且那方也是 AI
				elif setup_phase_active and ai_enabled and ai_teams.size() > 1:
					_trigger_ai_turn.call_deferred()

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
