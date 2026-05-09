为了让你更清晰地操作，我们将整个流程分为 **“初次设置”**、**“日常开发”** 和 **“同步原作者更新”** 三个阶段。

以下是完整的 Git 命令清单：

### 第一阶段：初次设置 (准备工作)
*在 GitHub 网页上点击 **Fork** 之后执行以下命令：*

```bash
# 1. 克隆你自己的仓库副本 (注意：URL 是你自己的用户名)
git clone https://github.com/你的用户名/仓库名.git

# 2. 进入项目目录
cd 仓库名

# 3. 关联原作者的仓库（为了以后同步更新，习惯上起名为 upstream）
git remote add upstream https://github.com/原作者/仓库名.git

# 4. 验证远程地址是否正确
# 你会看到 origin (你的) 和 upstream (原作者的)
git remote -v
```

---

### 第二阶段：日常开发 (修改代码)
*永远不要在 main 分支上直接修改，养成开新分支的习惯：*

```bash
# 1. 创建并切换到一个新分支 (比如叫 fix-ui)
git checkout -b fix-ui

# 2. ... 这里去写代码、改文件 ...

# 3. 查看哪些文件被改动了
git status

# 4. 暂存改动
git add .

# 5. 提交改动到本地仓库
git commit -m "修复了界面颜色问题"

# 6. 将新分支推送到你的 GitHub 仓库
git push origin fix-ui
```
*此时，你可以去 GitHub 页面点击 **Compare & pull request** 按钮了。*

---

### 第三阶段：同步原作者更新 (不丢失改动)
*当原作者更新了代码，你想把他的代码合并到你的分支里：*

```bash
# 1. 先切回主分支
git checkout main

# 2. 从原作者仓库拉取最新代码
git fetch upstream

# 3. 合并原作者代码到你的本地 main 分支
# 这会更新你的本地代码，使之与原作者同步
git merge upstream/main

# 4. 如果你想让你正在开发的分支也用上这些新代码：
git checkout fix-ui
git merge main
```
*注意：如果在第 4 步发生了“冲突”，Git 会提示你，你需要手动打开冲突文件修改，然后再次 add 和 commit。*

---

### 常用辅助命令 (救急用)

*   **查看当前在哪个分支：**
    `git branch`
*   **如果不小心改乱了，想放弃本地所有没提交的修改：**
    `git checkout -- .`
*   **查看提交历史：**
    `git log --oneline`
*   **万一发现刚才 commit 的备注写错了，想改备注：**
    `git commit --amend -m "新的正确备注"`

### 总结：你的“三位一体”结构
1.  **本地硬盘：** 你干活的地方。
2.  **Origin (你的 GitHub)：** 你的云端备份，PR 的跳板。
3.  **Upstream (作者 GitHub)：** 代码的源头，你只从这里拉取（fetch/merge），从不推送到这里。

**只要记住这个结构，你的代码就永远是安全的！**