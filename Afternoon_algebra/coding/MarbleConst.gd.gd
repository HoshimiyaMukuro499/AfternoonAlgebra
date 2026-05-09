# MarbleConst.gd（全局常量，单例）
extends Node

# 六边形方向（6个主方向）
enum HexDirection {
	RIGHT,       # (1,0)
	RIGHT_UP,    # (1,1)
	LEFT_UP,     # (0,1)
	LEFT,        # (-1,0)
	LEFT_DOWN,   # (-1,-1)
	RIGHT_DOWN   # (0,-1)
}

# 弹珠颜色枚举
enum MarbleColor {
	WHITE, BLUE, GREEN, RED, BLACK, YELLOW
}

# 阵营枚举
enum Camp {
	RED, BLUE
}

# 棋盘配置
const GRID_RADIUS: int = 7          # 棋盘有效半径
const TOTAL_MARBLE_COUNT: int = 6    # 每方弹珠数
const CELL_SIZE: float = 1.0         # 每个六边形格子的世界单位大小
