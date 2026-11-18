## 把 build_kit 的樣板裝進專案（tools/install.gd 呼叫它）：已經存在的檔案不覆蓋（force 才覆蓋），.gitignore 補上建置輸出。
class_name BuildInstaller
extends RefCounted

const TEMPLATES: String = "res://addons/build_kit/templates/"
## 樣板 → 專案裡的位置
const COPIES: Dictionary = {
	"build.ps1": "build.ps1",
	"ci.yml": ".github/workflows/build_kit.yml",
	"setup-godot.yml": ".github/actions/setup-godot/action.yml",
	"build.cfg": "build.cfg",
}
const GITIGNORE_LINES: PackedStringArray = ["/build/", "addons/build_kit/build_info.gen.tres*"]


## root：專案資料夾（絕對路徑）。回傳做了什麼（一行一件）。
static func install(root: String, project_name: String, godot_version: String, force: bool = false) -> PackedStringArray:
	var done: PackedStringArray = PackedStringArray()
	for template: String in COPIES:
		var target: String = root.path_join(COPIES[template])
		if FileAccess.file_exists(target) and not force:
			done.append("略過（已經存在）：%s" % COPIES[template])
			continue
		var text: String = FileAccess.get_file_as_string(TEMPLATES + template)
		if template == "build.cfg":
			text = text.replace("{name}", file_name(project_name)).replace("{godot_version}", godot_version)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			done.append("寫不進：%s（%s）" % [COPIES[template], error_string(FileAccess.get_open_error())])
			continue
		file.store_string(text)
		file.close()
		done.append("寫入：%s" % COPIES[template])
	var added: PackedStringArray = _extend_gitignore(root.path_join(".gitignore"))
	if not added.is_empty():
		done.append(".gitignore 加上：%s" % ", ".join(added))
	return done


## 正在跑的 Godot 在 godot-builds 的版本名稱：4.8-dev6、4.8-stable、4.8.1-rc2。
## 放在這裡（而不是 BuildConfig）：這個檔案不引用任何 class_name，剛複製進來、還沒匯入的專案也能用。
static func running_godot_version() -> String:
	var info: Dictionary = Engine.get_version_info()
	var number: String = "%d.%d" % [info["major"], info["minor"]]
	if int(info["patch"]) > 0:
		number += ".%d" % info["patch"]
	return "%s-%s" % [number, info["status"]]


## 專案名稱 → 檔名（去掉空白與不能當檔名的字）。
static func file_name(project_name: String) -> String:
	var cleaned: String = ""
	for character: String in project_name:
		if character != " " and character.is_valid_filename():
			cleaned += character
	return cleaned if not cleaned.is_empty() else "Game"


static func _extend_gitignore(path: String) -> PackedStringArray:
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	var added: PackedStringArray = PackedStringArray()
	for line: String in GITIGNORE_LINES:
		if not lines.has(line):
			added.append(line)
	if added.is_empty():
		return added
	if not text.is_empty() and not text.ends_with("\n"):
		text += "\n"
	text += "\n# build_kit\n" + "\n".join(added) + "\n"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	return added
