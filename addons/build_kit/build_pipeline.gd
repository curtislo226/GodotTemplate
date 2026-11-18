## 建置：本機（build.ps1）與 CI 跑的是同一段程式。三件事，各回傳一個 Result：
##   check()                          build.cfg、export_presets.cfg、Godot 版本對不對
##   test()                           跑 build.cfg 的測試
##   build(targets, debug, run_tests) 檢查 → 測試 → 版本 → 排除清單 → 建置資訊 → 匯出 → 打包 → 清理舊建置
## 專案 = build.cfg 所在的資料夾；排除清單與 BuildInfo 針對正在執行的專案（實際使用時是同一個）。
## 上一次建置被強制結束留下的髒狀態（改過的 export_presets.cfg、build_info.gen.tres），每次開始時自動還原。
class_name BuildPipeline
extends RefCounted

const EXPECTED: Dictionary = {"web": ["index.html", "index.pck", "index.wasm"]}
const EXPORT_LOG_TAIL: int = 30


## 一次執行的結果。outputs 給 CI：version、version_file、release、dir、<平台>_dir、<平台>_zip、itch_target、itch_<平台>。
class Result:
	var ok: bool = true
	var lines: PackedStringArray = PackedStringArray()
	var outputs: Dictionary = {}

	## $GITHUB_OUTPUT 的格式（key=value，一行一個）
	func github_output() -> String:
		var text: String = ""
		for key: String in outputs:
			var value: Variant = outputs[key]
			text += "%s=%s\n" % [key, str(value).to_lower() if value is bool else str(value)]
		return text


var _config: BuildConfig
var _project: String
var _godot: String = OS.get_executable_path()
var _result: Result


func _init(config: BuildConfig) -> void:
	_config = config
	_project = config.project_dir()


## 設定的問題：build.cfg、export_presets.cfg（存在、有進 git、preset 正確）、正在跑的 Godot 是不是 build.cfg 釘的版本。
func check(targets: PackedStringArray = PackedStringArray()) -> Result:
	_begin()
	_check_into(targets if not targets.is_empty() else _config.targets)
	if _result.ok:
		_say("設定沒有問題")
	return _result


func test() -> Result:
	_begin()
	var problems: PackedStringArray = _config.problems()
	if not problems.is_empty():
		for problem: String in problems:
			_fail("設定問題：" + problem)
		return _result
	_test_into()
	return _result


func build(targets: PackedStringArray = PackedStringArray(), debug: bool = false, run_tests: bool = true) -> Result:
	_begin()
	var wanted: PackedStringArray = targets if not targets.is_empty() else _config.targets
	if not _check_into(wanted):
		return _result
	if run_tests and not _test_into():
		_fail("測試失敗，停止建置（本機可以加 -SkipTests 略過）")
		return _result
	var version: BuildVersion = BuildVersion.from_git(_project)
	_say("版本 %s%s" % [version.text(), "（正式版）" if version.is_release() else ""])
	if version.dirty and not OS.get_environment("GITHUB_ACTIONS").is_empty():
		_say("工作區有沒提交的修改，所以不算正式版：\n" + BuildVersion.git(_project, ["status", "--porcelain", "--untracked-files=no"]))
	var builds_dir: String = _project.path_join("build")
	var out_dir: String = builds_dir.path_join(version.file_text() + ("-debug" if debug else ""))
	if DirAccess.dir_exists_absolute(out_dir):
		BuildPackager.remove_tree(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_touch(builds_dir.path_join(".gdignore"))
	if not _export_all(wanted, version, out_dir, debug) or not _package(wanted, version, out_dir, debug, run_tests):
		return _result
	var removed: PackedStringArray = BuildPackager.prune(builds_dir, _config.keep_builds)
	if not removed.is_empty():
		_say("清掉舊的建置：%s" % ", ".join(removed))
	_say("完成：%s" % out_dir)
	return _result


func _begin() -> void:
	_result = Result.new()
	if BuildPresets.recover(_project):
		_say("上次建置沒有正常結束：已還原 export_presets.cfg")
	var info: String = ProjectSettings.globalize_path(BuildInfo.GENERATED_PATH)
	if FileAccess.file_exists(info):
		DirAccess.remove_absolute(info)
		DirAccess.remove_absolute(info + ".uid")
		_say("上次建置沒有正常結束：已刪除留下的 build_info.gen.tres")


func _check_into(targets: PackedStringArray) -> bool:
	var problems: PackedStringArray = _config.problems()
	for target: String in targets:
		if not BuildConfig.TARGETS.has(target):
			problems.append("不認得的平台「%s」（只支援 %s）" % [target, ", ".join(BuildConfig.TARGETS)])
	if problems.is_empty():
		problems.append_array(BuildPresets.new(_project).problems(_presets_for(targets)))
	var running: String = BuildConfig.running_godot_version()
	if not _config.godot_version.is_empty() and running != _config.godot_version:
		problems.append("正在跑的 Godot 是 %s，build.cfg 釘的是 %s（匯出模板會對不上）" % [running, _config.godot_version])
	if _is_git_repo() and FileAccess.file_exists(_project.path_join(BuildPresets.FILE_NAME)) \
			and BuildVersion.git(_project, ["ls-files", BuildPresets.FILE_NAME]).is_empty():
		# 只警告：剛安裝、還沒 commit 時本機要能先建；CI 那邊沒有這個檔案會直接失敗
		_say("注意：export_presets.cfg 還沒進 git（commit 它；也檢查 .gitignore 有沒有排除它），否則 CI 會找不到")
	for problem: String in problems:
		_fail("設定問題：" + problem)
	return problems.is_empty()


func _test_into() -> bool:
	if _config.test_args.is_empty():
		_say("build.cfg 沒有設定測試（test_args），略過")
		return true
	var args: PackedStringArray = PackedStringArray(["--headless", "--path", _project])
	args.append_array(_config.test_args)
	_say("跑測試：godot %s" % " ".join(_config.test_args))
	for key: String in _config.test_env:
		OS.set_environment(key, _config.test_env[key])
	var output: Array = []
	var code: int = OS.execute(_godot, args, output, true)
	for key: String in _config.test_env:
		OS.unset_environment(key)
	if code == 0:                                    # 通過時不轉印（Windows 上子行程的中文會變亂碼，也太長）
		_say("測試通過")
		return true
	_print_tail(output, 200)
	_fail("測試失敗（結束代碼 %d）" % code)
	return false


## 匯出每個平台。export_presets.cfg 與建置資訊檔在這裡還原／刪除；被強制結束時由下一次的 _begin() 處理。
func _export_all(targets: PackedStringArray, version: BuildVersion, out_dir: String, debug: bool) -> bool:
	var excluded: PackedStringArray = BuildExclusions.new(_config).compute()
	_say("排除 %d 項（固定樣式＋沒用到的素材）" % excluded.size())
	var error: Error = BuildInfo.write(BuildInfo.GENERATED_PATH, {
		"version": version.text(), "commit": version.commit, "release": version.is_release(),
		"date": Time.get_date_string_from_system(true), "godot_version": _config.godot_version,
	})
	if error != OK:
		_fail("寫不進 %s：%s" % [BuildInfo.GENERATED_PATH, error_string(error)])
		return false
	var presets := BuildPresets.new(_project)
	error = presets.apply(_presets_for(targets), excluded, version)
	var ok: bool = error == OK
	if not ok:
		_fail("寫不進 export_presets.cfg：%s" % error_string(error))
	else:
		for target: String in targets:
			ok = _export(target, out_dir, debug) and ok
	error = presets.restore()
	if error != OK:
		_fail("還原 export_presets.cfg 失敗（%s）：請用 git checkout export_presets.cfg" % error_string(error))
		ok = false
	var info: String = ProjectSettings.globalize_path(BuildInfo.GENERATED_PATH)
	DirAccess.remove_absolute(info)
	DirAccess.remove_absolute(info + ".uid")
	return ok


func _export(target: String, out_dir: String, debug: bool) -> bool:
	var dir: String = out_dir.path_join(target)
	DirAccess.make_dir_recursive_absolute(dir)
	var main_file: String = "index.html" if target == "web" else "%s.exe" % _config.name
	var preset: String = _config.presets[target]
	_say("匯出 %s（preset「%s」）" % [target, preset])
	var output: Array = []
	var code: int = OS.execute(_godot, PackedStringArray(["--headless", "--path", _project,
		"--export-debug" if debug else "--export-release", preset, dir.path_join(main_file)]), output, true)
	var missing: PackedStringArray = PackedStringArray()
	for file: Variant in EXPECTED.get(target, [main_file]):
		if not FileAccess.file_exists(dir.path_join(String(file))):
			missing.append(String(file))
	if code != 0 or not missing.is_empty():
		_print_tail(output, EXPORT_LOG_TAIL)
		_fail("%s 匯出失敗（結束代碼 %d%s；匯出模板裝了嗎？上面是 Godot 輸出的最後幾行）"
			% [target, code, "，少了 " + ", ".join(missing) if not missing.is_empty() else ""])
		return false
	_result.outputs["%s_dir" % target] = dir
	return true


func _package(targets: PackedStringArray, version: BuildVersion, out_dir: String, debug: bool, ran_tests: bool) -> bool:
	var extra: Dictionary = {}
	for file: String in _config.bundle:
		var source: String = _project.path_join(file)
		if not FileAccess.file_exists(source):
			_fail("bundle 的檔案不存在：%s" % file)
			return false
		extra[file.get_file()] = source
	for target: String in targets:
		var zip: String = out_dir.path_join("%s-%s-%s.zip" % [_config.name, version.file_text(), target])
		var error: Error = BuildPackager.zip_dir(_result.outputs["%s_dir" % target], zip, extra if target == "windows" else {})
		if error != OK:
			_fail("打包 %s 失敗：%s" % [target, error_string(error)])
			return false
		_result.outputs["%s_zip" % target] = zip
	var info: FileAccess = FileAccess.open(out_dir.path_join("build_info.json"), FileAccess.WRITE)
	if info == null:
		_fail("寫不進 build_info.json：%s" % error_string(FileAccess.get_open_error()))
		return false
	info.store_string(JSON.stringify({
		"name": _config.name, "version": version.text(), "release": version.is_release(), "commit": version.commit,
		"godot_version": _config.godot_version, "targets": targets, "debug": debug,
		"date": Time.get_datetime_string_from_system(true) + "Z", "tests_skipped": not ran_tests,
	}, "  "))
	info.close()
	_result.outputs["version"] = version.text()
	_result.outputs["version_file"] = version.file_text()
	_result.outputs["release"] = version.is_release()
	_result.outputs["dir"] = out_dir
	_result.outputs["itch_target"] = _config.itch_target
	for target: String in targets:
		_result.outputs["itch_%s" % target] = _config.itch_channels.get(target, "")
	return true


func _presets_for(targets: PackedStringArray) -> Dictionary:
	var wanted: Dictionary = {}
	for target: String in targets:
		if _config.presets.has(target):
			wanted[target] = _config.presets[target]
	return wanted


func _is_git_repo() -> bool:
	return not BuildVersion.git(_project, ["rev-parse", "--git-dir"]).is_empty()


func _print_tail(output: Array, count: int) -> void:
	var all: PackedStringArray = PackedStringArray()
	for chunk: Variant in output:
		all.append_array(String(chunk).split("\n"))
	for line: String in all.slice(maxi(0, all.size() - count)):
		if not line.strip_edges().is_empty():
			print("    " + line)


func _touch(path: String) -> void:
	if not FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.close()


func _say(line: String) -> void:
	_result.lines.append(line)
	print("[build_kit] " + line)


func _fail(line: String) -> void:
	_result.ok = false
	_result.lines.append(line)
	printerr("[build_kit] " + line)
	if not OS.get_environment("GITHUB_ACTIONS").is_empty():
		print("::error::" + line.replace("\n", "%0A"))
