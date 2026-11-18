## 執行：godot --headless --path . -s res://addons/build_kit/tests/build_kit_tests.gd
## 不真的匯出（那要匯出模板、幾十秒）；真的建置用 ./build.ps1 驗證。只在 user://build_kit_tests/ 讀寫。
extends SceneTree

const DIR: String = "user://build_kit_tests/"
const FIXTURE: String = "res://addons/build_kit/tests/fixture/"
const PRESETS: String = """[preset.0]

name="Web"
platform="Web"
exclude_filter=""

[preset.0.options]

variant/thread_support=false
variant/extensions_support=false

[preset.1]

name="Windows"
platform="Windows Desktop"
exclude_filter=""

[preset.1.options]

application/file_version=""
application/product_version=""
"""

var _fail: int = 0
var _n: int = 0
var _dir: String = ""


func _check(cond: bool, what: String) -> void:
	_n += 1
	if not cond:
		_fail += 1
	print("  %s %s" % ["ok  " if cond else "FAIL", what])


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_dir = ProjectSettings.globalize_path(DIR)
	_test_version()
	_test_config()
	_test_exclusions()
	_test_presets()
	_test_packager()
	_test_info()
	_test_installer()
	_test_pipeline()
	BuildPackager.remove_tree(_dir)
	print("\n%d / %d 通過" % [_n - _fail, _n])
	quit(1 if _fail > 0 else 0)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## 在 user://build_kit_tests/ 放一份 build.cfg（從樣板，填名稱與目前的 Godot 版本），可以覆寫某幾行。
func _config(overrides: Dictionary = {}) -> BuildConfig:
	var text: String = FileAccess.get_file_as_string("res://addons/build_kit/templates/build.cfg")
	text = text.replace("{name}", "Demo").replace("{godot_version}", BuildConfig.running_godot_version())
	for key: String in overrides:
		text = RegEx.create_from_string("(?m)^%s=.*$" % key).sub(text, "%s=%s" % [key, overrides[key]])
	_write(_dir.path_join("build.cfg"), text)
	return BuildConfig.load_from(_dir.path_join("build.cfg"))


func _test_version() -> void:
	print("[BuildVersion]")
	var release: BuildVersion = BuildVersion.parse("v0.4.2-0-ga1b2c3d")
	_check(release.is_release() and release.text() == "0.4.2", "就在 tag 上 → 正式版 0.4.2")
	var dev: BuildVersion = BuildVersion.parse("v0.4.2-7-ga1b2c3d")
	_check(not dev.is_release() and dev.text() == "0.4.2-dev.7+a1b2c3d", "tag 之後 7 個 commit → 0.4.2-dev.7+a1b2c3d")
	_check(dev.windows_file_version() == "0.4.2.7" and dev.file_text() == "0.4.2-dev.7_a1b2c3d", "exe 檔案版本四段、檔名把 + 換掉")
	var dirty: BuildVersion = BuildVersion.parse("v1.0-0-gabcdef0", 0, "", true)
	_check(not dirty.is_release() and dirty.text() == "1.0.0-dev.0+abcdef0.dirty", "tag 上但有沒提交的修改 → 不是正式版、標 .dirty")
	var none: BuildVersion = BuildVersion.parse("", 42, "1234567")
	_check(not none.has_tag and none.text() == "0.0.0-dev.42+1234567", "沒有 tag → 0.0.0-dev.<commit 數>+hash")
	_check(BuildVersion.parse("fatal: not a git repository").text() == "0.0.0-dev.0+nogit", "不是 git repo 也有版本，不會當掉")
	var here: BuildVersion = BuildVersion.from_git(ProjectSettings.globalize_path("res://"))
	_check(here.commit.length() == 7, "讀這個 repo 的 git：%s" % here.text())


func _test_config() -> void:
	print("[BuildConfig]")
	var config: BuildConfig = _config()
	_check(config.problems().is_empty(), "樣板填好名稱與版本就沒有問題：%s" % config.problems())
	_check(config.name == "Demo" and config.targets == PackedStringArray(["web", "windows"]) and config.presets["windows"] == "Windows",
		"讀到名稱、平台、preset 名稱")
	_check(config.project_dir() == _dir.trim_suffix("/"), "專案資料夾 = build.cfg 所在的資料夾")
	var all: String = "\n".join(_config({"name": "\"My Game\"", "godot_version": "\"4.8\"", "targets": "PackedStringArray(\"web\", \"mac\")",
		"target": "\"no slash\""}).problems())
	_check(all.contains("不能當檔名") and all.contains("godot_version") and all.contains("「mac」") and all.contains("[itch]"),
		"名稱有空白、版本格式、不支援的平台、itch 格式都會指出來")
	_check(BuildConfig.load_from(_dir.path_join("nothing.cfg")).problems()[0].contains("讀不到"), "沒有 build.cfg")
	_check(_config({"prune_dirs": "PackedStringArray(\"assets/\", \"res://ui/\", \"/art\")"}).prune_dirs == PackedStringArray(["res://assets", "res://ui", "res://art"]),
		"prune_dirs 寫相對路徑也從專案根目錄算（assets/ → res://assets）")
	_check(config.fixed_excludes().has("addons/build_kit/tools/*") and config.fixed_excludes().has("addons/gut/*"),
		"固定排除：設定的樣式＋build_kit 自己的工具")
	for version: String in ["4.8-stable", "4.8.1-rc2", "4.9-beta3"]:
		_check(_config({"godot_version": "\"%s\"" % version}).problems().is_empty(), "接受 godot_version %s" % version)
	_config()
	var with_env: String = FileAccess.get_file_as_string(_dir.path_join("build.cfg")).replace("[test_env]\n", "[test_env]\n\nLANG_CODE=\"en\"\n")
	_write(_dir.path_join("build.cfg"), with_env)
	_check(BuildConfig.load_from(_dir.path_join("build.cfg")).test_env == {"LANG_CODE": "en"}, "[test_env] 讀成環境變數")


func _test_exclusions() -> void:
	print("[BuildExclusions]")
	var config: BuildConfig = _config()
	config.exclude = PackedStringArray(["dev/*"])
	config.kit_excludes = PackedStringArray()        # fixture 放在 tests/ 底下，平常會被排除
	config.shipped_dirs = PackedStringArray([FIXTURE + "shipped"])
	config.prune_dirs = PackedStringArray([FIXTURE + "assets"])
	var exclusions := BuildExclusions.new(config)
	var excluded: PackedStringArray = exclusions.compute()
	var prefix: String = FIXTURE.trim_prefix("res://")
	_check(exclusions.is_shipped(FIXTURE + "assets/used.tres") and not excluded.has(prefix + "assets/used.tres"), "資源相依找得到的留下")
	_check(not excluded.has(prefix + "assets/literal.txt"), "設定檔裡的 \"res://…\" 字串找得到的留下")
	_check(excluded.has(prefix + "assets/unused.txt") and excluded.has(prefix + "assets/sub/deep.txt"), "沒用到的（含子資料夾）排除")
	_check(not excluded.has(prefix + "assets/hidden/skip.txt"), ".gdignore 的資料夾不看（Godot 本來就不匯出）")
	_check(excluded.has("dev/*"), "固定樣式一定在清單裡")


func _test_presets() -> void:
	print("[BuildPresets]")
	var path: String = _dir.path_join("export_presets.cfg")
	var backup: String = _dir.path_join(BuildPresets.BACKUP)
	_write(path, PRESETS)
	var presets := BuildPresets.new(_dir)
	var wanted: Dictionary = {"web": "Web", "windows": "Windows"}
	_check(presets.platform_of("Windows") == "Windows Desktop" and presets.problems(wanted).is_empty(), "標準的 preset 沒有問題")
	var all: String = "\n".join(presets.problems({"web": "Windows", "windows": "Mac"}))
	_check(all.contains("沒有名為「Mac」") and all.contains("平台是 Windows Desktop"), "找不到 preset、平台不對")
	_write(path, PRESETS.replace("thread_support=false", "thread_support=true").replace("extensions_support=false", "extensions_support=true"))
	all = "\n".join(BuildPresets.new(_dir).problems(wanted))
	_check(all.contains("執行緒") and all.contains("GDExtension"), "Web 開了執行緒或 GDExtension 會指出來（標準是關閉）")
	_write(path, PRESETS)
	presets = BuildPresets.new(_dir)
	presets.apply(wanted, PackedStringArray(["dev/*", "assets/a.png"]), BuildVersion.parse("v1.2.3-4-gabcdef0"))
	var file := ConfigFile.new()
	file.load(path)
	_check(file.get_value("preset.0", "exclude_filter") == "dev/*,assets/a.png" and file.get_value("preset.1", "exclude_filter") == "dev/*,assets/a.png",
		"每個 preset 都寫入排除清單")
	_check(file.get_value("preset.1.options", "application/file_version") == "1.2.3.4" and not file.has_section_key("preset.0.options", "application/file_version"),
		"只有 Windows 寫入檔案版本")
	_check(FileAccess.get_file_as_string(backup) == PRESETS, "寫入前先備份原檔")
	_check(presets.restore() == OK and FileAccess.get_file_as_string(path) == PRESETS and not FileAccess.file_exists(backup),
		"restore：位元組完全相同、刪掉備份")
	presets = BuildPresets.new(_dir)
	presets.apply(wanted, PackedStringArray(["x"]), BuildVersion.parse(""))   # 之後「當掉」：沒有 restore
	_check(BuildPresets.recover(_dir) and FileAccess.get_file_as_string(path) == PRESETS and not FileAccess.file_exists(backup),
		"建置中途被強制結束：下一次 recover() 從備份還原")
	_check(not BuildPresets.recover(_dir), "沒有備份時 recover() 什麼都不做")
	_check(not BuildPresets.new(_dir.path_join("none")).problems(wanted).is_empty(), "沒有 export_presets.cfg")


func _test_packager() -> void:
	print("[BuildPackager]")
	var source: String = _dir.path_join("pack/web")
	_write(source.path_join("index.html"), "<html>")
	_write(source.path_join("sub/a.txt"), "a")
	_write(source.path_join(".hidden"), "h")
	_write(_dir.path_join("LICENSE.txt"), "license")
	var zip: String = _dir.path_join("pack/out.zip")
	_check(BuildPackager.zip_dir(source, zip, {"LICENSE.txt": _dir.path_join("LICENSE.txt")}) == OK, "壓縮成功")
	var reader := ZIPReader.new()
	reader.open(zip)
	var files: PackedStringArray = PackedStringArray(Array(reader.get_files()).filter(func(f: String) -> bool: return not f.ends_with("/")))
	files.sort()
	_check(files == PackedStringArray([".hidden", "LICENSE.txt", "index.html", "sub/a.txt"]) and reader.read_file("sub/a.txt").get_string_from_utf8() == "a",
		"zip 裡有資料夾的檔案（含子資料夾、點開頭的檔案）與額外檔案：%s" % files)
	reader.close()
	_check(BuildPackager.zip_dir(source, zip, {"X": _dir.path_join("missing.txt")}) != OK, "額外檔案不存在時失敗")
	var builds: String = _dir.path_join("builds")
	_write(builds.path_join("ElementPath_20261116_ver0.1_web").path_join("index.html"), "舊流程的輸出")
	for name: String in ["old", "mid", "new"]:
		_write(builds.path_join(name).path_join("build_info.json"), name)
		OS.delay_msec(1100)                              # 修改時間以秒為單位
	_check(BuildPackager.prune(builds, 2) == PackedStringArray(["old"]) and DirAccess.dir_exists_absolute(builds.path_join("new"))
		and DirAccess.dir_exists_absolute(builds.path_join("mid")), "只留最新的 2 次建置")
	_check(DirAccess.dir_exists_absolute(builds.path_join("ElementPath_20261116_ver0.1_web")), "不是 build_kit 建的資料夾（沒有 build_info.json）不碰")


func _test_info() -> void:
	print("[BuildInfo]")
	BuildInfo.refresh(_dir.path_join("nothing.tres"))
	_check(BuildInfo.version() == "dev" and BuildInfo.label() == "dev" and not BuildInfo.is_release(), "沒有建置資訊 → dev")
	var path: String = _dir.path_join("info.tres")
	BuildInfo.write(path, {"version": "0.4.2", "release": true, "commit": "a1b2c3d", "date": "2026-11-18", "godot_version": "4.8-dev6"})
	BuildInfo.refresh(path)
	_check(BuildInfo.label() == "v0.4.2" and BuildInfo.commit() == "a1b2c3d" and BuildInfo.date() == "2026-11-18", "正式版 → v0.4.2")
	BuildInfo.write(path, {"version": "0.4.2-dev.7+a1b2c3d", "release": false})
	BuildInfo.refresh(path)
	_check(BuildInfo.label() == "0.4.2-dev.7+a1b2c3d", "開發版照原樣")
	BuildInfo.refresh()


func _test_installer() -> void:
	print("[BuildInstaller]")
	var root: String = _dir.path_join("new_project")
	DirAccess.make_dir_recursive_absolute(root)
	_write(root.path_join(".gitignore"), ".godot/\r\n/build/\r\n")
	var done: String = "\n".join(BuildInstaller.install(root, "My Game", "4.8-dev6"))
	_check(FileAccess.file_exists(root.path_join(".github/workflows/build_kit.yml")) and FileAccess.file_exists(root.path_join(".github/actions/setup-godot/action.yml"))
		and FileAccess.file_exists(root.path_join("build.ps1")), "寫入 build.ps1、CI workflow、setup-godot action")
	var config: BuildConfig = BuildConfig.load_from(root.path_join("build.cfg"))
	_check(config.name == "MyGame" and config.godot_version == "4.8-dev6", "build.cfg 填好名稱（去掉空白）與 Godot 版本")
	var ignore: String = FileAccess.get_file_as_string(root.path_join(".gitignore"))
	_check(ignore.count("/build/") == 1 and ignore.contains("build_info.gen.tres*") and done.contains("加上"), ".gitignore 補上沒有的行、不重複（CRLF 也認得）")
	_write(root.path_join("build.ps1"), "mine")
	BuildInstaller.install(root, "My Game", "4.8-dev6")
	_check(FileAccess.get_file_as_string(root.path_join("build.ps1")) == "mine", "已經存在的檔案不覆蓋")
	BuildInstaller.install(root, "My Game", "4.8-dev6", true)
	var ps1: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join("build.ps1"))
	_check(FileAccess.get_file_as_string(root.path_join("build.ps1")) != "mine", "force 才覆蓋")
	var ascii: bool = true
	for byte: int in ps1:
		ascii = ascii and byte < 128
	_check(ascii, "build.ps1 只有 ASCII（PowerShell 5.1 才讀得對）")


func _test_pipeline() -> void:
	print("[BuildPipeline]")
	_write(_dir.path_join("export_presets.cfg"), PRESETS)
	var config: BuildConfig = _config()
	var result: BuildPipeline.Result = BuildPipeline.new(config).check()
	_check(result.ok, "check：設定、preset、Godot 版本都對：%s" % result.lines)
	result = BuildPipeline.new(config).check(PackedStringArray(["web", "linux"]))
	_check(not result.ok and "\n".join(result.lines).contains("「linux」"), "check：不認得的平台")
	result = BuildPipeline.new(_config({"godot_version": "\"4.7-stable\""})).check()
	_check(not result.ok and "\n".join(result.lines).contains("4.7-stable"), "check：正在跑的 Godot 和 build.cfg 不同")
	result = BuildPipeline.new(_config({"godot_version": "\"4.7-stable\""})).build()
	_check(not result.ok and not FileAccess.file_exists(_dir.path_join(BuildPresets.BACKUP)), "build：檢查沒過就不動任何檔案")
	config = _config()
	_write(_dir.path_join(BuildPresets.BACKUP), PRESETS)
	_write(_dir.path_join("export_presets.cfg"), PRESETS.replace("exclude_filter=\"\"", "exclude_filter=\"dirty\""))
	result = BuildPipeline.new(config).check()
	_check(FileAccess.get_file_as_string(_dir.path_join("export_presets.cfg")) == PRESETS and "\n".join(result.lines).contains("沒有正常結束"),
		"上次建置被強制結束：開始時自動還原 export_presets.cfg")
	config = BuildConfig.load_from()                 # 測試要在真的 Godot 專案裡跑：用這個專案的 build.cfg，只換測試參數
	config.test_args = PackedStringArray(["-s", FIXTURE + "exit_with.gd", "--", "1"])
	result = BuildPipeline.new(config).test()
	_check(not result.ok and "\n".join(result.lines).contains("測試失敗"), "test：失敗回報")
	config.test_args = PackedStringArray(["-s", FIXTURE + "exit_with.gd", "--", "0"])
	_check(BuildPipeline.new(config).test().ok, "test：通過")
	config.test_args = PackedStringArray(["-s", FIXTURE + "exit_with.gd", "--", "env:LOC_TEST"])
	config.test_env = {"LOC_TEST": "7"}
	_check(not BuildPipeline.new(config).test().ok and OS.get_environment("LOC_TEST").is_empty(), "test：[test_env] 傳給測試（結束代碼 7），之後清掉")
	var outputs := BuildPipeline.Result.new()
	outputs.outputs = {"version": "0.4.2", "release": true, "web_dir": "/b/web", "itch_web": ""}
	_check(outputs.github_output() == "version=0.4.2\nrelease=true\nweb_dir=/b/web\nitch_web=\n", "GITHUB_OUTPUT 的格式（ci.yml 依賴這些 key）")
