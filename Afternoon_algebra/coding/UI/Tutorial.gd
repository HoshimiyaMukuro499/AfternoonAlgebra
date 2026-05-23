extends Control

signal tutorial_finished

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var prev_button: Button = $PrevButton
@onready var next_button: Button = $NextButton
@onready var skip_button: Button = $SkipButton
@onready var texture_rect: TextureRect = $TextureRect

# 每页的文本内容（前3页为整体规则，后6页为每个弹珠一页）
var page_texts: Array[String] = [
	# Page 0 - 游戏原则
	"[font_size=40][center][b]游戏原则[/b][/center][/font_size]\n\n[color=#FFD700][b]游戏概述[/b][/color]\n《六色弹珠：六边形碰撞战》是一款双人对战的策略游戏。\n\n[color=#FFD700][b]胜利条件[/b][/color]\n将对方所有弹珠击出棋盘或使其死亡即可获胜。\n\n[color=#FFD700][b]棋盘[/b][/color]\n正六边形棋盘，每条边包含8个格点，共169个格点。坐标使用轴向六边形坐标 (q, r)。",
	# Page 1 - 游戏目标
	"[font_size=40][center][b]游戏目标[/b][/center][/font_size]\n\n[color=#FFD700][b]目标[/b][/color]\n在10×10×10的六边形棋盘上，利用弹性碰撞与棋子特性，将对方所有弹珠击出棋盘（或使其死亡），即获得胜利。\n\n[color=#FFD700][b]回合流程[/b][/color]\n1. 选择一个己方存活弹珠。\n2. 根据弹珠颜色执行其专属移动指令。\n3. 结算所有碰撞、出界、死亡、特性触发。\n4. 检查胜负，切换回合。",
	# Page 2 - 移动整体规则
	"[font_size=40][center][b]移动整体规则[/b][/center][/font_size]\n\n[color=#FFD700][b]移动方式[/b][/color]\n弹珠逐格推进移动。每进入一个有弹珠的格点，两者交换速度矢量（完全弹性碰撞）：当前弹珠停下，被撞弹珠获得剩余步数继续沿原方向移动。\n\n[color=#FFD700][b]出界判定[/b][/color]\n每步结束后立即检查出界，出界则死亡。\n\n[color=#FFD700][b]绿球推挤[/b][/color]\n绿球推挤在移动完全停止后同时结算。",
	# Page 3 - 白球
	"[font_size=40][center][b]白球（基础）[/b][/center][/font_size]\n\n[color=#FFFFFF][b]移动方式[/b][/color]\n指定方向（6选1）+ 指定基础力度（1~5）。实际移动步数 = 基础力度。\n\n[color=#FFFFFF][b]特殊能力[/b][/color]\n- 被友方弹珠碰撞时，额外获得+1剩余步数。\n- 每当己方其他颜色弹珠死亡时（黄球除外），若白球仍存活，则立即变为该死亡弹珠的颜色，并获得其全部特性。\n- 白球不会因黄球死亡而变色。",
	# Page 4 - 蓝球
	"[font_size=40][center][b]蓝球（随从）[/b][/center][/font_size]\n\n[color=#0000FF][b]移动方式[/b][/color]\n选择移动方向（6选1）+ 力度（1~5）。\n\n[color=#0000FF][b]特殊能力[/b][/color]\n- 移动前在两侧生成最多2个随从。\n- 随从与蓝球同方向同力度移动，移动后消失。\n- 若任意一个随从出界，蓝球死亡。\n- 若生成0个随从，蓝球移动后不会因随从出界而死亡。",
	# Page 5 - 绿球
	"[font_size=40][center][b]绿球（推挤）[/b][/center][/font_size]\n\n[color=#00FF00][b]移动方式[/b][/color]\n与白球相同（方向 + 力度1~5）。\n\n[color=#00FF00][b]特殊能力[/b][/color]\n- 移动停止后，检查相邻6个格点。\n- 对每个相邻格上的弹珠（不分敌我），将其沿远离绿球的方向推开1格。\n- 若目标格被占，则推开失败，该弹珠停留在原处且不死亡。\n- 若目标格出界，该弹珠死亡。\n- 所有推开同时结算。",
	# Page 6 - 红球
	"[font_size=40][center][b]红球（定向步进）[/b][/center][/font_size]\n\n[color=#FF0000][b]移动方式[/b][/color]\n指定步数（1~4），每步可自选方向（允许折返）。\n\n[color=#FF0000][b]特殊能力[/b][/color]\n- 每一步移动后立即与所在格点上的弹珠进行弹性碰撞（速度交换）。\n- 若某一步碰撞后导致自己或对方出界，则出界者立即死亡并终止后续移动。",
	# Page 7 - 黑球
	"[font_size=40][center][b]黑球（干扰）[/b][/center][/font_size]\n\n[color=#000000][b]移动方式[/b][/color]\n不能主动移动。\n\n[color=#000000][b]特殊能力[/b][/color]\n- 选择一个敌方弹珠，并指定一个大致方向（6个主方向之一）。\n- 系统随机从指定方向、顺时针偏60°、逆时针偏60°中选一个方向。\n- 系统随机从{2, 3}中选择移动格数。\n- 被指定的敌方弹珠强制沿选定的方向移动指定格数（移动过程中正常进行碰撞弹性交换）。\n- 若移动过程中或终点出界，则敌方弹珠死亡。",
	# Page 8 - 黄球
	"[font_size=40][center][b]黄球（死亡增益）[/b][/center][/font_size]\n\n[color=#FFFF00][b]移动方式[/b][/color]\n与白球相同（方向 + 力度1~5）。\n\n[color=#FFFF00][b]特殊能力[/b][/color]\n- 死亡时，立即手动选择己方一个其他弹珠（不能是白球或黄球），给予永久增益。\n- 对蓝球：随从出界不再导致蓝球死亡。\n- 对绿球：推挤范围从相邻1格变为相邻X格（X = 1 + 黄球增益次数）。\n- 对红球：移动步数上限从4提升至4 + 增益次数。\n- 对黑球：敌方弹珠被强制移动的格数固定为3。\n\n[center][color=#FFD700]点击下方按钮开始游戏！[/color][/center]"
]

# 每页对应的图片路径（请替换为实际图片路径，无图片则留空字符串）
var page_images: Array[String] = [
	"",   # 第0页图片（游戏原则）
	"",   # 第1页图片（游戏目标）
	"",   # 第2页图片（移动整体规则）
	"res://UI/page0.png",   # 第3页图片（白球）
	"res://UI/page1.png",   # 第4页图片（蓝球）
	"res://UI/page2.png",   # 第5页图片（绿球）
	"res://UI/page3.png",   # 第6页图片（红球）
	"res://UI/page4.png",   # 第7页图片（黑球）
	"res://UI/page5.png"    # 第8页图片（黄球）
]

var current_page: int = 0

func _ready():
	_update_page()
	prev_button.pressed.connect(_on_prev_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	skip_button.pressed.connect(_on_skip_button_pressed)

func _update_page():
	# 更新文本
	rich_text_label.text = page_texts[current_page]
	
	# 增大整体字体
	rich_text_label.add_theme_font_size_override("normal_font_size", 28)
	
	# 更新图片
	var img_path = page_images[current_page]
	if img_path != "":
		var tex = load(img_path)
		if tex:
			texture_rect.texture = tex
			texture_rect.visible = true
		else:
			texture_rect.visible = false
	else:
		texture_rect.visible = false
	
	# 更新按钮状态
	prev_button.disabled = (current_page == 0)
	next_button.text = "下一页" if current_page < page_texts.size() - 1 else "开始游戏"

func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		_update_page()

func _on_next_button_pressed():
	if current_page < page_texts.size() - 1:
		current_page += 1
		_update_page()
	else:
		get_tree().change_scene_to_file("res://main.tscn")

func _on_skip_button_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
