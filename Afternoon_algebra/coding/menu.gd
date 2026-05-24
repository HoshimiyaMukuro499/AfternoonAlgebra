extends Control

# GameModeManager 已注册为 Autoload，可通过 GameModeManager.mode 访问
const GameModeManager_ = preload("res://GameModeManager.gd")  # 用于类型安全

# 游戏模式常量
enum GameMode {
	PVP,      # 玩家 vs 玩家
	PVAI_RED, # 玩家 VS AI（红方 AI）
	PVAI_BLUE,# AI VS 玩家（蓝方 AI）
	AIVS_AI  # AI VS AI
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_start_pressed() -> void:
	# 玩家 vs 玩家
	_set_mode_and_start(GameMode.PVP)

func _on_ai_start_pressed() -> void:
	# 玩家 vs AI（AI 控制蓝方）
	_set_mode_and_start(GameMode.PVAI_BLUE)

func _on_ai_vs_ai_pressed() -> void:
	# AI vs AI
	_set_mode_and_start(GameMode.AIVS_AI)

func _set_mode_and_start(mode: int):
	# 通过 Autoload 保存游戏模式（跨场景持久）
	GameModeManager.mode = mode
	
	# 跳转到教程场景（教程结束后会进入 main.tscn）
	get_tree().change_scene_to_file("res://UI/Tutorial.tscn")

