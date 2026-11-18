## 建置的命令列入口（本機 build.ps1 與 CI 都呼叫它）：
##   godot --headless --path . -s res://addons/build_kit/tools/build.gd -- [選項]
## 選項：
##   --target=web|windows|all   只建某個平台（預設 build.cfg 的 targets）
##   --skip-tests               不跑測試
##   --tests-only               只跑測試（CI 的測試步驟）
##   --check                    只檢查 build.cfg、export_presets.cfg、Godot 版本
##   --debug                    匯出 debug 版（輸出資料夾加 -debug）
## 結束代碼：0 成功，1 失敗，2 參數錯誤。在 CI 時把結果寫進 $GITHUB_OUTPUT。
extends SceneTree


func _initialize() -> void:
	var config: BuildConfig = BuildConfig.load_from()
	var targets: PackedStringArray = PackedStringArray()
	var mode: String = "build"
	var debug: bool = false
	var run_tests: bool = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--target="):
			var target: String = arg.trim_prefix("--target=")
			targets = PackedStringArray() if target == "all" else PackedStringArray([target])
		elif arg == "--skip-tests":
			run_tests = false
		elif arg == "--tests-only":
			mode = "test"
		elif arg == "--check":
			mode = "check"
		elif arg == "--debug":
			debug = true
		else:
			printerr("[build_kit] 不認得的選項：%s" % arg)
			quit(2)
			return
	var pipeline := BuildPipeline.new(config)
	var result: BuildPipeline.Result
	match mode:
		"check":
			result = pipeline.check(targets)
		"test":
			result = pipeline.test()
		_:
			result = pipeline.build(targets, debug, run_tests)
	_write_github_output(result)
	quit(0 if result.ok else 1)


func _write_github_output(result: BuildPipeline.Result) -> void:
	var path: String = OS.get_environment("GITHUB_OUTPUT")
	if path.is_empty() or result.outputs.is_empty():
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("[build_kit] 寫不進 GITHUB_OUTPUT：%s" % path)
		return
	file.seek_end()
	file.store_string(result.github_output())
	file.close()
