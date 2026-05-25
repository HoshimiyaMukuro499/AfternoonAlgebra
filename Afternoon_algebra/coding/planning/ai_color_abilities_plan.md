# AI 颜色专属功能决策逻辑 实施总结

## 已完成修改

### 1. GameManager.gd — 黑球行动流程

**新增 TurnState 枚举值：**
- `BLACK_MARBLE_SELECTED` — 黑球被选中，等待选择敌方目标
- `BLACK_TARGET_PICKING` — 黑球已选目标，等待选大致方向
- `BLACK_DIRECTION_PICKING` — 黑球方向已选，执行强制移动

**新增变量：**
- `black_target_marble` — 黑球选择的敌方目标弹珠
- `black_approx_direction` — 黑球选择的大致方向

**新增方法：**
- `black_select_target(target: Marble2D)` — 选择敌方目标
- `black_select_approx_direction(direction: int)` — 选择大致方向，执行强制移动
- `_execute_black_move()` — 执行黑球强制移动（调用 black_marble.force_enemy_move）

**修改的方法：**
- `select_marble()` — 黑球选中后进入 `BLACK_MARBLE_SELECTED` 状态，不再走普通移动流程
- `cancel_selection()` — 支持黑球三状态的取消
- `start_turn()` — 重置黑球变量
- `_execute_ai_action()` — 新增 `select_enemy` 和 `select_approx_direction` 动作

### 2. RandomAI.gd — 黑球智能决策

**新增决策方法：**
- `_decide_black_target(gm)` — 选择敌方目标
  - 优先选择距离棋盘边缘最近的敌方弹珠（更容易被推出界）
  - 使用 `MarbleConst.GRID_RADIUS - max(|q|, |r|, |q-r|)` 计算边缘距离
- `_decide_black_approx_direction(gm)` — 选择大致方向
  - 模拟目标坐标沿6个方向走3步
  - 选择步数中出界次数最多的方向（指向棋盘外）
- `_get_neighbor_hex(hex, dir)` — 辅助坐标计算

**新增 match 分支：**
- `BLACK_MARBLE_SELECTED` → `_decide_black_target`
- `BLACK_TARGET_PICKING` → `_decide_black_approx_direction`

## 待办事项

### 3. InputHandler.gd — 黑球玩家交互
黑球选择目标和大致方向需要玩家通过点击交互：
- `BLACK_TARGET_PICKING` 状态：点击敌方弹珠选择目标
- `BLACK_DIRECTION_PICKING` 状态：点击相邻格子选择方向

需要对 AI mode 来说这一步不是必须的（AI 通过代码直接调用方法），但玩家交互需要更新。

### 4. UI.gd — 黑球状态提示
目前 UI 只在 `MARBLE_SELECTED` 状态下提示红球特殊信息，需要增加黑球状态的提示。

### 5. 蓝球方向选择优化（可选）
AI 选择蓝球方向时，可以优先选择随从生成位置更丰富的方向（两侧空闲格多）。

### 6. 绿球方向选择优化（可选）
AI 选择绿球方向时，可以优先选择周围有敌方弹珠的方向（推挤效果最大化）。

### 7. 黄球死亡增益 AI 选择（可选）
黄球死亡时，AI 需要选择增益目标弹珠。
