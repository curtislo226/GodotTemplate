## 檢查與暫時修改 export_presets.cfg（專案根目錄、進 git 的那份）。
## apply() 先把原檔備份到 build/.export_presets.backup 再寫入；restore() 寫回並刪掉備份。
## 建置中途被強制結束、留下備份時，下一次建置一開始用 recover() 自動還原——不會把改過的檔案當成原本的。
class_name BuildPresets
extends RefCounted

const FILE_NAME: String = "export_presets.cfg"
const BACKUP: String = "build/.export_presets.backup"

var path: String
var _project: String
var _original: String = ""
var _file: ConfigFile = ConfigFile.new()
var _load_error: Error = OK


func _init(project_dir: String) -> void:
	_project = project_dir
	path = project_dir.path_join(FILE_NAME)
	_original = FileAccess.get_file_as_string(path)
	_load_error = _file.parse(_original) if not _original.is_empty() else ERR_FILE_NOT_FOUND


## 上次建置沒有還原（留下備份）時，還原 export_presets.cfg。回傳有沒有還原。
static func recover(project_dir: String) -> bool:
	var backup: String = project_dir.path_join(BACKUP)
	if not FileAccess.file_exists(backup):
		return false
	var file: FileAccess = FileAccess.open(project_dir.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(FileAccess.get_file_as_string(backup))
	file.close()
	DirAccess.remove_absolute(backup)
	return true


## preset 的平台（"Web"、"Windows Desktop"）；沒有這個 preset 時是 ""。
func platform_of(preset: String) -> String:
	var section: String = _section_of(preset)
	return String(_file.get_value(section, "platform", "")) if not section.is_empty() else ""


## 問題（空 = 這些 preset 都可以建）：檔案不存在、找不到 preset、平台不對、Web 開了執行緒或 GDExtension。
func problems(wanted: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if _load_error != OK:
		found.append("找不到或讀不懂 %s（在編輯器的「專案 → 匯出」新增 preset 後會產生；它要進 git）" % FILE_NAME)
		return found
	var expected: Dictionary = {"web": "Web", "windows": "Windows Desktop"}
	for target: String in wanted:
		var preset: String = wanted[target]
		var platform: String = platform_of(preset)
		if platform.is_empty():
			found.append("export_presets.cfg 沒有名為「%s」的 preset（%s 用）" % [preset, target])
		elif platform != expected.get(target, platform):
			found.append("preset「%s」的平台是 %s，%s 應該是 %s" % [preset, platform, target, expected[target]])
		elif target == "web":
			if bool(_option(preset, "variant/thread_support")):
				found.append("Web preset「%s」開了執行緒（thread_support）：itch.io 需要另外設 SharedArrayBuffer，標準是關閉" % preset)
			if bool(_option(preset, "variant/extensions_support")):
				found.append("Web preset「%s」開了 GDExtension 支援：標準是 Web 版不含 GDExtension" % preset)
	return found


## 備份原檔，再寫入每個 preset 的排除清單、Windows preset 的檔案版本與產品版本。
func apply(wanted: Dictionary, exclude_filter: PackedStringArray, version: BuildVersion) -> Error:
	var backup_path: String = _project.path_join(BACKUP)
	DirAccess.make_dir_recursive_absolute(backup_path.get_base_dir())
	var backup: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		return FileAccess.get_open_error()
	backup.store_string(_original)
	backup.close()
	for target: String in wanted:
		var section: String = _section_of(wanted[target])
		if section.is_empty():
			continue
		_file.set_value(section, "exclude_filter", ",".join(exclude_filter))
		if platform_of(wanted[target]) == "Windows Desktop":
			_file.set_value(section + ".options", "application/file_version", version.windows_file_version())
			_file.set_value(section + ".options", "application/product_version", version.windows_file_version())
	return _file.save(path)


## 寫回原本的內容（位元組完全相同）並刪掉備份。
func restore() -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(_original)
	file.close()
	DirAccess.remove_absolute(_project.path_join(BACKUP))
	return OK


func _option(preset: String, key: String) -> Variant:
	var section: String = _section_of(preset)
	return _file.get_value(section + ".options", key, null) if not section.is_empty() else null


func _section_of(preset: String) -> String:
	for section: String in _file.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") and String(_file.get_value(section, "name", "")) == preset:
			return section
	return ""
