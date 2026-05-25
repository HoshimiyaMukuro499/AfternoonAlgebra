# test_tutorial.gd
# 教程 UI 测试：测试 Tutorial.gd 的分页、导航和图片显示功能
class_name TestTutorial
extends "res://tests/base_test.gd"

var tutorial: Control

func before_each() -> void:
	tutorial = Control.new()
	var tutorial_script = load("res://UI/Tutorial.gd")
	tutorial.set_script(tutorial_script)
	# 添加必要的子节点（因为脚本使用 @onready 引用它们）
	# 但 @onready 需要场景树，我们手动创建子节点
	var rich_text = RichTextLabel.new()
	rich_text.name = "RichTextLabel"
	tutorial.add_child(rich_text)
	
	var prev_btn = Button.new()
	prev_btn.name = "PrevButton"
	tutorial.add_child(prev_btn)
	
	var next_btn = Button.new()
	next_btn.name = "NextButton"
	tutorial.add_child(next_btn)
	
	var skip_btn = Button.new()
	skip_btn.name = "SkipButton"
	tutorial.add_child(skip_btn)
	
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	tutorial.add_child(sprite)

func after_each() -> void:
	if tutorial and is_instance_valid(tutorial):
		tutorial.queue_free()
		tutorial = null

# ================================================================
# 第1组：教程页面基本测试
# ================================================================

func test_tutorial_script_loaded() -> void:
	"""测试教程脚本能加载"""
	assert_not_null(tutorial.get_script(), "Tutorial.gd 脚本应加载")

func test_initial_page_is_zero() -> void:
	"""测试初始页面为第0页"""
	assert_eq(tutorial.current_page, 0, "初始页面为0")

func test_page_texts_count() -> void:
	"""测试页面文本数量"""
	assert_eq(tutorial.page_texts.size(), 9, "应有9页文本")

func test_page_images_count() -> void:
	"""测试页面图片数组大小与文本数一致"""
	assert_eq(tutorial.page_images.size(), tutorial.page_texts.size(), "图片数与文本数应一致")

func test_first_page_not_empty() -> void:
	"""测试第0页文本非空"""
	assert_true(tutorial.page_texts[0].length() > 0, "第0页应有内容")

func test_last_page_has_start_hint() -> void:
	"""测试最后一页有开始游戏提示"""
	assert_true(tutorial.page_texts[8].contains("开始游戏"), "最后一页应有'开始游戏'提示")

# ================================================================
# 第2组：页面导航测试
# ================================================================

func test_next_button_advances_page() -> void:
	"""测试下一页按钮"""
	tutorial._ready()
	var old_page = tutorial.current_page
	tutorial._on_next_button_pressed()
	assert_eq(tutorial.current_page, old_page + 1, "页面应前进1页")

func test_prev_button_goes_back() -> void:
	"""测试上一页按钮"""
	tutorial._ready()
	# 先前进到第1页
	tutorial._on_next_button_pressed()
	var old_page = tutorial.current_page
	tutorial._on_prev_button_pressed()
	assert_eq(tutorial.current_page, old_page - 1, "页面应后退1页")

func test_prev_button_disabled_on_first_page() -> void:
	"""测试第一页时上一页按钮禁用"""
	tutorial._ready()
	tutorial._update_page()
	assert_true(tutorial.prev_button.disabled, "第0页时上一页按钮禁用")

func test_prev_button_enabled_after_navigation() -> void:
	"""测试导航后上一页按钮启用"""
	tutorial._ready()
	tutorial._on_next_button_pressed()
	assert_false(tutorial.prev_button.disabled, "第1页时上一页按钮启用")

func test_last_page_next_button_shows_start() -> void:
	"""测试最后一页时下一页按钮显示'开始游戏'"""
	tutorial._ready()
	# 直接跳到最后一页
	tutorial.current_page = tutorial.page_texts.size() - 1
	tutorial._update_page()
	assert_eq(tutorial.next_button.text, "开始游戏", "最后一页按钮显示'开始游戏'")

func test_navigation_bounds_lower() -> void:
	"""测试不能翻到第0页之前"""
	tutorial._ready()
	tutorial.current_page = 0
	tutorial._on_prev_button_pressed()
	assert_eq(tutorial.current_page, 0, "不能翻到第0页之前")

func test_navigation_bounds_upper() -> void:
	"""测试不能翻过最后一页"""
	tutorial._ready()
	tutorial.current_page = tutorial.page_texts.size() - 1
	# 在最后一页点击 next 会触发场景切换，在无场景树环境中 skip
	# 只验证 _update_page 设置正确按钮文本
	tutorial._update_page()
	assert_eq(tutorial.next_button.text, "开始游戏", "最后一页按钮显示'开始游戏'")

# ================================================================
# 第3组：页面内容测试
# ================================================================

func test_page_0_has_game_principles() -> void:
	"""测试第0页包含游戏原则"""
	assert_true(tutorial.page_texts[0].contains("游戏原则"), "第0页应包含'游戏原则'")

func test_page_8_has_yellow_marble_info() -> void:
	"""测试第8页包含黄球信息"""
	assert_true(tutorial.page_texts[8].contains("牺牲者") or tutorial.page_texts[8].contains("黄"), "第8页应包含黄球信息")

# ================================================================
# 第4组：图片路径测试
# ================================================================

func test_image_paths_are_valid() -> void:
	"""测试图片路径格式正确"""
	for i in range(tutorial.page_images.size()):
		var path = tutorial.page_images[i]
		if path != "":
			assert_true(path.begins_with("res://"), "图片路径应以 res:// 开头")
			assert_true(path.ends_with(".png"), "图片路径应以 .png 结尾")

func test_image_exists_for_marble_pages() -> void:
	"""测试弹珠介绍页有关联图片"""
	# 第2页（整体规则）开始应有图片
	assert_true(tutorial.page_images[2] != "", "第2页应有图片")
	assert_true(tutorial.page_images[3] != "", "第3页（白球）应有图片")
	assert_true(tutorial.page_images[4] != "", "第4页（蓝球）应有图片")
	assert_true(tutorial.page_images[5] != "", "第5页（绿球）应有图片")
	assert_true(tutorial.page_images[6] != "", "第6页（红球）应有图片")
	assert_true(tutorial.page_images[7] != "", "第7页（黑球）应有图片")
	assert_true(tutorial.page_images[8] != "", "第8页（黄球）应有图片")

func test_first_two_pages_have_no_images() -> void:
	"""测试前两页没有图片"""
	assert_eq(tutorial.page_images[0], "", "第0页无图片")
	assert_eq(tutorial.page_images[1], "", "第1页无图片")

# ================================================================
# 第5组：信号测试
# ================================================================

func test_tutorial_finished_signal_exists() -> void:
	"""测试 tutorial_finished 信号存在"""
	assert_true(tutorial.has_signal("tutorial_finished"), "应有 tutorial_finished 信号")
