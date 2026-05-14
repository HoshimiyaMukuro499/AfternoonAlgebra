# test_runner.gd
# 测试运行器主控脚本
# 挂载到测试场景的根节点，自动运行所有测试并输出报告
extends Node2D

var _tests: Array[Dictionary] = []
var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("\n========== 开始运行测试 ==========\n")
	
	# 注册所有测试模块
	_register_tests(TestHexGrid.new())
	_register_tests(TestMarble.new())
	_register_tests(TestBlueMarble.new())
	_register_tests(TestWhiteMarble.new())
	_register_tests(TestGameManager.new())
	
	# 执行所有测试
	_run_all_tests()
	
	# 输出测试报告
	_print_report()

func _register_tests(instance: BaseTest) -> void:
	var script = instance.get_script()
	var name = "Unknown"
	if script and script.resource_path:
		name = script.resource_path.get_file()
	_tests.append({"instance": instance, "name": name})

func _run_all_tests() -> void:
	for test_module in _tests:
		var instance = test_module["instance"]
		var module_name = test_module["name"]
		print("\n--- [%s] ---" % module_name)
		
		if instance.has_method("before_all"):
			instance.before_all()
		
		var methods = instance.get_script().get_script_method_list()
		for method in methods:
			var method_name = method["name"]
			if method_name.begins_with("test_"):
				_run_single_test(instance, method_name)
		
		if instance.has_method("after_all"):
			instance.after_all()

func _run_single_test(instance: BaseTest, method_name: String) -> void:
	if instance.has_method("before_each"):
		instance.before_each()
	
	# 清除之前的失败状态
	instance._clear_failures()
	
	# 调用测试方法
	instance.call(method_name)
	
	# 检查是否有断言失败
	var has_fail = instance._has_failures()
	var error_msg = instance._get_last_failure()
	instance._clear_failures()
	
	if not has_fail:
		_passed += 1
		print("  [PASS] %s" % method_name)
	else:
		_failed += 1
		print("  [FAIL] %s -> %s" % [method_name, error_msg])
	
	if instance.has_method("after_each"):
		instance.after_each()

func _print_report() -> void:
	print("\n========== 测试报告 ==========")
	print("通过: %d" % _passed)
	print("失败: %d" % _failed)
	print("总计: %d" % (_passed + _failed))
	if _failed == 0:
		print("全部通过!")
	else:
		print("存在失败的测试，请检查上方日志。")
	print("==============================\n")
