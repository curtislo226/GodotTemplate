## 把 build_kit 裝進專案：複製樣板（已經存在的不覆蓋，加 --force 才覆蓋）、補 .gitignore。
##   godot --headless --path . -s res://addons/build_kit/tools/install.gd [-- --force]
## 剛複製進來、還沒匯入過也能跑（用 preload，不靠 class_name 的快取）。
## 裝完：在編輯器新增 Web 與 Windows 的 export preset（export_presets.cfg 要進 git），填 build.cfg，再跑 ./build.ps1 -Check。
extends SceneTree

const Installer: GDScript = preload("res://addons/build_kit/build_installer.gd")


func _initialize() -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	var name: String = String(ProjectSettings.get_setting("application/config/name", "Game"))
	var force: bool = OS.get_cmdline_user_args().has("--force")
	var done: PackedStringArray = Installer.install(root, name, Installer.running_godot_version(), force)
	for line: String in done:
		print("  " + line)
	if not FileAccess.file_exists(root.path_join("export_presets.cfg")):
		print("\n還沒有 export_presets.cfg：在編輯器「專案 → 匯出」新增 Web 與 Windows Desktop 兩個 preset（名稱照 build.cfg 的 [presets]）。")
	print("\n下一步：檢查 build.cfg，然後 ./build.ps1 -Check（第一次會先匯入專案）")
	quit()
