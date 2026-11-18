## 版本號：git tag 是唯一來源。
##   tag v0.4.2 上、工作區乾淨      → 0.4.2（正式版，is_release）
##   tag 之後 7 個 commit          → 0.4.2-dev.7+a1b2c3d
##   還沒有任何 tag                → 0.0.0-dev.<commit 數>+a1b2c3d
##   工作區有沒提交的修改            → 再加 .dirty（不算正式版）
## windows_file_version 給 exe 的檔案版本（四段數字）：0.4.2.7
class_name BuildVersion
extends RefCounted

var major: int = 0
var minor: int = 0
var patch: int = 0
## tag 之後的 commit 數（沒有 tag 時是全部 commit 數）
var distance: int = 0
var commit: String = ""
var dirty: bool = false
var has_tag: bool = false

static var _describe: RegEx = RegEx.create_from_string(r"^v?(\d+)\.(\d+)(?:\.(\d+))?-(\d+)-g([0-9a-f]+)$")


## git describe --tags --long --match "v[0-9]*" 的輸出 → 版本；沒有 tag 時給 commit 數與短 hash。
static func parse(describe: String, commit_count: int = 0, short_sha: String = "", is_dirty: bool = false) -> BuildVersion:
	var version := BuildVersion.new()
	version.dirty = is_dirty
	var found: RegExMatch = _describe.search(describe.strip_edges())
	if found == null:
		version.distance = commit_count
		version.commit = short_sha
		return version
	version.has_tag = true
	version.major = found.get_string(1).to_int()
	version.minor = found.get_string(2).to_int()
	version.patch = found.get_string(3).to_int()
	version.distance = found.get_string(4).to_int()
	version.commit = found.get_string(5)
	return version


## 讀目前 git 狀態（project_dir 是專案的絕對路徑）。不是 git repo 時是 0.0.0-dev.0。
static func from_git(project_dir: String) -> BuildVersion:
	var describe: String = git(project_dir, ["describe", "--tags", "--long", "--match", "v[0-9]*"])
	var count: int = git(project_dir, ["rev-list", "--count", "HEAD"]).to_int()
	var sha: String = git(project_dir, ["rev-parse", "--short=7", "HEAD"])
	var status: String = git(project_dir, ["status", "--porcelain", "--untracked-files=no"])
	return parse(describe, count, sha, not status.is_empty())


## 打 tag、乾淨的工作區、就在 tag 上 → 正式版。
func is_release() -> bool:
	return has_tag and distance == 0 and not dirty


## 0.4.2、0.4.2-dev.7+a1b2c3d、0.4.2-dev.7+a1b2c3d.dirty
func text() -> String:
	var core: String = "%d.%d.%d" % [major, minor, patch]
	if is_release():
		return core
	var build: String = commit if not commit.is_empty() else "nogit"
	return "%s-dev.%d+%s%s" % [core, distance, build, ".dirty" if dirty else ""]


## 適合當資料夾或檔名的版本（+ 換成 _）。
func file_text() -> String:
	return text().replace("+", "_")


## exe 的檔案版本：四段、每段 0～65535。
func windows_file_version() -> String:
	return "%d.%d.%d.%d" % [mini(major, 65535), mini(minor, 65535), mini(patch, 65535), mini(distance, 65535)]


static func git(project_dir: String, args: PackedStringArray) -> String:
	var output: Array = []
	var full: PackedStringArray = PackedStringArray(["-C", project_dir])
	full.append_array(args)
	if OS.execute("git", full, output, true) != 0:
		return ""
	return String(output[0]).strip_edges() if not output.is_empty() else ""
