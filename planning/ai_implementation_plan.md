# AI 对战实现规划方案

> 基于现有《午后代数》Godot 4.6 项目的 AI 对战功能扩展规划
> 编写日期：2025-06-09

---

## 目录

1. [项目现状](#1-项目现状)
2. [总体架构设计](#2-总体架构设计)
3. [Phase 1：基础设施 + 随机 AI（3天）](#3-phase-1基础设施--随机-ai3天)
4. [Phase 2：启发式 AI（5天）](#4-phase-2启发式-ai5天)
5. [Phase 3：MCTS 高级 AI（选做，7天）](#5-phase-3mcts-高级-ai选做7天)
6. [各颜色弹珠的 AI 决策指南](#6-各颜色弹珠的-ai-决策指南)
7. [测试策略](#7-测试策略)
8. [风险与缓解](#8-风险与缓解)
9. [附录：文件清单](#9-附录文件清单)

---

## 1. 项目现状

### 1.1 现有架构摘要

| 层级 | 组件 | 职责 |
|------|------|------|
| **游戏流程** | `GameManager.gd` | 状态机（选珠→IDLE→MARBLE_SELECTED→DIRECTION_SELECTED→EXECUTING→VICTORY），回合切换 |
| **输入** | `InputHandler.gd` | 鼠标/键盘事件 → 调用 GameManager API |
| **UI** | `UI/UI.gd` | 回合信息、选珠界面、胜利提示 |
| **棋盘** | `HexGrid2D.gd` | 六边形网格数据、弹珠位置管理 |
| **弹珠** | `Marble2D.gd` + 6个子类 | 移动、碰撞、各颜色特性 |
| **策略** | `*MoveStrategy.gd`（6个） | 各颜色移动行为 |
| **辅助** | `*Helper.gd`（4个） | 蓝球随从、黄球增益等 |
| **死亡结算** | `DeathResolver.gd` | 同时死亡时白球变色分配 |
| **测试** | `tests/`（14个文件） | GUT 框架，全部不依赖场景树 |

### 1.2 已有有利条件

- ✅ **清晰的 API 层**：`GameManager` 提供 `select_marble()`、`select_direction()`、`select_power()`、`red_select_power()`、`red_append_direction()` 等公开方法，AI 直接调用
- ✅ **纯逻辑可测试**：测试全部在无场景树环境下运行，说明核心逻辑是纯数据驱动的
- ✅ **状态机完整**：AI 每个决策点都有明确的状态对应
- ✅ **棋盘查询能力**：`hex_grid.get_marble_at()`、`hex_grid.is_out_of_bounds()`、`get_available_positions()` 可获取完整棋盘状态
- ✅ **红球逐格决策已有支持**：`RED_DIRECTION_PICKING` 状态 + `red_append_direction()` 证明了非阻塞式多步决策机制
- ✅ **选珠阶段接口友好**：`setup_select_color()`、`setup_place_marble()` 同样适用于 AI

---

## 2. 总体架构设计

### 2.1 新增目录结构

```
coding/
├── ai/
│   ├── AIStrategy.gd          # AI 策略基类（接口定义）
│   ├── RandomAI.gd            # 随机 AI（Phase 1）
│   ├── HeuristicAI.gd         # 启发式 AI（Phase 2）
│   └── MCTS_AI.gd             # 蒙特卡洛树搜索 AI（Phase 3，选做）
├── tests/
│   └── test_ai.gd             # AI 测试
├── planning/
│   └── ai_implementation_plan.md   # 本文件
└── GameManager.gd             # 修改：添加 AI 支持
```

### 2.2 核心接口设计

```gdscript
# AIStrategy.gd - 所有 AI 策略的基类
class_name AIStrategy
extends RefCounted

# ── 决策入口 ──
# 根据当前 GameManager 状态，返回下一步操作
# 返回值 Dictionary:
#   { "action": "select_marble", "marble": Marble2D }
#   { "action": "select_direction", "direction": int }
#   { "action": "select_power", "power": int }
#   { "action": "red_power", "power": int }
#   { "action": "red_direction", "direction": int }
#   { "action": "setup_color", "color": int }
#   { "action": "setup_place", "q": int, "r": int }
func decide(gm: GameManager) -> Dictionary:
    push_error("未实现")
    return {}

# ── 棋盘评估（用于启发式 / MCTS）──
func evaluate(gm: GameManager) -> float:
    push_error("未实现")
    return 0.0
```

### 2.3 GameManager 改动要点

```gdscript
# GameManager.gd 新增内容

# ── 新增信号 ──
signal ai_turn_started(camp)  # AI 开始决策

# ── 新增变量 ──
var ai_enabled: bool = false
var ai_teams: Array[int] = []  # AI 控制的阵营列表（可支持 AIvsAI）
var ai_strategies: Dictionary = {}  # camp → AIStrategy 实例

# ── 新增/修改方法 ──

# 在 start_turn() 末尾判断是否需要触发 AI
func start_turn():
    # ... 现有代码 ...
    if ai_enabled and current_team in ai_teams:
        _trigger_ai_turn.call_deferred()

# AI 决策调度
func _trigger_ai_turn():
    var strategy = ai_strategies.get(current_team)
    if not strategy:
        return
    var action = strategy.decide(self)
    _execute_ai_action(action)

# 执行 AI 动作（路由到对应 API）
func _execute_ai_action(action: Dictionary):
    match action.get("action"):
        "select_marble":   select_marble(action.marble)
        "select_direction": select_direction(action.direction)
        "select_power":    select_power(action.power)
        "red_power":       red_select_power(action.power)
        "red_direction":   red_append_direction(action.direction)
        "setup_color":     setup_select_color(action.color)
        "setup_place":     setup_place_marble(action.q, action.r)
```

### 2.4 AI 与已有系统的关系

```
┌─────────────────────────────────────────────────┐
│                   GameManager                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ 玩家输入  │  │  AI调度  │  │  状态机/规则  │   │
│  │InputHandler│  │_trigger_ │  │   start_turn │   │
│  │           │  │ AI_turn  │  │  execute_move│   │
│  └─────┬─────┘  └────┬─────┘  └──────┬───────┘   │
│        │              │               │           │
│        ▼              ▼               ▼           │
│  ┌──────────────────────────────────────────┐     │
│  │         GameManager 公共 API               │     │
│  │  select_marble / select_direction / ...    │     │
│  └──────────────────────────────────────────┘     │
└─────────────────────────────────────────────────┘
```

> **核心原则**：AI 路径与玩家路径在 API 层汇合，GameManager 不区分调用来源。

---

## 3. Phase 1：基础设施 + 随机 AI（3天）

### 3.1 目标

实现 AI 对战的最简可行版本：**人vs随机AI** 可完整运行一局游戏。

### 3.2 任务分解

#### Day 1：创建 AI 基类和随机 AI

| 文件 | 内容 |
|------|------|
| `ai/AIStrategy.gd` | 基类 + `decide()`/`evaluate()` 接口 + `get_game_snapshot()` 工具方法 |
| `ai/RandomAI.gd` | 所有决策点随机选择合法操作的实现 |

**RandomAI 决策逻辑：**

| 游戏阶段 | GameManager 状态 | 随机选择 |
|---------|-----------------|---------|
| 选珠-选颜色 | 选珠阶段 COLOR_SELECT | 随机选 0-5 中的一个颜色 |
| 选珠-放置 | 选珠阶段 PLACEMENT | 从 `get_available_positions()` 随机选 |
| 选弹珠 | IDLE | 从己方存活弹珠中随机选 |
| 选方向 | MARBLE_SELECTED | 随机选 0-5 |
| 选力度 | DIRECTION_SELECTED | 随机选 1-5 |
| 红球选力度 | MARBLE_SELECTED（红球） | 随机选 1-5 |
| 红球选方向（每步） | RED_DIRECTION_PICKING | 从 6 个方向中随机选 |

#### Day 2：修改 GameManager

| 改动 | 说明 |
|------|------|
| 新增 `ai_enabled` / `ai_teams` / `ai_strategies` | 控制 AI 启用状态 |
| 新增 `_trigger_ai_turn()` / `_execute_ai_action()` | 调度和执行 AI 动作 |
| 修改 `start_turn()` | 末尾判断是否触发 AI |
| 新增 `start_new_game()` | 统一入口，接受模式参数 |
| 新增 `set_ai_for_camp(camp, strategy)` | 设置 AI 策略 |

#### Day 3：UI/菜单 + 端到端验证

| 改动 | 说明 |
|------|------|
| 修改 `menu.tscn` / `menu.gd` | 添加模式选择（人vs人 / 人vsAI / AIvsAI） |
| 修改 `GameManager._ready()` | 支持从菜单接收模式参数 |
| 实现 `tests/test_ai.gd` | AIvsAI 自动对局测试 |

### 3.3 交付物

- ✅ 人vs随机AI 可完整游戏
- ✅ AIvsAI 可自动对局（用于调试和演示）
- ✅ 至少 5 个 AI 相关测试通过
- ✅ 所有已有测试无回归

---

## 4. Phase 2：启发式 AI（5天）

### 4.1 目标

实现一个**能做出合理决策**的 AI，具备基本的局势评估和策略选择能力。

### 4.2 棋盘评估函数

```gdscript
func evaluate(gm: GameManager, for_camp: int) -> float:
    var score = 0.0

    # 1. 弹珠数量优势（权重最高）
    var my_count = count_alive(gm, for_camp)
    var enemy_count = count_alive(gm, opponent(for_camp))
    score += (my_count - enemy_count) * 100

    # 2. 位置控制（棋盘中心区域得分更高）
    for marble in get_my_marbles(gm, for_camp):
        score += evaluate_position(marble) * 10

    # 3. 各颜色价值加权
    #    白球（变色潜力）> 蓝球（随从）> 绿球（推挤）> 红球（多向）> 黄球 > 黑球
    for marble in get_my_marbles(gm, for_camp):
        score += color_value(marble.color) * 20

    # 4. 威胁评估（敌方可能吃掉己方弹珠的情况）
    score -= evaluate_threats(gm, for_camp) * 30

    # 5. 己方威胁能力（己方可能吃掉敌方弹珠的情况）
    score += evaluate_offense(gm, for_camp) * 25

    return score
```

### 4.3 HeuristicAI 决策流程

```
对于每个可能的操作：
  1. 模拟执行该操作（内存中）
  2. 调用 evaluate() 评估结果局面
  3. 选择评估值最高的操作

红球特殊处理：
  - 先遍历所有可能的力度(1-5)
  - 对每个力度，用贪心策略逐格选方向（每步选使评估值最大的方向）
  - 选择整体评估最高的力度+路径组合
```

### 4.4 各颜色决策启发式

| 颜色 | AI 决策要点 |
|------|------------|
| **白** | 优先往有敌方弹珠的方向走，利用碰撞将对方推出界 |
| **蓝** | 选择随从生成位置最优的方向（随从在两侧生成），考虑随从阻挡对方路径 |
| **绿** | 往敌方密集区走，利用推挤一次推动多个敌方弹珠 |
| **红** | 规划 L 形或折线路径，绕过障碍物攻击敌方后排 |
| **黑** | 不需要决策移动，但作为"碰撞锚点"有战略价值，AI 应评估其位置 |
| **黄** | 用期望步数代替随机步数做决策 |

### 4.5 选珠阶段 AI 策略

```gdscript
func decide_setup_color(gm: GameManager) -> int:
    # 优先级：白 > 蓝 > 绿 > 红 > 黄 > 黑
    # 优先选未选过的颜色
    var used_colors = get_used_colors(gm, gm.setup_current_team)
    for color in [WHITE, BLUE, GREEN, RED, YELLOW, BLACK]:
        if color not in used_colors:
            return color
    return randi() % 6

func decide_setup_placement(gm: GameManager) -> Vector2:
    # 策略：优先占据中心区域 + 分散布局
    # 1. 筛选己方可放置位置
    # 2. 按"到中心的距离 + 到已有弹珠的距离"综合评分
    # 3. 选最高分位置
    var positions = gm.hex_grid.get_available_positions(gm.setup_current_team)
    # ... 评分排序 ...
    return best_position
```

### 4.6 交付物

- ✅ 启发式 AI 可稳定打败随机 AI（胜率 > 80%）
- ✅ 选珠阶段具备合理的选色和布阵策略
- ✅ AI 能正确使用各颜色特性（蓝球随从、绿球推挤、红球折线）
- ✅ 完整的评估函数单元测试

---

## 5. Phase 3：MCTS 高级 AI（选做，7天）

### 5.1 目标

实现蒙特卡洛树搜索 AI，通过大量模拟对局来评估走法，达到接近人类玩家的水平。

### 5.2 MCTS 核心设计

```
每个节点表示一个游戏状态
├── 根节点：当前真实局面
├── 选择（Selection）：UCT 公式选择最佳子节点
├── 扩展（Expansion）：添加新子节点
├── 模拟（Simulation）：随机 playout 到终局
└── 回传（Backpropagation）：更新节点统计

UCT 公式：
  UCT = Q/N + C * sqrt(ln(N_parent) / N)
  其中 C = 1.414（探索常数）
```

### 5.3 状态克隆问题

MCTS 需要在内存中模拟游戏，需要解决状态克隆：

```gdscript
# 方案：快照克隆（snapshot），非深拷贝
# 只克隆需要的信息：
#   - 棋盘字典（弹珠位置）
#   - 弹珠存活状态 + 颜色 + 阵营
#   - 当前回合数/阵营
#   - 不克隆场景树节点（性能考虑）

func clone_state(gm: GameManager) -> Dictionary:
    var snapshot = {
        "marbles": {},
        "current_team": gm.current_team,
        "turn_number": gm.turn_number,
    }
    for hex_pos in gm.hex_grid.marbles:
        var marble = gm.hex_grid.marbles[hex_pos]
        snapshot.marbles[hex_pos] = {
            "camp": marble.camp,
            "color": marble.color,
            "is_alive": marble.is_alive,
        }
    return snapshot

# 在快照上模拟移动（不依赖场景树）
func simulate_move(snapshot: Dictionary, action: Dictionary) -> Dictionary:
    # 复制快照，在副本上执行移动逻辑
    # 返回新快照
```

### 5.4 优化方向

| 优化 | 说明 | 预估提升 |
|------|------|----------|
| 早期剪枝 | 前几回合不考虑明显差的走法 | 模拟次数 ×2 |
| 开局书 | 预设选珠阶段的最佳阵型 | 选珠速度 ×10 |
| 并行模拟 | Godot 4 支持多线程 | 速度 ×N（核心数） |
| 时间控制 | 根据剩余时间调整模拟次数 | 稳定帧率 |

### 5.5 交付物

- ✅ MCTS AI 在固定时间内的决策质量显著高于启发式 AI
- ✅ 支持时间控制（如每步限制 3 秒）
- ✅ 可配置模拟次数
- ✅ MCTS 单元测试（验证 UCT 选择和 playout 正确性）

---

## 6. 各颜色弹珠的 AI 决策指南

### 6.1 红色弹珠（定向者）

```
难点：每步可选不同方向，搜索空间大（5步 × 6方向 = 6^5 = 7776 种路径）

Phase 1（随机）：每步随机选方向
Phase 2（启发式）：
  - 用 BFS/A* 规划到达目标的折线路径
  - 每步贪心：选使评估函数值最大的方向
  - 极端情况：只有1步时就是普通弹珠
Phase 3（MCTS）：
  - 在模拟时将红球的逐格决策展开为独立动作
  - 使用早期剪枝：只考虑通往有敌方弹珠区域的方向
```

### 6.2 蓝色弹珠（统领者）

```
难点：随从的生成位置影响后续碰撞

决策要点：
  1. 随从在移动方向两侧生成（左侧和右侧）
  2. 随从会一起移动并可能碰撞
  3. 随从出界可能导致蓝球死亡（除非有 follower_safe 增益）

AI 策略：
  - 选择方向时，考虑两侧随从生成位是否被占用
  - 如果生成位被己方弹珠占据，可能导致随从数量不足
  - 随从可以作为"路障"撞击敌方弹珠
```

### 6.3 绿色弹珠（推挤者）

```
难点：推挤范围仅1格，路径上的连续阻挡需要特殊处理

决策要点：
  1. 绿球移动时，路径相邻格子的弹珠被推挤
  2. push_range=1，被推的弹珠只移动1格
  3. 推挤可把敌方推出界

AI 策略：
  - 优先瞄准边界附近的敌方弹珠
  - 评估路径上是否有己方弹珠（避免推挤友方）
  - 推挤范围可通过黄球增益增加
```

### 6.4 白色弹珠（遗愿者）

```
难点：变色后的行为取决于变成的颜色

决策要点：
  1. 白球本身是普通移动（无特殊能力）
  2. 己方弹珠死亡时，白球变色为死亡弹珠的颜色
  3. 变色是自动触发的，AI 不需要主动决策

AI 策略：
  - 白球价值高，应尽量保护
  - 考虑"牺牲某个颜色的弹珠来让白球变色"的战略
```

### 6.5 黑色弹珠（干扰者）

```
特点：不能主动移动，但被碰撞后会正常反弹

决策要点：
  1. 黑球在 move() 时直接返回，不移动
  2. 被其他弹珠碰撞时，行为同普通弹珠
  3. 纯防守型弹珠

AI 策略：
  - 把黑球当作"障碍物"来阻挡敌方路径
  - 不主动选择黑球（无操作）
  - 选珠阶段黑球优先级最低
```

### 6.6 黄色弹珠（牺牲者）

```
难点：实际步数随机 ±1（均匀分布）

决策要点：
  1. 选择的力度不确定，实际步数 = 力度 ± 1（至少1步）
  2. 死亡时增益一个友方同色弹珠

AI 策略：
  - 用期望值决策（如选3步，期望3步）
  - 靠近边界时小心步数超出导致的意外死亡
  - 死亡增益是重要的战略价值
```

---

## 7. 测试策略

### 7.1 新增测试文件

| 文件 | 测试内容 |
|------|---------|
| `tests/test_ai.gd` | AI 策略基类、随机 AI、启发式 AI 的单元测试 |

### 7.2 测试用例设计

```
test_ai.gd
├── AIStrategy 基类
│   ├── test_decide_not_implemented()    # 直接调用基类应有错误
│   └── test_get_game_snapshot()         # 快照包含必要字段
│
├── RandomAI
│   ├── test_random_select_marble()      # 只选己方存活弹珠
│   ├── test_random_select_direction()   # 返回 0-5
│   ├── test_random_select_power()       # 返回 1-5
│   ├── test_random_setup_color()        # 返回 0-5
│   ├── test_random_setup_place()        # 返回可放置坐标
│   └── test_random_vs_random_playable() # AIvsAI 可完整对局
│
├── HeuristicAI
│   ├── test_evaluate_basic()            # 评估函数返回合理值
│   ├── test_evaluate_more_marbles_better() # 弹珠多得分高
│   ├── test_selects_obvious_capture()   # 能吃掉对方弹珠时优先选
│   ├── test_avoids_suicide()            # 不会把自己送出界
│   └── test_setup_placement_valid()     # 选珠阶段放置在合法位置
│
├── GameManager AI 集成
│   ├── test_ai_turn_triggers()          # AI 回合自动触发
│   ├── test_ai_executes_full_game()     # AIvsAI 完整对局
│   ├── test_ai_vs_random_win_rate()     # 启发式胜率测试
│   └── test_ai_does_not_alter_manual()  # 人vsAI 时手动操作不受影响
```

### 7.3 胜率测试方法

```gdscript
func test_heuristic_vs_random_win_rate():
    var heuristic_wins = 0
    var total_games = 50

    for i in range(total_games):
        var gm = setup_ai_game()
        var heuristic = HeuristicAI.new()
        var random = RandomAI.new()
        gm.set_ai_for_camp(RED, heuristic)
        gm.set_ai_for_camp(BLUE, random)
        run_game_to_end(gm)
        if gm.current_state == VICTORY:
            heuristic_wins += 1

    var win_rate = heuristic_wins / float(total_games)
    assert_gt(win_rate, 0.7, "启发式AI胜率应 > 70%")
```

### 7.4 回归保证

每次修改后运行完整测试套件：
```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit_on_success=true
```

---

## 8. 风险与缓解

| 风险 | 等级 | 影响 | 缓解措施 |
|------|------|------|----------|
| 红球逐格决策搜索空间大 | 🟡 中 | Phase 2 启发式可能不够好 | 用 BFS 路径规划 + 贪心每步选择，不枚举所有路径 |
| 状态克隆性能瓶颈 | 🟡 中 | Phase 3 MCTS 模拟速度慢 | 用快照而非深拷贝，只克隆必要字段 |
| 黄球随机性导致决策不稳定 | 🟢 低 | AI 重复局面可能选不同走法 | 用期望值评估；MCTS 天然支持随机性 |
| 选珠阶段 AI 策略影响大 | 🟢 低 | 布阵差导致后续被动 | 简单的"分散+中心优先"策略已足够 |
| 蓝球随从的间接影响 | 🟢 低 | AI 可能低估随从的战略价值 | 在评估函数中加入"随从占据格子"的加分 |
| AI 决策耗时导致帧率下降 | 🟢 低 | 玩家体验差 | 使用 `call_deferred()` 分帧执行；MCTS 加时间限制 |
| Godot 4 中 RefCounted 的限制 | 🟢 低 | 无法使用 `@onready` 等节点相关功能 | AI 策略不需要场景树，纯逻辑即可 |

---

## 9. 附录：文件清单

### 9.1 新增文件

| 文件 | 预估行数 | 所属 Phase |
|------|---------|-----------|
| `ai/AIStrategy.gd` | ~60 | Phase 1 |
| `ai/RandomAI.gd` | ~120 | Phase 1 |
| `ai/HeuristicAI.gd` | ~350 | Phase 2 |
| `ai/MCTS_AI.gd` | ~400 | Phase 3（选做）|
| `tests/test_ai.gd` | ~250 | Phase 1 |
| `planning/ai_implementation_plan.md` | — | 本文档 |
| **合计** | **~1180** | |

### 9.2 修改文件

| 文件 | 改动量 | 说明 |
|------|--------|------|
| `GameManager.gd` | +~80行 | 添加 AI 调度、AI 控制变量、新游戏入口 |
| `menu.gd` | +~30行 | 添加模式选择逻辑 |
| `menu.tscn` | 少量 UI 元素 | 添加对战模式按钮 |
| **合计** | **+~110行** | |

### 9.3 不变文件

以下文件**完全不需要修改**（确保零回归）：

- `Marble2D.gd` 及 6 个颜色子类
- 所有 `*MoveStrategy.gd`
- 所有 `*Helper.gd`
- `HexGrid2D.gd`
- `DeathResolver.gd`
- `BoardInitializer.gd`
- `InputHandler.gd`
- `UI/UI.gd`
- 所有已有测试文件（14个）

---

## 更新日志

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2025-06-09 | v1.0 | 初始版本 |
