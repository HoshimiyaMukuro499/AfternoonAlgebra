```bash


D:\文件\AfternoonAlgebra>git checkout main
Already on 'main'
Your branch is up to date with 'origin/main'.

D:\文件\AfternoonAlgebra>git pull
Already up to date.

D:\文件\AfternoonAlgebra>git checkout -b feature/C
Switched to a new branch 'feature/C'

D:\文件\AfternoonAlgebra>git status
On branch feature/C
nothing to commit, working tree clean

D:\文件\AfternoonAlgebra>git add .

D:\文件\AfternoonAlgebra>git push
fatal: The current branch feature/C has no upstream branch.
To push the current branch and set the remote as upstream, use

    git push --set-upstream origin feature/C

To have this happen automatically for branches without a tracking
upstream, see 'push.autoSetupRemote' in 'git help config'.


D:\文件\AfternoonAlgebra>git commit -m "创建新的分支"
On branch feature/C
nothing to commit, working tree clean

D:\文件\AfternoonAlgebra>git push
fatal: The current branch feature/C has no upstream branch.
To push the current branch and set the remote as upstream, use

    git push --set-upstream origin feature/C

To have this happen automatically for branches without a tracking
upstream, see 'push.autoSetupRemote' in 'git help config'.


D:\文件\AfternoonAlgebra>git push --set-upstream origin feature/C
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
remote:
remote: Create a pull request for 'feature/C' on GitHub by visiting:
remote:      https://github.com/HoshimiyaMukuro499/AfternoonAlgebra/pull/new/feature/C
remote:
To https://github.com/HoshimiyaMukuro499/AfternoonAlgebra
 * [new branch]      feature/C -> feature/C
branch 'feature/C' set up to track 'origin/feature/C'.

D:\文件\AfternoonAlgebra>git push
Everything up-to-date
```