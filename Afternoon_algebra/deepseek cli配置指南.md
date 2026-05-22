这份文档将指导你从零开始，在 Windows 环境下使用 **DeepSeek API** 配置并高效使用 **Aider**。

---

# 🚀 Aider + DeepSeek 配置与使用全指南

## 一、 环境准备 (确保基础工具已就绪)
在安装 Aider 之前，请确保你的系统中安装了：
1. **Python 3.10+**: [下载地址](https://www.python.org/)（安装时务必勾选 "Add Python to PATH"）。
2. **Git**: [下载地址](https://git-scm.com/)（Aider 强依赖 Git 来记录代码修改）。

---

## 二、 安装 Aider
由于你在 Windows 上之前遇到了兼容性报错，建议使用以下最稳妥的命令：

```powershell
# 1. 先升级基础构建工具
python -m pip install --upgrade pip setuptools wheel

# 2. 安装 Aider
pip install aider-chat
```

**如果 `pip` 依然报错**，请使用 `uv`（目前最快的 Python 包管理器，能自动解决冲突）：
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
# 安装后重启终端，运行：
uv tool install aider-chat --python 3.12
```

---

## 三、 配置 DeepSeek API Key (永久设置)
为了避免每次打开终端都要重新输入 Key，建议直接将其存入系统环境变量。

1. 在 PowerShell 中运行（替换为你的真实 Key）：
   ```powershell
   [System.Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", "你的_DEEPSEEK_API_KEY", "User")
   ```
2. **重启 VS Code 或 PowerShell 窗口**，让设置生效。

---

## 四、 启动 Aider
进入你的项目文件夹（例如 `AfternoonAlgebra`），在终端输入：

```powershell
# 使用 DeepSeek V3 模型 (反应快，适合常规修改)
aider --model deepseek/deepseek-chat

# 或者：使用 DeepSeek R1 模型 (适合解决复杂的逻辑 Bug，思考时间较长)
aider --model deepseek/deepseek-reasoner
```

---

## 五、 核心操作流程 (基础操作)

进入 Aider 界面后，你会看到一个 `>` 提示符，这是你与 AI 沟通的地方。

### 1. 添加文件 (关键)
AI 默认看不见你的代码。你必须告诉它要修改哪些文件。
*   ` /add path/to/file.gd ` —— 添加单个文件。
*   使用 **Tab 键** 可以自动补全路径。

### 2. 下达指令
直接用自然语言描述你的需求：
*   “帮我把这个文件里的坐标计算逻辑从直角坐标改为六边形轴向坐标。”
*   “运行报错了：[粘贴报错内容]，请修复它。”

### 3. 确认修改
*   Aider 会显示 `SEARCH/REPLACE` 代码块。
*   它会**自动修改**你的磁盘文件。
*   它会**自动提交**一个 Git Commit（如果你项目里有 Git）。

### 4. 常用管理指令
*   `/ls`：查看当前 AI “看着”哪些文件。
*   `/drop 文件名`：让 AI 忘掉某个文件，节省 Token。
*   `/undo`：撤销 AI 上一次的代码修改。
*   `/clear`：清空聊天历史（如果 Token 占用太高，请执行此操作）。
*   `/exit`：退出 Aider。

---

## 六、 进阶技巧 (针对你的项目)

### 1. 节省 Token 的最佳实践
你的项目有很多 Godot 生成的非代码文件。建议在项目根目录创建一个 `.aiderignore` 文件，内容如下：
```text
*.uid
*.import
*.tscn
*.svg
*.png
.obsidian/
.vscode/
```
这样 Aider 在扫描项目时会跳过这些大型非代码文件。

### 2. 限制上下文窗口
如果项目文件很多，启动时可以加上限制，防止 DeepSeek 报错：
```powershell
aider --model deepseek/deepseek-chat --map-tokens 1024 --max-chat-history-tokens 2000
```
（这里可以多一些，具体多少可以问问AI）
### 3. 多人协作注意事项
*   **并发限制**：如果多人共用一个 API Key，避免同时在大项目上运行 Aider，否则会触发 DeepSeek 的速率限制（Rate Limit）。
*   **安全性**：永远不要把你的 API Key 直接写在代码里提交到 GitHub。

---

## 七、 故障排查
*   **提示 "DEEPSEEK_API_KEY not set"**：
    运行 `echo $env:DEEPSEEK_API_KEY`。如果没有输出，说明环境变量没生效，请重新运行“第三步”并彻底重启终端。
*   **AI 修改不生效**：
    确保你在 `/add` 时使用的是正确的文件路径。如果路径里有中文或空格，建议用引号包起来。
*   **Token 溢出 (超过 128k)**：
    立刻执行 `/drop` 移除不必要的文件，并执行 `/clear` 清空对话记录。

## 八、配置文件
.aider.conf.yml
```
# ==========================================
# Aider 配置文件 - 针对 DeepSeek & Godot 项目优化
# ==========================================

# 1. 指定模型
model: deepseek/deepseek-chat

# 2. 自动加载的核心逻辑文件 (根据你上次 /ls 的结果)
files:
  - Afternoon_algebra/coding/GameManager.gd
  - Afternoon_algebra/coding/hex_grid_2d.gd
  - Afternoon_algebra/coding/InputHandler.gd
  - Afternoon_algebra/coding/Marble2D.gd

# 3. Token 限制与性能优化
# 限制项目地图大小，防止扫描整个文件夹导致 40w Token 报错
map-tokens: 1024

# 限制聊天历史记录，防止对话变长后变得极贵且反应慢
# 设为 8000 是一个平衡点，既能记住之前的逻辑，又不至于溢出
max-chat-history-tokens: 8000

# 4. 界面与交互
# 建议开启：显示 Token 消耗总额
show-diffs: true
dark-mode: true

# 5. Git 设置
# 自动提交代码修改 (如果你觉得自动 commit 太烦，可以设为 false)
auto-commits: true
# 提交信息前缀
commit-message-prefix: "AI: "

# 6. 忽略建议 (配合 .aiderignore 使用)
# 强制不读取的文件类型
# (虽然可以用 .aiderignore，但在配置里显式禁止更保险)
# no-attribute-author: true
```
.aiderignore
```
# 忽略 Godot 自动生成的元数据
*.uid
*.import
*.tscn
*.svg
*.png
*.zip

# 忽略开发工具配置
.obsidian/
.vscode/
.aider*
```

---

**💡 提示**：Aider 就像一个会写代码的队友，它最擅长“看到问题 -> 修复代码 -> 提交 Git”的循环。保持 `/add` 的文件尽量精简（只添加相关的逻辑文件），它的表现会非常惊艳。