extends Control

signal tutorial_finished

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var prev_button: Button = $PrevButton
@onready var next_button: Button = $NextButton
@onready var skip_button: Button = $SkipButton
@onready var sprite: Sprite2D = $Sprite

# 每页的文本内容（前3页为整体规则，后6页为每个弹珠一页）

var page_texts: Array[String] = [
	# Page 0 - 游戏原则
	"[font_size=40][center][b]游戏原则[/b][/center][/font_size]\n\n[font_size=30]《六色弹珠：六边形碰撞战》是一款[u]双人对战的策略游戏[/u]。\n\n将对方[u]所有弹珠击出棋盘[/u]即可获胜！[/font_size]",
	
	# Page 1 - 游戏目标
	"[font_size=40][center][b]游戏目标[/b][/center][/font_size]\n\n[font_size=30][color=#FFD700][b]目标[/b][/color]\n在六边形棋盘上，利用[u]弹性碰撞与棋子特性[/u]，将对方所有弹珠击出棋盘（或使其死亡），即获得胜利。\n\n双方轮流行动，选择自己的颜色弹珠并且对其实行[b]专属指令[/b]便可以获胜！[/font_size]",
	
	# Page 2 - 移动整体规则
	"[font_size=40][center][b]移动整体规则[/b][/center][/font_size]\n\n[font_size=30][color=#FFD700][b]移动方式[/b][/color]\n弹珠[u]逐格推进移动[/u]。每进入一个有弹珠的格点，两者发生[u]完全弹性碰撞[/u]！\n\n一个弹珠的最大移动距离有限制，通常是[b]5格[/b]，但对于特定的颜色弹珠与增益弹珠可能会有所不同哦！\n\n想必你也发现了，屏幕右侧的可爱女孩子们都是谁啊？这是我们代表六个弹珠形象的[b]弹珠娘(Marble Girl)[/b]！\n\n下面就来一一介绍吧：[/font_size]",
	
	# Page 3 - 白球（遗愿者）
	"[font_size=40][center][b]白球（遗愿者）[/b][/center][/font_size]\n\n[font_size=30][color=#FFFFFF][b]移动方式[/b][/color]\n白球可以向任意方向移动1~5步。\n\n但由于白球娘与其他球的良好关系，似乎[u]友方弹珠的推动可以给它更大的助力[/u]！\n\n而且在友方弹珠死亡之后，它也会[u]含泪继承他们的能力[/u]...[/font_size]",
	
	# Page 4 - 蓝球（统领者）
	"[font_size=40][center][b]蓝球（统领者）[/b][/center][/font_size]\n\n[font_size=30][color=#0000FF][b]移动方式[/b][/color]\n蓝球可以向任意方向移动1~5步。\n\n蓝球可以在[u]初始位置旁边生成两个随从[/u]，跟随自己一同移动，移动结束后消失。\n\n然而，如果随从不慎出界，自己也会死亡TAT。[/font_size]",
	
	# Page 5 - 绿球（推挤者）
	"[font_size=40][center][b]绿球（推挤者）[/b][/center][/font_size]\n\n[font_size=30][color=#00FF00][b]移动方式[/b][/color]\n绿球可以向任意方向移动1~5步。\n\n在绿色弹珠停止移动之后，它会[u]推开相邻六格的所有弹珠[/u]！\n\n这个技能很强力，但也难免误伤队友...[/font_size]",
	
	# Page 6 - 红球（定向者）
	"[font_size=40][center][b]红球（定向者）[/b][/center][/font_size]\n\n[font_size=30][color=#FF0000][b]移动方式[/b][/color]\n[b]指定步数（1~4），每步可自选方向！[/b]\n\n这可以让它进行更加灵活的移动...[/font_size]",
	
	# Page 7 - 黑球（干扰者）
	"[font_size=40][center][b]黑球（干扰者）[/b][/center][/font_size]\n\n[font_size=30][color=#666666][b]移动方式[/b][/color]\n[b]不能主动移动。[/b]\n\n选择一个敌方弹珠，并指定[u]一个大致方向（6个主方向之一）[/u]，会使得敌方弹珠在[u]指定方向以及相邻方向中[/u]选一个方向移动[u]2~3格！[/u]\n\n这样的干扰，或许能够瓦解对方的阵型，或者置关键弹珠于死地...[/font_size]",
	
	# Page 8 - 黄球（牺牲者）
	"[font_size=40][center][b]黄球（牺牲者）[/b][/center][/font_size]\n\n[font_size=30][color=#FFFF00][b]移动方式[/b][/color]\n黄球可以向任意方向移动1~5步。\n\n死亡时，立即手动选择己方一个其他弹珠（不能是白球或黄球），给予永久增益！\n\n对蓝球：随从出界不再导致蓝球死亡。\n对绿球：增加一格。\n对红球：移动步数上限增加1。\n对黑球：敌方弹珠被强制移动的格数固定为3。\n\n呜呜呜 黄球的名字看起来就让人心疼哇！因此我也对它的形象施加了最多的心血！\n\n[center][color=#FFD700]点击下方按钮开始游戏！[/color][/center][/font_size]"
]


# 每页对应的图片路径（请替换为实际图片路径，无图片则留空字符串）
var page_images: Array[String] = [
	"",   # 第0页图片（游戏原则）
	"",   # 第1页图片（游戏目标）
	"res://UI/b163c6d317906d18affe29d6de91fbbf.png",   # 第2页图片（移动整体规则）
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
			sprite.texture = tex
			sprite.visible = true
			# 根据区域大小自动计算缩放比例
			var viewport = get_viewport()
			if viewport:
				var region_size = Vector2(0.35, 0.75) * viewport.get_visible_rect().size
				var tex_size = tex.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					var scale_factor = min(region_size.x / tex_size.x, region_size.y / tex_size.y)
					sprite.scale = Vector2(scale_factor, scale_factor)
		else:
			sprite.visible = false
	else:
		sprite.visible = false
	
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
		var tree = get_tree()
		if tree and tree.get_root():
			tree.change_scene_to_file("res://main.tscn")

func _on_skip_button_pressed():
	var tree = get_tree()
	if tree and tree.get_root():
		tree.change_scene_to_file("res://main.tscn")
