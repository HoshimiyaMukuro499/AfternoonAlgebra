# GameManager.gd（游戏主控制器，挂在根节点）
extends Node2D

# 直接在_ready里获取场景中的节点，不用在检查器设置变量
var hex_grid: HexGrid2D
var test_marble: Marble2D


func _ready() -> void:
	# 直接获取场景树里的节点（路径要和你场景里的节点名一致！）
	hex_grid = $HexGrid3D
	test_marble = $Marble_Rigid
	
	print("=== 六边形弹珠游戏框架初始化成功 ===")
	
	# 测试：把弹珠放到棋盘中心
	if hex_grid and test_marble:
		hex_grid.place_marble(test_marble, 0, 0)
		print("弹珠已放置到棋盘中心坐标(0,0)")


# 测试输入：按Enter键触发弹珠移动
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if test_marble:
			test_marble.move(MarbleConst.HexDirection.RIGHT, 2)
