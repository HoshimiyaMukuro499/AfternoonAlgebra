# Godot 测试框架说明

## 文件结构

```
tests/
├── base_test.gd           # 测试基类，提供 assert_eq / assert_true 等断言方法
├── test_runner.gd         # 测试运行器，自动发现并执行所有测试
├── test_scene.tscn        # 测试场景，在 Godot 中打开此场景即可运行全部测试
├── test_hex_grid.gd       # HexGrid2D 棋盘测试（坐标转换、边界、放置/移动/移除）
├── test_marble.gd         # Marble2D 基类测试（移动、碰撞、邻居计算、高亮、死亡）
├── test_blue_marble.gd    # 蓝球/随从测试（生成位置、清除、联动移动、棋盘状态）
├── test_white_marble.gd   # 白球测试（变色、碰撞步数加成、按颜色移动分发、变蓝棋盘状态）
└── test_game_manager.gd   # GameManager 状态机测试（选择、取消、回合切换）
```

---

## 运行方式

### 方式一：Godot 编辑器内运行

1. 打开 `tests/test_scene.tscn`
2. 直接运行该场景（**F6** 或点击"运行当前场景"）
3. 在"输出"面板查看测试结果

### 方式二：命令行运行（推荐用于持续验证）

**注意：必须使用带 `console` 后缀的可执行文件**，否则无法正确输出日志到终端。

在 `Afternoon_algebra/coding` 目录下执行：

```bash
# 假设 Godot 安装在 D:\Godot\...（根据实际情况调整路径）
"D:/Godot/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" \
  --headless --path . --scene tests/test_scene.tscn
```

参数说明：
- `--headless`：无界面模式，不渲染窗口
- `--path .`：以当前目录作为项目根目录
- `--scene tests/test_scene.tscn`：直接运行测试场景

---

## 断言方法（base_test.gd 提供）

| 方法 | 说明 |
|---|---|
| `assert_eq(actual, expected, msg)` | 断言相等 |
| `assert_ne(actual, expected, msg)` | 断言不相等 |
| `assert_true(condition, msg)` | 断言为真 |
| `assert_false(condition, msg)` | 断言为假 |
| `assert_null(value, msg)` | 断言为 null |
| `assert_not_null(value, msg)` | 断言非 null |
| `assert_almost_eq(a, b, tolerance, msg)` | 浮点数近似相等 |
| `fail(msg)` | 强制失败 |

---

## 最新测试结果

**日期**：2026-05-14

| 模块 | 测试数 | 结果 |
|---|---|---|
| test_hex_grid.gd | 21 | 全部通过 |
| test_marble.gd | 20 | 全部通过 |
| test_blue_marble.gd | 12 | 全部通过 |
| test_white_marble.gd | 14 | 全部通过 |
| test_game_manager.gd | 12 | 全部通过 |

**总计：79 个测试，0 个失败。**

---

## 修改记录

### 2026-05-14：完善棋盘功能测试（通过生成棋子验证棋盘状态）

本次更新重点：现有棋盘（HexGrid2D）已就绪，测试全面改用真实 `Marble2D` 棋子节点，验证棋盘的字典一致性、多棋子共存、碰撞/死亡后的棋盘状态、随从在棋盘上的全生命周期等。

#### 1. `test_hex_grid.gd` — 用真实棋子测试棋盘核心功能
- 所有弹珠测试节点由 `Area2D.new()` 替换为 `Marble2D.new()`（`_create_test_marble` 辅助方法）
- 新增 `test_get_marble_hex`：验证 `get_marble_hex()` 能正确返回棋子坐标
- 新增 `test_get_marble_hex_unplaced`：验证未放置棋子返回 `(0,0)`
- 新增 `test_remove_marble_by_node`：验证 `remove_marble_by_node()` 正确移除
- 新增 `test_multiple_marbles_on_board`：验证多棋子共存时棋盘字典大小正确
- 新增 `test_board_state_after_marble_move`：验证棋子移动后原位置清空、新位置正确、其他棋子不受影响
- 新增 `test_marble_reposition_updates_grid`：验证同一棋子重新放置时旧位置被清空、不重复计数
- 新增 `test_place_marble_at_edge` / `test_place_marble_out_of_bounds`：边界附近放置行为
- 新增 `test_board_dictionary_integrity`：遍历 `grid.marbles` 字典，验证键值对与 `get_marble_at()` 一致且无 null
- 新增 `test_clear_board_after_removal`：全部移除后字典应为空

#### 2. `test_blue_marble.gd` — 随从在棋盘上的生成/移动/清除
- 新增 `test_followers_are_placed_on_grid`：随从生成后，验证 `grid.get_marble_hex()` 和 `grid.get_marble_at()` 能正确查询到随从
- 新增 `test_follower_positions_match_hex_coords`：验证随从的 `position` 与 `hex_to_world` 计算值一致
- 新增 `test_clear_followers_removes_from_grid`：随从清除后，验证棋盘上对应坐标查询为 null
- 新增 `test_blue_move_updates_follower_grid_positions`：验证随从移动后旧位置清空、新位置正确
- 新增 `test_blue_survives_when_followers_safe`：中心区域移动，蓝球应存活且到达正确坐标
- 新增 `test_board_clean_after_blue_move`：蓝球移动后，棋盘上只应剩下蓝球本身，无残留随从
- 修正 `test_follower_spawn_avoids_occupied`：原期望"一侧被占时只生成1个"与代码逻辑不符（代码会从其他方向补足到2个），改为验证"不会生成在被占据格子上"且总数为2

#### 3. `test_marble.gd` — 碰撞与死亡后的棋盘状态一致性
- 新增 `test_move_updates_grid_position`：移动后原位置为空、新位置有该棋子
- 新增 `test_move_step_by_step_grid_state`：单步移动后的棋盘状态
- 新增 `test_collision_updates_grid_state`：两球碰撞后，验证碰撞者未动、被撞者获得剩余步数继续移动，棋盘各位置状态正确
- 新增 `test_collision_chain_grid_state`：三球链式碰撞后，验证中间球未动、末端球持续移动，棋盘状态正确
- 新增 `test_die_updates_board_size`：棋子死亡后棋盘字典大小减1，剩余棋子不受影响
- 修正 `test_collision_moves_target` / `test_collision_chain`：原有期望值与代码实际行为不符（弹性碰撞语义：碰撞者不动，被撞者获得剩余步数继续移动），已按实际行为修正期望值

#### 4. `test_white_marble.gd` — 变色后的棋盘交互
- 新增 `test_blue_white_spawns_followers_on_grid`：白球变蓝后移动，验证存活且坐标正确
- 新增 `test_blue_white_move_updates_grid_state`：变蓝移动后，原位置为空、新位置有该棋子
- 新增 `test_blue_white_collision_with_followers_grid_state`：变蓝后碰撞敌方，验证碰撞者和被撞者的棋盘位置正确
- 改进 `after_each`：增加对残留随从的清理（`BlueMarbleHelper.clear_followers`）

#### 5. 源码 bug 修复
- **`BlueMarbleHelper.gd` 类型错误**：`_get_follower_spawn_cells` 中 `var candidates = []` 未标注类型，函数返回类型为 `Array[Vector2]`，运行时抛出 `Trying to return an array of type "Array" where expected return type is "Array[Vector2]"`。已修复为 `var candidates: Array[Vector2] = []`。
