
为了进行版本控制，我们使用GitHub来进行版本的控制与维护。
# GitHub 团队协作指南（Windows 命令行版）

## 一、安装与配置（一次性）

### 1. 安装 Git
- 下载：https://git-scm.com/download/win
- 安装时一路 **Next**，唯一要注意：**选择 "Git from the command line and also from 3rd-party software"**（我在下载的时候并没有遇到这个问题）

### 2. 配置身份（让 GitHub 知道是谁提交的）
打开 **Git Bash**（右键桌面 → Git Bash Here），输入：

```bash
git config --global user.name "你的真实姓名或昵称"
git config --global user.email "你登录GitHub的邮箱"
```

### 3. 克隆仓库（下载项目到电脑）
在你想放项目的位置（比如 `D:\`）右键 → **Git Bash Here**，然后：

```bash
git clone https://github.com/HoshimiyaMukuro499/Zodiac
```

> 如果提示 `fatal: Authentication failed`，说明需要登录。按提示在弹窗中输入 GitHub 账号密码（密码要用 Personal Access Token，见附录）。

克隆完成后，进入项目目录：

```bash
cd Afternoon_algebra
```

---

## 二、记住这 6 条命令就够了

| 命令 | 作用 | 什么时候用 |
|------|------|-----------|
| `git pull` | 拉取最新代码 | 每天开始工作前 |
| `git status` | 查看当前改动了哪些文件 | 提交前看一眼 |
| `git add .` | 把所有改动加入"暂存区" | 准备提交时 |
| `git commit -m "说明"` | 提交到本地仓库（存档） | 改完一小段功能后 |
| `git push` | 上传到 GitHub | commit 之后 |
| `git checkout -b 分支名` | 创建并切换到新分支（仅首次PR需要） | 首次准备发 PR 时 |

---

## 三、日常工作流程（分步图解）

### 第1步：开始工作前 → 拉取最新

```bash
git pull
```

> 如果提示 `Already up to date`，说明已经是最新。

### 第2步：修改文件

正常用编辑器（VS Code、记事本等）修改脚本、增删文件、调整文件夹结构。**完全正常操作，不需要额外命令**。

### 第3步：查看改了哪些内容

```bash
git status
```

输出示例：
```
Changes not staged for commit:
  modified:   scripts/player.lua
  deleted:    deprecated/old.txt
Untracked files:
  new_feature/monster.lua
```

**解释**：
- `modified` = 修改过的文件
- `deleted` = 删除的文件
- `Untracked` = 新增的文件（Git 还没跟踪过）

### 第4步：提交到本地（存档）

```bash
git add .
git commit -m "描述清楚你改了啥"
```

`git add .` 的意思是"所有改动都加入本次提交"。

**提交信息示例**：
- `git commit -m "调整文件结构：将 NPC 脚本移到 npc/ 目录"`
- `git commit -m "新增三个技能脚本"`
- `git commit -m "修复传送门坐标错误"`

> ⚠️ 不要写 `update`、`fix`、`111` 这种看不懂的信息。

### 第5步：推送到 GitHub

```bash
git push
```

如果出现提示说 `fatal: The current branch has no upstream branch`，说明这是你第一次推送某个分支，按提示复制它给的命令即可（通常是 `git push --set-upstream origin 分支名`）。

---

## 四、发 Pull Request（最重要的一步）

普通成员**不能直接推送到 main 分支**，需要通过 PR 让维护者审查。

### 标准流程（只在第一次需要手动创建分支）

#### 第一次发 PR（或每次新功能开始时）：
```bash
# 确保 main 是最新的
git checkout main
git pull

# 创建一个新分支（分支名随便起，如 feature/添加跳跃功能）我觉得可以写成feature/人名
git checkout -b feature/玩家技能

# 然后正常修改、提交、推送（见上面的步骤2-5）
# 推送时会提示 upstream 命令，复制粘贴执行即可
```

#### 之后修改同一个功能时：
直接在同一个分支上继续 `git add/commit/push` 即可，PR 会自动更新。

#### 创建 PR（网页操作）：
1. 浏览器打开仓库页面
2. 点击 **Pull requests** 标签 → **New pull request**
3. base 选 `main`，compare 选你刚才创建的分支（如 `feature/玩家技能`）
4. 点击 **Create pull request**
5. 标题写清楚（如：`添加玩家二段跳技能`），正文可以留空或写测试说明
6. 点击 **Create pull request** 完成

#### PR 提交后：
- 等待维护者审查
- 如果需要修改：继续改文件 → `git add/commit/push`（同一分支），PR 会自动更新
- 维护者合并后，你的改动就正式生效了

### 以后每次做新功能，重复上面流程：
```bash
git checkout main
git pull
git checkout -b 新功能名
# ...修改、提交、推送...
# 网页上发 PR
```

> 💡 如果你只是想改一个极小的东西（比如修一个错别字），也可以直接在 main 分支上改、提交、推送，然后私聊维护者让他帮你合并（但不推荐养成习惯）。

---

## 五、常见场景命令

### 场景1：新增了多个文件
```bash
git status          # 确认所有新文件都显示为 Untracked
git add .
git commit -m "新增怪物 AI 脚本和配置文件"
git push
```

### 场景2：删除了文件
直接用资源管理器删，然后：
```bash
git add .           # Git 会自动发现文件被删了
git commit -m "删除过时的 debug 脚本"
git push
```

### 场景3：移动/重命名文件
**建议用 `git mv` 命令**（比手动移动更可靠）：
```bash
git mv scripts/old_ai.lua scripts/new_ai.lua
git commit -m "重命名 AI 脚本"
git push
```

如果已经手动移动了：
```bash
git add -A         # -A 会记录重命名和删除
git status         # 检查是否识别为重命名
git commit -m "调整文件夹结构"
git push
```

### 场景4：想放弃某个文件的修改（恢复到最新版）
```bash
git checkout -- 文件名
```
例如：`git checkout -- scripts/player.lua`

### 场景5：commit 后发现有遗漏，想补进去
```bash
git add 遗漏的文件
git commit --amend --no-edit   # 合并到上一个 commit
git push --force              # 注意：需要用 --force 覆盖远程
```
> ⚠️ `--force` 只在你自己还没发 PR、或者 PR 还在 review 时用。如果 PR 已经合并了，就再发一个新的 commit。

### 场景6：拉取时提示冲突（Conflict）
```bash
git pull
# 提示 CONFLICT，例如 scripts/player.lua
```

**解决方法**：
1. 打开冲突文件（VS Code 会高亮冲突区域）
2. 找类似这样的标记：
   ```
   <<<<<<< HEAD
   你之前写的代码
   =======
   别人最新写的代码
   >>>>>>> branch-name
   ```
3. 手动保留正确的代码，删除 `<<<<<<<`、`=======`、`>>>>>>>` 这些标记
4. 保存文件
5. 执行：
   ```bash
   git add .
   git commit -m "解决冲突"
   git push
   ```

> 如果搞不定，直接把终端截图发给维护者，不要硬来。

---

## 六、维护者（我）额外需要做的<font color='red'>家人们注册完github账号记得发我用户名/注册账号，然后我邀请你</font>

### 1. 把组员加入仓库
GitHub 仓库 → Settings → Collaborators → Add people

### 2. 保护 main 分支（防止误推送）
GitHub 仓库 → Settings → Branches → Add rule
- Branch name pattern: `main`
- ✅ Require a pull request before merging
- ✅ Require approvals (1 人)
- 点击 Create

### 3. 日常审查 PR
- 看改动是否合理（文件结构、代码逻辑）
- 点 Conversation → 如果有问题，点 `Add review` → `Request changes`
- 没问题就 `Approve` 然后 `Merge pull request`

### 4. 处理冲突（帮组员解决）
组员搞不定的冲突，让他在群里发截图，你亲自解决或者远程帮他操作。

---

## 七、快速记忆卡片（给组员）

```bash
# 每天第一次开工：
git pull

# 改完一段功能后：
git status          # 看一眼改了什么
git add .           # 全部加入
git commit -m "说明" # 存档
git push            # 上传

# 发 PR 前（第一次做新功能时）：
git checkout main && git pull
git checkout -b 新分支名
# 然后正常改、提交、推送
# 最后去网页点 New pull request
```

---

## 附录：GitHub 密码问题（如果提示登录失败）

GitHub 现在不允许用账号密码直接 push，需要用 **Personal Access Token**：

1. 登录 GitHub → 右上角头像 → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 勾选 `repo` 和 `workflow`，生成
4. 复制那串 token（像 `ghp_xxxxxx`）
5. 当 Git 弹出密码输入框时，**用户名输入你的 GitHub 用户名，密码粘贴这个 token**

或者一行命令配置缓存（避免每次输）：
```bash
git config --global credential.helper wincred
```
