## 專案根目錄的 build.cfg：每個專案「不一樣的地方」都在這裡，本機（build.ps1）、CI、build.gd 只讀它。
## 範例見 addons/build_kit/templates/build.cfg。
class_name BuildConfig
extends RefCounted

const PATH: String = "res://build.cfg"
const TARGETS: PackedStringArray = ["web", "windows"]

## 輸出檔名的前綴（ElementPath → ElementPath-0.4.2-windows.zip）
var name: String = ""
## 4.8-dev6、4.8-stable…（下載 Godot 與匯出模板用）
var godot_version: String = ""
## 要建的平台：web、windows
var targets: PackedStringArray = PackedStringArray(["web", "windows"])
## 平台 → export_presets.cfg 裡的 preset 名稱
var presets: Dictionary = {"web": "Web", "windows": "Windows"}
## 跑測試：傳給 Godot 的參數（前面自動加 --headless --path <專案>）；空 = 不跑
var test_args: PackedStringArray = PackedStringArray()
## 跑測試時設定的環境變數（[test_env] 區段，例如 EP_TEST_LANGUAGE="en"）
var test_env: Dictionary = {}
## 一起放進 Windows zip 的檔案（相對專案根目錄）：THIRD_PARTY_LICENSES.txt、CHANGELOG.md…
var bundle: PackedStringArray = PackedStringArray()
## 本機 build/ 保留最近幾次建置
var keep_builds: int = 5
## 匯出時排除（Godot 的 exclude_filter 格式，相對 res://）
var exclude: PackedStringArray = PackedStringArray(["dev/*", "tests/*", "tools/*", "addons/gut/*", "addons/*/tests/*"])
## 這些資料夾裡「沒被出貨內容引用」的檔案也排除（素材包只用到一部分時）
var prune_dirs: PackedStringArray = PackedStringArray()
## 出貨內容的起點（除了主場景、autoload、翻譯、圖示之外）；用來判斷 prune_dirs 裡哪些檔案有被用到
var shipped_dirs: PackedStringArray = PackedStringArray()
## itch.io：user/game；空 = 不上傳
var itch_target: String = ""
## 平台 → itch channel；某個平台的 channel 留空 = 那個平台不上傳
var itch_channels: Dictionary = {"web": "html5", "windows": "windows"}

## build_kit 自己不出貨的部分；一律排除（不從 build.cfg 讀）
var kit_excludes: PackedStringArray = PackedStringArray(["addons/build_kit/tools/*", "addons/build_kit/templates/*", "addons/build_kit/tests/*"])

var path: String = ""
var _load_error: String = ""


static func load_from(cfg_path: String = PATH) -> BuildConfig:
	var config := BuildConfig.new()
	config.path = cfg_path
	var file := ConfigFile.new()
	var error: Error = file.load(cfg_path)
	if error != OK:
		config._load_error = "讀不到 %s（%s）" % [cfg_path, error_string(error)]
		return config
	config.name = String(file.get_value("build", "name", ""))
	config.godot_version = String(file.get_value("build", "godot_version", ""))
	config.targets = PackedStringArray(file.get_value("build", "targets", config.targets))
	config.test_args = PackedStringArray(file.get_value("build", "test_args", config.test_args))
	config.bundle = PackedStringArray(file.get_value("build", "bundle", config.bundle))
	config.keep_builds = int(file.get_value("build", "keep_builds", config.keep_builds))
	for target: String in TARGETS:
		config.presets[target] = String(file.get_value("presets", target, config.presets[target]))
		config.itch_channels[target] = String(file.get_value("itch", target, config.itch_channels[target]))
	config.exclude = PackedStringArray(file.get_value("export", "exclude", config.exclude))
	config.prune_dirs = _res_dirs(PackedStringArray(file.get_value("export", "prune_dirs", config.prune_dirs)))
	config.shipped_dirs = _res_dirs(PackedStringArray(file.get_value("export", "shipped_dirs", config.shipped_dirs)))
	config.itch_target = String(file.get_value("itch", "target", ""))
	if file.has_section("test_env"):
		for key: String in file.get_section_keys("test_env"):
			config.test_env[key] = str(file.get_value("test_env", key))
	return config


## "assets/"、"assets"、"res://assets/" 都變成 "res://assets"（相對路徑一律從專案根目錄算，不靠工作目錄）。
static func _res_dirs(dirs: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for dir: String in dirs:
		var cleaned: String = dir.strip_edges().trim_prefix("res://").trim_prefix("/").trim_suffix("/")
		if not cleaned.is_empty():
			found.append("res://" + cleaned)
	return found


## 正在跑的 Godot 在 godot-builds 的版本名稱：4.8-dev6、4.8-stable、4.8.1-rc2（和 godot_version 同格式）。
static func running_godot_version() -> String:
	return BuildInstaller.running_godot_version()


## 專案資料夾（build.cfg 所在的資料夾，絕對路徑）。export_presets.cfg、git、測試、build/ 都以它為準。
## 排除清單與 BuildInfo 一律針對「正在執行的專案」，實際使用時兩者相同。
func project_dir() -> String:
	return ProjectSettings.globalize_path(path).get_base_dir()


## 設定的問題（空 = 可以用）。
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not _load_error.is_empty():
		found.append(_load_error)
		return found
	if name.is_empty():
		found.append("[build] name 沒有填")
	elif not name.is_valid_filename() or name.contains(" "):
		found.append("[build] name「%s」不能當檔名（不要有空白或 / \\ : * ? \" < > |）" % name)
	if not RegEx.create_from_string(r"^\d+\.\d+(\.\d+)?-(stable|dev\d+|beta\d+|rc\d+)$").search(godot_version):
		found.append("[build] godot_version「%s」格式不對（例：4.8-dev6、4.8-stable、4.8.1-rc2）" % godot_version)
	if targets.is_empty():
		found.append("[build] targets 是空的")
	for target: String in targets:
		if not TARGETS.has(target):
			found.append("[build] targets 有不認得的平台「%s」（只支援 %s）" % [target, ", ".join(TARGETS)])
	if keep_builds < 1:
		found.append("[build] keep_builds 至少要 1")
	if not itch_target.is_empty() and not RegEx.create_from_string(r"^[\w-]+/[\w-]+$").search(itch_target):
		found.append("[itch] target「%s」格式不對（例：curtislo226/kings-ball）" % itch_target)
	return found


## 匯出要排除的固定樣式（設定的 exclude 加上 build_kit 自己的工具）。
func fixed_excludes() -> PackedStringArray:
	var found: PackedStringArray = exclude.duplicate()
	for pattern: String in kit_excludes:
		if not found.has(pattern):
			found.append(pattern)
	return found
