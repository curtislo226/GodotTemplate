## 匯出時要排除的檔案（Godot 的 exclude_filter）：
##   1. 設定的固定樣式（dev/*、tests/*、addons/gut/*…，加上 build_kit 自己的工具）
##   2. prune_dirs 裡「沒有被出貨內容用到」的檔案
## 「出貨內容」從主場景、autoload、翻譯、圖示與 shipped_dirs 出發，沿著資源相依與程式碼裡的 "res://…" 字串一路找。
## 來源：ElementPath 的 tools/export_exclusions.gd。
class_name BuildExclusions
extends RefCounted

const SKIPPED_EXTENSIONS: PackedStringArray = ["import", "uid"]
const READ_FOR_PATHS: PackedStringArray = ["gd", "tres", "tscn", "gdshader", "gdshaderinc", "cfg"]

var _config: BuildConfig
var _reached: Dictionary = {}
var _waiting: Array[String] = []
var _path_literal: RegEx = RegEx.create_from_string("res://[^\"'\\n)]+")


func _init(config: BuildConfig) -> void:
	_config = config


## 排除清單（相對 res://，可以直接用逗號接起來放進 exclude_filter）。
func compute() -> PackedStringArray:
	_reach_shipped_content()
	var excluded: PackedStringArray = _config.fixed_excludes()
	for dir: String in _config.prune_dirs:
		for file: String in _files_under(dir.trim_suffix("/")):
			if not _reached.has(file) and not is_fixed_excluded(file):
				excluded.append(file.trim_prefix("res://"))
	return excluded


## 出貨內容會用到這個檔案嗎（compute() 之後有效）。
func is_shipped(path: String) -> bool:
	return _reached.has(path)


func is_fixed_excluded(path: String) -> bool:
	var relative: String = path.trim_prefix("res://")
	for pattern: String in _config.fixed_excludes():
		if relative.matchn(pattern):
			return true
	return false


func _reach_shipped_content() -> void:
	if not _reached.is_empty():
		return
	_reach(String(ProjectSettings.get_setting("application/config/icon", "")))
	_reach(String(ProjectSettings.get_setting("application/run/main_scene", "")))
	for property: Dictionary in ProjectSettings.get_property_list():
		if String(property["name"]).begins_with("autoload/"):
			_reach(String(ProjectSettings.get_setting(property["name"])).trim_prefix("*"))
	for path: String in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		_reach(path)
	for dir: String in _config.shipped_dirs:
		for path: String in _files_under(dir.trim_suffix("/")):
			if not is_fixed_excluded(path):
				_reach(path)
	while not _waiting.is_empty():
		var path: String = _waiting.pop_back()
		for dependency: String in ResourceLoader.get_dependencies(path):
			var parts: PackedStringArray = dependency.split("::")
			_reach(parts[parts.size() - 1])
		if READ_FOR_PATHS.has(path.get_extension()):
			for found: RegExMatch in _path_literal.search_all(FileAccess.get_file_as_string(path)):
				_reach(found.get_string())


func _reach(path: String) -> void:
	if path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(path)
		path = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	if path.is_empty() or _reached.has(path):
		return
	if DirAccess.dir_exists_absolute(path):
		_reached[path] = true
		for inside: String in _files_under(path.trim_suffix("/")):
			_reach(inside)
		return
	if not FileAccess.file_exists(path):
		return
	_reached[path] = true
	_waiting.append(path)


static func _files_under(dir: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file: String in DirAccess.get_files_at(dir):
		if not SKIPPED_EXTENSIONS.has(file.get_extension()):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		if not FileAccess.file_exists(dir.path_join(sub).path_join(".gdignore")):
			found.append_array(_files_under(dir.path_join(sub)))
	return found
