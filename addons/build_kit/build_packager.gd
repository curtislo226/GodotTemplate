## 打包與清理（都用作業系統的絕對路徑；build/ 有 .gdignore，不在 Godot 的檔案系統裡）。
class_name BuildPackager
extends RefCounted


## 把資料夾裡的所有檔案（含子資料夾）與額外檔案 {zip 裡的名稱: 絕對路徑} 壓成 zip。
static func zip_dir(dir: String, zip_path: String, extra: Dictionary = {}) -> Error:
	var packer := ZIPPacker.new()
	var error: Error = packer.open(zip_path)
	if error != OK:
		return error
	for relative: String in files_in(dir):
		error = _add(packer, relative, dir.path_join(relative))
		if error != OK:
			packer.close()
			return error
	for inside: String in extra:
		error = _add(packer, inside, String(extra[inside]))
		if error != OK:
			packer.close()
			return error
	return packer.close()


## 資料夾裡所有檔案的相對路徑（排序）。
static func files_in(dir: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in _list(dir, false):
		found.append(file)
	for sub: String in _list(dir, true):
		for inside: String in files_in(dir.path_join(sub)):
			found.append(sub.path_join(inside))
	found.sort()
	return found


## builds_dir 底下 build_kit 的建置資料夾只留最新的 keep 個（依修改時間），回傳刪掉的資料夾名稱。
## 只算 build_kit 建出來的資料夾（裡面有 build_info.json）；其他資料夾（舊流程的輸出、自己放的東西）不碰。
static func prune(builds_dir: String, keep: int) -> PackedStringArray:
	var dirs: Array[Dictionary] = []
	for sub: String in _list(builds_dir, true):
		var full: String = builds_dir.path_join(sub)
		if FileAccess.file_exists(full.path_join("build_info.json")):
			dirs.append({"name": sub, "time": _newest_time(full)})
	dirs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["time"]) > int(b["time"]))
	var removed: PackedStringArray = PackedStringArray()
	for index: int in range(keep, dirs.size()):
		var name: String = dirs[index]["name"]
		remove_tree(builds_dir.path_join(name))
		removed.append(name)
	return removed


static func remove_tree(dir: String) -> void:
	for file: String in _list(dir, false):
		DirAccess.remove_absolute(dir.path_join(file))
	for sub: String in _list(dir, true):
		remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## 資料夾裡的檔案或子資料夾，包含點開頭的（Linux 上 DirAccess.get_files_at() 會略過它們）。
static func _list(dir: String, directories: bool) -> PackedStringArray:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return PackedStringArray()
	access.include_hidden = true
	return access.get_directories() if directories else access.get_files()


static func _add(packer: ZIPPacker, inside: String, source: String) -> Error:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
	if bytes.is_empty() and not FileAccess.file_exists(source):
		return ERR_FILE_NOT_FOUND
	var error: Error = packer.start_file(inside)
	if error != OK:
		return error
	error = packer.write_file(bytes)
	packer.close_file()
	return error


static func _newest_time(dir: String) -> int:
	var newest: int = FileAccess.get_modified_time(dir) if FileAccess.file_exists(dir) else 0
	for file: String in DirAccess.get_files_at(dir):
		newest = maxi(newest, FileAccess.get_modified_time(dir.path_join(file)))
	return newest
