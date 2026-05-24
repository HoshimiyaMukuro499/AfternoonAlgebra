# 从教程场景跳转到主场景时程序卡死问题修复

## 问题描述

在菜单中选择 AI 模式（任一 AI 模式）后进入教程场景，无论点击"下一页"直到最后
（"开始游戏"按钮）还是直接"跳过教程"，程序都会卡死无法正常开始游戏。

## 根因分析

### 核心 Bug：AI 选珠阶段的异步竞争条件

`GameManager._execute_ai_action()` 中处理 `"setup_place"` 动作时，直接调用了
`setup_place_marble(action.q, action.r)` —— 但 `setup_place_marble` 是一个**协程**
（含有 `await` 语句）。

当 AI 放置该方的最后一颗弹珠（第6颗）时，`setup_place_marble` 会：
1. 显示阵型名称
2. `await get_tree().create_timer(3.0).timeout` —— 暂停3秒

由于 `_execute_ai_action` **没有 `await`** 这个调用，函数执行到 `await` 后立即返回，
然后继续执行后面的 `_trigger_ai_turn.call_deferred()`。

这导致在 3 秒等待期间：
- 新的 `_trigger_ai_turn` 被触发
- AI 尝试再次决策 `setup_place`
- `setup_state` 仍是 `PLACEMENT`（await 期间未更新）
- `setup_current_team` 仍是同一方
- 但所有 6 个位置都已填满，`_decide_setup_placement` 找不到可用位置
- 返回 `{action: "setup_place", q: 0, r: 0}` 这个无效位置
- `setup_place_marble(0, 0)` 因为 `(0,0)` 不在合理区域内，直接 return
- 然后又触发下一轮 `_trigger_ai_turn.call_deferred()`
- **形成死循环，程序卡死**

### 次要问题：RandomAI 无可用位置时返回无效数据

`_decide_setup_placement` 在 `available.size() == 0` 时返回 `{q: 0, r: 0}`，
这是一个硬编码的无效值，应该返回空字典让上层停止 AI 决策。

## 修复方案

### 1. 让 `_execute_ai_action` 正确 await 协程 (GameManager.gd)

将 `_trigger_ai_turn` 改为 async 函数，`await _execute_ai_action`：
```gdscript
func _trigger_ai_turn():
    ...
    await _execute_ai_action(action)
    _ai_pending = false
```

将 `_execute_ai_action` 的 `"setup_place"` 分支加上 `await`：
```gdscript
"setup_place":
    await setup_place_marble(action.q, action.r)
    ...
```

### 2. 让 RandomAI 在无可用位置时返回空字典 (ai/RandomAI.gd)

```gdscript
if available.size() == 0:
    push_error("RandomAI: 没有可放置的位置，跳过决策")
    return {}  # 返回空字典，让上层停止 AI 决策循环
```

### 3. 改进 Tutorial.gd 的场景切换逻辑 (UI/Tutorial.gd)

教程页面按钮现在同时支持两种使用方式：
- 作为 `GameManager` 的子节点嵌入：发射 `tutorial_finished` 信号
- 作为独立场景（从菜单跳转）：直接 `change_scene_to_file("res://main.tscn")`
