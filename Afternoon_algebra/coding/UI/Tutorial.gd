extends Control

signal tutorial_finished

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var prev_button: Button = $PrevButton
@onready var next_button: Button = $NextButton
@onready var skip_button: Button = $SkipButton

var pages: Array[String] = [
	# Page 0
	"[center][b]欢迎来到《六色弹珠：六边形碰撞战》[/b][/center]\n\n[color=#FFD700][b]游戏目标[/b][/color]\n将对方所有弹珠击出棋盘或使其死亡即可获胜。\n\n[color=#FFD700][b]棋盘与坐标[/b][/color]\n棋盘为正六边形，每条边包含8个格点，共169个格点。坐标使用轴向六边形坐标 (q, r)。",
	# Page 1
	"[color=#FFD700][b]回合流程[/b][/color]\n1. 选择一个己方存活弹珠。\n2. 根据弹珠颜色执行其专属移动指令。\n3. 结算碰撞、出界、死亡等。\n4. 检查胜负，切换回合。",
	# Page 2
	"[color=#FFD700][b]六种弹珠能力简介[/b][/color]\n\n[color=#FFFFFF]白球（基础）[/color]\n- 指定方向 + 力度（1~5）移动。\n- 被友方碰撞时获得额外步数。\n- 己方其他颜色弹珠死亡时，白球可变为该颜色并获得其特性。",
	# Page 3
	"[color=#0000FF]蓝球（随从）[/color]\n- 移动前在两侧生成最多2个随从。\n- 随从与蓝球同方向同力度移动，移动后消失。\n- 若随从出界，蓝球死亡。\n\n[color=#00FF00]绿球（推挤）[/color]\n- 移动后推开相邻所有弹珠（不分敌我）1格。\n- 若目标格被占则推开失败，若出界则目标死亡。",
	# Page 4
	"[color=#FF0000]红球（定向步进）[/color]\n- 指定步数（1~4），每步可自选方向。\n- 每步移动后立即进行碰撞交换。\n\n[color=#000000]黑球（干扰）[/color]\n- 不能主动移动。\n- 选择一个敌方弹珠，强制其沿随机方向移动2~3格。",
	# Page 5
	"[color=#FFFF00]黄球（死亡增益）[/color]\n- 移动方式与白球相同。\n- 死亡时给予己方一个其他弹珠永久增益（如蓝球随从出界不死亡、绿球推挤范围扩大等）。\n\n[center][color=#FFD700]点击下方按钮开始游戏！[/color][/center]"
]

var current_page: int = 0

func _ready():
	_update_page()
	prev_button.pressed.connect(_on_prev_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	skip_button.pressed.connect(_on_skip_button_pressed)

func _update_page():
	rich_text_label.text = pages[current_page]
	prev_button.disabled = (current_page == 0)
	next_button.text = "下一页" if current_page < pages.size() - 1 else "开始游戏"

func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		_update_page()

func _on_next_button_pressed():
	if current_page < pages.size() - 1:
		current_page += 1
		_update_page()
	else:
		get_tree().change_scene_to_file("res://main.tscn")

func _on_skip_button_pressed():
	
	get_tree().change_scene_to_file("res://main.tscn")
