# 一、现有进度总结+提交流程
## 🎯 新任务分配（基于实际进度）

### **A ：GameManager 回合流程 + 架构清理**

**Step 2**（等 D 完成策略模式后）：
- [ ] `GameManager.gd` — **添加死亡→白球变色钩子**：当检测到非黄、非白弹珠死亡时，调用 `white_marble.on_teammate_died(color)`
- [ ] `GameManager.gd` — **添加黄球死亡增益钩子**：发射 `yellow_died(dead_yellow_marble)` 信号，让 C 的 UI 处理目标选择
- [ ] `GameManager.gd` — **添加黑球选中特殊逻辑**：如果 `selected_marble.color == BLACK`，进入黑球交互状态（等 C 的 UI）
- [ ] 修正移动方式：伪动态痕迹
### **B ：绿球/红球算法修复 + 蓝球完善**

**Step 1**（无依赖）：
- [x] `GreenMarbleHelper.gd` — **重构 `push_neighbors()` 为同时推挤**
  - [x] 第一步：遍历6方向，收集所有 `(被推弹珠, 源格子, 目标格子)` 三元组
  - [x] 第二步：检查每个目标格子是否出界/被占
  - [x] 第三步：批量同时移动（这一步用同一帧移动所有弹珠）
  - [x] 写成纯函数：`push_simultaneous(board_state, green_pos, push_range) - [ ]> Array[PushAction]`

**Step 2**（无依赖）：
- [x] `InputHandler.gd` — **实现 `_try_select_power(pos)`**（红球逐方向选择）
  - [x] 红球在当前状态可以选择每步方向，点击相邻格子决定每步方向
- [x] `red_marble.gd` — 完善红球移动方式，支持逐方向选择

**Step 3**：
- [x] 编写绿球推挤测试、红球逐方向测试
- [x] `blue_marble.tscn` — **删除 UI 子节点**（CanvasLayer/Label）

- [x] (optional)检查红球的操作流程——在选择总力度之后走一步选一步方向，而不是先选定每一步的方向之后再移动

- [ ] 检查蓝球的随从生成，保证随从能够在移动的过程中正确显示（目前也有蓝球随从碰撞的效果，但是看不到蓝球的随从）

- [x] 检查绿球的技能效果在移动结束之后触发推挤


---

### **C：UI 框架 + 黄球/黑球交互 + 视觉**
C任务进行重构，若有遗漏，敬请补充
- [x] 完成主界面
- [x] 完成新手文档
- [x] 完成方向选择指示 并将结果调用到接口中
- [x] 完成力度选择指示 并将结果调用到接口中
- [ ] 完成黄球增益选择UI 并将结果调用到接口中
- [ ] 完成黑球特殊移动UI 并调用force_move
- [x] 完成胜负界面
- [x] 改善双方弹珠显示，增加区分度
---
### **D ：核心算法重构 + 集成测试**

**Step 1**（无依赖，立刻开始）：
- [x] **白球策略模式重构**
  - [x] 定义 `MoveStrategy` 基类（或直接用 `Callable`）
  - [x] 为每个颜色创建策略：`WhiteMoveStrategy`, `BlueMoveStrategy`（复用 `BlueMarbleHelper`）等
  - [x] `white_marble.gd` 去掉 `match color`，在 `change_color()` 时 `current_strategy = strategies[new_color]`
  - [x] 保持向后兼容（已有测试仍然通过）

**Step 2**（无依赖，立刻开始）：
- [x] **同时死亡结算算法**
  - [x] 纯函数：`resolve_simultaneous_deaths(death_events, white_marbles) - [ ]> Array[ColorChangeEvent]`
  - [x] 按阵营分组 → 每组找未变色的白球 → 变色（每个死亡事件对应一个变色）
  - [x] 写独立的单元测试

**Step 3**（等 B、C 完成各自模块）：
- [x] **跨球集成测试**
  - [x] 黄球+蓝球（`set_follower_safe` 增益）
  - [x] 黄球+绿球（`push_range` 增益）
  - [x] 黄球+红球（`max_steps` 增益）
  - [x] 白球变色后每色移动行为验证
- [x] **端到端游戏流程测试**
  - [x] 创建 GameManager → 初始化棋盘 → 选择→方向→力度→移动→回合切换→胜负

**输出产物**：
- [ ] 重构 `white_marble.gd`
- [x] 新增 `MoveStrategy.gd`（或类似文件）
- [ ] 新增死亡结算模块
- [ ] 新增 `tests/test_integration.gd`

**提交流程**
@所有人 
各位游戏制作人好！
提交通道开放时间：我们会将于5.22号（今天）晚20:00开放作品提交通道，截止提交时间为==5.26号 24:00；==
提交网站：https://leihuo.163.com/gamejam-PKU-CAA/index.html#/
提交内容：


![[ac3f5c3c89f3c6d4e840f74decf5d0c5.jpg]]
作品名称：六方对弈：弹珠碰撞战
作品简介：利用不同技能的弹珠配合战斗！
作品介绍：《六色弹珠：六边形碰撞战》是一款策略对战游戏。在六边形棋盘上，操控六种特性迥异的弹珠，利用弹性碰撞将对手击出边界。从白球的变形继承，到蓝球的随从战术，每步决策都充满变数。选珠布阵，碰撞制胜！
作品类型：策略模拟
策划案上传：game_rule+task_allocation
图片上传：截图
视频：无
试玩安装包：[ ] 制作一个可执行文件（exe/app） 周锦添 今天晚上没有问题的话今天晚上完成，否则明天中午12：00以前完成
游戏技术文件：全游戏压缩包
是否愿意参加线下游戏展：是
# 二、此次例会任务

1. 帮助sorry完成更新内容的上传，A部分验收。
2. 检验蓝球绿球功能，B部分验收。
3. C在A的基础上完成剩余黄球黑球部分UI，C部分验收。
4. D部分AI代码是否引入？如果引入的话，让AI动得慢一些。
5. 全体改bug，优化。
6. 完善策划案。
7. 致谢文档（会被我们加到github主页上&游戏文档之中，如果有时间的话就写一个）
8. 开发者姓名栏是否写真实姓名

# 三、关于后续

开源项目、可以用于大作业的提交，被MIT license保护。**作者把代码公开，别人可以用、改、卖，只要保留原作者的版权声明就行**。

感谢大家！