# base_test.gd
# 所有测试类的基类，提供断言辅助方法
class_name BaseTest
extends "res://addons/gut/test.gd"

var _failure_count: int = 0
var _last_failure_msg: String = ""

func _has_failures() -> bool:
	return _failure_count > 0

func _get_last_failure() -> String:
	return _last_failure_msg

func _clear_failures() -> void:
	_failure_count = 0
	_last_failure_msg = ""

