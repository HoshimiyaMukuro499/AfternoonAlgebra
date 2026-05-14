# base_test.gd
# 所有测试类的基类，提供断言辅助方法
class_name BaseTest
extends RefCounted

var _failure_count: int = 0
var _last_failure_msg: String = ""

func assert_true(condition: bool, msg: String = "") -> void:
	if not condition:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望为 true，实际为 false"
		push_error("ASSERT FAILED: " + _last_failure_msg)

func assert_false(condition: bool, msg: String = "") -> void:
	if condition:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望为 false，实际为 true"
		push_error("ASSERT FAILED: " + _last_failure_msg)

func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望 %s，实际 %s" % [str(expected), str(actual)]
		push_error("ASSERT FAILED: " + _last_failure_msg)

func assert_ne(actual, expected, msg: String = "") -> void:
	if actual == expected:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望不等于 %s" % str(expected)
		push_error("ASSERT FAILED: " + _last_failure_msg)

func assert_null(value, msg: String = "") -> void:
	if value != null:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望为 null，实际为 %s" % str(value)
		push_error("ASSERT FAILED: " + _last_failure_msg)

func assert_not_null(value, msg: String = "") -> void:
	if value == null:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望非 null"
		push_error("ASSERT FAILED: " + _last_failure_msg)

func assert_almost_eq(actual: float, expected: float, tolerance: float, msg: String = "") -> void:
	if abs(actual - expected) > tolerance:
		_failure_count += 1
		_last_failure_msg = msg if msg != "" else "期望约等于 %f，实际 %f" % [expected, actual]
		push_error("ASSERT FAILED: " + _last_failure_msg)

func fail(msg: String = "") -> void:
	_failure_count += 1
	_last_failure_msg = msg if msg != "" else "测试失败"
	push_error("ASSERT FAILED: " + _last_failure_msg)

func _has_failures() -> bool:
	return _failure_count > 0

func _get_last_failure() -> String:
	return _last_failure_msg

func _clear_failures() -> void:
	_failure_count = 0
	_last_failure_msg = ""
