# GameModeManager.gd
# 全局单例，用于存储菜单选择的游戏模式
extends Node

enum GameMode {
	PVP,      # 玩家 vs 玩家
	PVAI_RED, # 红方 AI / 玩家 vs 蓝方
	PVAI_BLUE,# 玩家 vs 蓝方 AI
	AIVS_AI  # AI vs AI
}

var mode: int = GameMode.PVP

