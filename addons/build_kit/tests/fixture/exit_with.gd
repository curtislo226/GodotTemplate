## build_kit 測試用：以第一個參數當結束代碼；"env:NAME" = 用環境變數 NAME 的值（測 [test_env]）。
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var value: String = args[0] if not args.is_empty() else "0"
	if value.begins_with("env:"):
		value = OS.get_environment(value.trim_prefix("env:"))
	quit(value.to_int())
