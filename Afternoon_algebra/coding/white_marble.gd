# WhiteMarble.gd
# 白球（变色者）弹珠（2D版）。
# 特性1：当当前颜色为白色时，被友方碰撞步数+1。
# 特性2：己方其他颜色弹珠死亡时，白球变为该颜色，并继承该颜色的全部移动特性（如变蓝后能生成随从）。
# 特性3：可以多次变色（覆盖）。
#
# 策略模式重构：各颜色移动逻辑由 MoveStrategyBase 子类实现，
# change_color() 时自动切换 current_strategy。

class_name WhiteMarble
extends Marble2D

# preload 策略脚本
const _WhiteMoveStrategy := preload("res://WhiteMoveStrategy.gd")
const _BlueMoveStrategy := preload("res://BlueMoveStrategy.gd")
const _GreenMoveStrategy := preload("res://GreenMoveStrategy.gd")
const _RedMoveStrategy := preload("res://RedMoveStrategy.gd")
const _BlackMoveStrategy := preload("res://BlackMoveStrategy.gd")
const _YellowMoveStrategy := preload("res://YellowMoveStrategy.gd")
const BlueMarbleHelper = preload("res://BlueMarbleHelper.gd")

# 记录是否已经变色过（用于外部优先选择未变色的白球）
var has_changed: bool = false
# 临时存储随从列表（仅当当前颜色为蓝色时使用，每次移动后即清空）
var temp_followers: Array[Node2D] = []
var follower_safe: bool = false
var push_range: int = 1
var max_steps: int = 5
var enhanced: bool = false

# 新增方法：设置临时随从列表（由 GameManager 在选定方向后调用）
func set_temp_followers(f: Array[Node2D]) -> void:
	temp_followers = f

# 新增方法：获取临时随从列表
func get_temp_followers() -> Array[Node2D]:
	return temp_followers

# 新增方法：清除临时随从
func clear_temp_followers() -> void:
	if temp_followers.size() > 0:
		BlueMarbleHelper.clear_followers(self, temp_followers)
		temp_followers = []

# 黄球增益：增加推挤范围（绿球特性）
func increase_push_range(amount: int = 1) -> void:
	push_range += amount
	print("白球（绿球特性）推挤范围增加至: ", push_range)

# 黄球增益：增加最大步数（红球特性）
func increase_max_steps(amount: int = 1) -> void:
	max_steps += amount
	print("白球（红球特性）最大步数增加至: ", max_steps)

# 黄球增益：设置增强状态（黑球特性）
func set_enhanced(value: bool = true) -> void:
	enhanced = value
	print("白球（黑球特性）已增强，强制移动距离固定为3")

# 黄球增益：设置随从安全模式（蓝球特性）
func set_follower_safe(safe: bool) -> void:
	follower_safe = safe
	print("白球（蓝球特性）获得增益：随从出界不再导致死亡")

# 策略字典
var strategies: Dictionary = {}
# 当前策略
var current_strategy = null

# 获取弹珠的 Sprite 节点（场景中实际节点名为 "SpriteWhite"）
@onready var spritewhite: Sprite2D = $SpriteWhite


func _init() -> void:
	strategies = {
		MarbleConst.MarbleColor.WHITE:  _WhiteMoveStrategy.new(),
		MarbleConst.MarbleColor.BLUE:   _BlueMoveStrategy.new(),
		MarbleConst.MarbleColor.GREEN:  _GreenMoveStrategy.new(),
		MarbleConst.MarbleColor.RED:    _RedMoveStrategy.new(),
		MarbleConst.MarbleColor.BLACK:  _BlackMoveStrategy.new(),
		MarbleConst.MarbleColor.YELLOW: _YellowMoveStrategy.new(),
	}
	current_strategy = strategies[MarbleConst.MarbleColor.WHITE]


# ---------- 碰撞步数调整 ----------
# 委托给当前策略
func on_collision_as_target(collider: Marble2D, incoming_steps: int, direction: int) -> int:
	if current_strategy:
		return current_strategy.on_collision_as_target(self, collider, incoming_steps, direction)
	return incoming_steps
# ---------- 移动分发 ----------
# 根据当前策略执行移动（替代旧的 match color）
func move(direction: int, steps: int) -> void:
	if not is_alive:
		return
	
	# 确保策略与当前颜色一致（兼容外部直接设 color 的场景）
	_sync_strategy_with_color()

	on_before_move(direction, steps)
	var success = false
	if current_strategy:
		success = current_strategy.execute(self, direction, steps)
	else:
		success = _move_step_by_step(direction, steps)
	on_after_move(direction, steps, success)


# 确保 current_strategy 与 color 一致
func _sync_strategy_with_color() -> void:
	if color in strategies and current_strategy != strategies[color]:
		current_strategy = strategies[color]


# ---------- 变色逻辑 ----------
# 由外部（GameManager / Board）在己方其他颜色弹珠死亡时调用
# 规则：己方非白非黄的弹珠死亡时，白球变为该颜色；白球死亡不触发变色
func on_teammate_died(dead_color: int) -> void:
	if not is_alive:
		return
	if dead_color == MarbleConst.MarbleColor.YELLOW:
		return
	if dead_color == MarbleConst.MarbleColor.WHITE:
		return
	change_color(dead_color)
	has_changed = true


# 改变颜色并更新外观，同时切换策略
func change_color(new_color: int) -> void:
	color = new_color
	_update_appearance(new_color)
	if new_color in strategies:
		current_strategy = strategies[new_color]
	print("白球变为颜色: ", new_color)


# 根据颜色设置 Sprite 的纹理（替换精灵图而非 modulate 着色）
func _update_appearance(new_color: int) -> void:
	var s = _get_sprite_node()
	if not s:
		return
	var tex = _get_texture_for_color(new_color)
	if tex:
		s.texture = tex


# 获取各颜色对应的纹理
func _get_texture_for_color(c: int) -> Texture2D:
	match c:
		MarbleConst.MarbleColor.WHITE:  return load("res://e38f2b561d3b4729548c49c70ff55bfc_副本.png")
		MarbleConst.MarbleColor.BLUE:   return load("res://72ecbf01174f9811d8d12cb4db99ff12.png")
		MarbleConst.MarbleColor.GREEN:  return load("res://e0b8bb4e61a2c84b61cb88da0639f13f.png")
		MarbleConst.MarbleColor.RED:    return load("res://51aaad4f97bb00788f135d0f723e824b.png")
		MarbleConst.MarbleColor.BLACK:  return load("res://b764655fb551105500b3ff458d9a265f.png")
		MarbleConst.MarbleColor.YELLOW: return load("res://448f9290e54cf220665a9acb90b58e08.png")
	return null


# 死亡时清理（委托给策略）
func on_death() -> void:
	if current_strategy:
		current_strategy.on_death(self)
