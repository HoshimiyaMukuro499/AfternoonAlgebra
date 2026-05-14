# Godot 测试框架说明

## 文件结构

```
tests/
├── base_test.gd           # 测试基类，提供 assert_eq / assert_true 等断言方法
├── test_runner.gd         # 测试运行器，自动发现并执行所有测试
├── test_scene.tscn        # 测试场景，在 Godot 中打开此场景即可运行全部测试
├── test_hex_grid.gd       # HexGrid2D 棋盘测试（坐标转换、边界、放置/移动/移除）
├── test_marble.gd         # Marble2D 基类测试（移动、碰撞、邻居计算、高亮、死亡）
├── test_blue_marble.gd    # 蓝球/随从测试（生成位置、清除、联动移动）
├── test_white_marble.gd   # 白球测试（变色、碰撞步数加成、按颜色移动分发）
└── test_game_manager.gd   # GameManager 状态机测试（选择、取消、回合切换）
```

## 运行方式

在 Godot 编辑器中：
1. 打开 `tests/test_scene.tscn`
2. 直接运行该场景（F6 或点击"运行当前场景"）
3. 在"输出"面板查看测试结果

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

## 已知代码问题

### `BlueMarbleHelper.gd` 属性名不一致

`BlueMarbleHelper` 多处使用了 `marble.hex_grid_2d`：
- `_get_follower_spawn_cells` 第 55、69 行
- `_create_follower` 第 84、85 行
- `_move_follower` 第 111、113、120 行

但 `Marble2D` 类中定义的属性名是 `hex_grid`（没有 `_2d` 后缀）。这会导致随从相关逻辑在运行时抛出 `Invalid get index 'hex_grid_2d'` 错误。

**建议修复**：将 `BlueMarbleHelper.gd` 中所有 `hex_grid_2d` 替换为 `hex_grid`。
