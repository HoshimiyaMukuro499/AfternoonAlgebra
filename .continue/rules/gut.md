---
description: 任何时候修改了代码或测试文件，都需要运行 GUT 测试确保没有引入回归
alwaysApply: true
---

每次修改代码或测试文件后，必须运行 GUT 测试确认无回归。使用以下命令运行所有测试：

```
& "D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --headless --path "E:\freshman\spring_term\AfternoonAlgebra\Afternoon_algebra\coding" -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit_on_success=true
```

如果需要指定特定测试前缀（如 test_player），追加 `-gprefix=test_player` 参数。