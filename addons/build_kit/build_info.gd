## 遊戲裡讀「這是哪一版」：建置時 build_kit 寫入 build_info.gen.tres（不進 git），在編輯器裡直接跑時沒有這個檔，就是 dev。
##   version_label.text = BuildInfo.label()     # "v0.4.2"、"0.4.2-dev.7+a1b2c3d"、"dev"
## 這個檔案跟著遊戲出貨；build_kit 的其他部分（tools/、templates/、tests/）不出貨。
class_name BuildInfo
extends RefCounted

const GENERATED_PATH: String = "res://addons/build_kit/build_info.gen.tres"
const KEYS: PackedStringArray = ["version", "commit", "date", "godot_version", "release"]

static var _data: Dictionary = {}
static var _loaded: bool = false


## 版本（沒有建置資訊時是 "dev"）
static func version() -> String:
	return String(_value("version", "dev"))


static func commit() -> String:
	return String(_value("commit", ""))


## 建置日期（UTC，2026-11-18）
static func date() -> String:
	return String(_value("date", ""))


static func godot_version() -> String:
	return String(_value("godot_version", Engine.get_version_info()["string"]))


## 是不是正式版（打 tag 建出來的）
static func is_release() -> bool:
	return bool(_value("release", false))


## 給畫面角落用：正式版 "v0.4.2"，其他照版本原樣，沒有建置資訊時 "dev"。
static func label() -> String:
	return "v" + version() if is_release() else version()


## 重新讀取（測試、或建置資訊檔剛被寫入時）。
static func refresh(path: String = GENERATED_PATH) -> void:
	_data.clear()
	_loaded = true
	if not ResourceLoader.exists(path):
		return
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return
	for key: String in KEYS:
		if resource.has_meta(key):
			_data[key] = resource.get_meta(key)


## 建置用：把資訊寫成 build_info.gen.tres。
static func write(path: String, values: Dictionary) -> Error:
	var resource := Resource.new()
	for key: String in KEYS:
		if values.has(key):
			resource.set_meta(key, values[key])
	return ResourceSaver.save(resource, path)


static func _value(key: String, default: Variant) -> Variant:
	if not _loaded:
		refresh()
	return _data.get(key, default)
