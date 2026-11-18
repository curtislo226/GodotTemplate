# Build Kit（建置與 CI）

Godot 4.8 的 Windows 與 Web 建置、版本號、GitHub Actions CI、itch.io 上傳。**本機（`build.ps1`）與 CI 跑同一段 GDScript**，每個專案只有一份 `build.cfg` 不一樣。
從 ElementPath 的 `build.ps1`／`tools/export_exclusions.gd`／`.github/workflows/tests.yml` 抽出來重寫。

| Module | 做什麼 |
|---|---|
| `BuildInfo` | **跟遊戲出貨**：`BuildInfo.label()` → `v0.4.2`、`0.4.2-dev.7+a1b2c3d`、編輯器裡是 `dev` |
| `BuildConfig` | 讀與檢查 `build.cfg` |
| `BuildVersion` | git tag → 版本（正式版、開發版、`.dirty`）、exe 的四段檔案版本 |
| `BuildExclusions` | 匯出排除清單：固定樣式＋`prune_dirs` 裡沒被出貨內容引用的檔案 |
| `BuildPresets` | 檢查 `export_presets.cfg`（preset 存在、平台、Web 不開執行緒與 GDExtension）；備份後寫入排除清單與版本、還原；`recover()` 處理上次沒還原的 |
| `BuildPackager` | zip、清掉舊建置 |
| `BuildPipeline` | `check()`、`test()`、`build(targets, debug, run_tests)`，各回傳 `Result`（`ok`、`lines`、`outputs`） |
| `BuildInstaller` | 把樣板裝進專案（不覆蓋已存在的檔案）、補 `.gitignore` |
| `tools/build.gd`、`tools/install.gd` | 命令列入口（`build.ps1` 與 CI 呼叫 build.gd；build.gd 負責寫 `$GITHUB_OUTPUT`） |

**專案 = `build.cfg` 所在的資料夾**：`export_presets.cfg`、git、測試、`build/` 都以它為準。排除清單與 `BuildInfo` 一律針對正在執行的專案（實際使用時兩者相同）。

相依：無。需要 git（版本號）與該 Godot 版本的匯出模板。

## 安裝

```
godot --headless --path . -s res://addons/build_kit/tools/install.gd
```

剛複製進來、還沒匯入過的專案也能直接跑。會寫入（已存在的不覆蓋，`-- --force` 才覆蓋）：`build.ps1`、`build.cfg`、`.github/workflows/build_kit.yml`、`.github/actions/setup-godot/action.yml`，並在 `.gitignore` 加 `/build/` 與 `build_info.gen.tres`。然後：

1. 編輯器「專案 → 匯出」新增 **Web** 與 **Windows Desktop** 兩個 preset（名稱照 `build.cfg` 的 `[presets]`）。`export_presets.cfg` **要進 git**（Godot 4 的密碼在 `.godot/export_credentials.cfg`，不在這個檔）。
   - Web：`variant/thread_support` 與 `variant/extensions_support` 關閉（`-Check` 會擋）
   - Windows：`binary_format/embed_pck=true`、`application/icon` 用 `.ico`、`modify_resources=true`
2. 填 `build.cfg`（說明在檔案裡）：`name`、`godot_version`、`test_args`、`[test_env]`、`bundle`、`[export]`、`[itch]`。
3. `./build.ps1 -Check`（檢查 build.cfg、preset、Godot 版本；`export_presets.cfg` 還沒進 git 時只提醒，本機照樣能建），再 `./build.ps1`。
4. 遊戲裡顯示版本：`version_label.text = BuildInfo.label()`。

## 本機建置

```
./build.ps1                     測試 → 匯出所有平台 → build/<版本>/
./build.ps1 -Target web         只建 Web
./build.ps1 -SkipTests          不跑測試
./build.ps1 -Check              只檢查設定
./build.ps1 -TestsOnly          只跑測試
./build.ps1 -DebugBuild         debug 版（輸出資料夾加 -debug）
```

找 Godot 的順序：`-Godot <路徑>` → `$env:GODOT_BIN` → `build.cfg` 的 `godot_version` 在 `$env:GODOT_HOME`（預設是專案的上一層，即 `Desktop\Godots`）找 `Godot_v<版本>_win64*` 裡的 `*_console.exe`；**找不到指定版本就停止**（不會偷用別的版本，匯出模板會對不上）。沒有 `godot_version` 時才用 PATH 上的 `godot`。
`-Check` 也會比對正在跑的 Godot 與 `godot_version`。
換 Godot 版本：把新版解壓到 `Desktop\Godots`，改 `build.cfg` 的 `godot_version`。

輸出：

```
build/0.4.2/                     開發版的資料夾把 + 換成 _：0.4.2-dev.7_a1b2c3d（build_info.json 裡仍是 +）
  web/            index.html、index.pck、index.wasm…（可以直接 butler push）
  windows/        <name>.exe（pck 嵌在裡面）
  <name>-0.4.2-web.zip
  <name>-0.4.2-windows.zip       含 bundle 的檔案（授權、CHANGELOG）
  build_info.json                版本、commit、Godot 版本、日期、是否略過測試
```

本機 `build/` 只保留最近 `keep_builds` 次（預設 5）；只算 build_kit 建出來的資料夾（有 `build_info.json` 的），舊流程的輸出或自己放的東西不會被刪。

## 版本號

git tag 是唯一來源（`v0.4.2`）：

| 狀況 | 版本 | exe 檔案版本 |
|---|---|---|
| 就在 tag `v0.4.2` 上、工作區乾淨 | `0.4.2`（正式版） | 0.4.2.0 |
| tag 之後 7 個 commit | `0.4.2-dev.7+a1b2c3d` | 0.4.2.7 |
| 還沒有 tag | `0.0.0-dev.<commit 數>+a1b2c3d` | 0.0.0.N |
| 有沒提交的修改 | 再加 `.dirty`（不算正式版） | |

發佈：更新 `CHANGELOG.md` → commit → `git tag v0.4.2` → `git push --follow-tags`。

## CI（`.github/workflows/build_kit.yml`）

| 觸發 | 做什麼 |
|---|---|
| 每次 push（任何分支） | 跑測試（`--tests-only`）；匯出 Web 確認還能建（不留成品）。不另外跑 pull_request，避免同一個分支跑兩次 |
| 推上 main、手動執行 | 匯出所有平台，zip 保留 30 天（Actions → 該次執行 → Artifacts） |
| 推 `v*` tag | 正式建置、建立 GitHub Release（說明用 `CHANGELOG.md`）；`[itch] target` 有填且設了 `BUTLER_API_KEY` 時上傳 itch.io |

- Godot 與匯出模板從 godotengine/godot-builds 下載，有快取（同版本第二次起約省一半時間）。
- 同一分支有新的 push 時，舊的執行會被取消（tag 不會）。
- 跑在 Linux runner（Windows 版也在 Linux 匯出）。GitHub Free 的私人 repo 每月 2000 分鐘，接近上限時再把 push 的 Web 匯出拿掉。
- 失敗時 log 會有 `::error::` 註記；匯出失敗會印出 Godot 輸出的最後 30 行；匯入失敗會印出匯入輸出。
- 專案需要額外的 CI 步驟（例如 ElementPath 的整局試玩）：在自己的 workflow 另外加 job，不要改 `build_kit.yml`（重新安裝會蓋掉）。

## 上傳 itch.io

**Agent 注意：使用者表示要上傳 itch.io 時，提醒他 API key 要自己設定（Agent 不能經手 key），並給他下面的步驟。**

1. itch.io → 右上頭像 → Settings → **API keys** → Generate new API key，複製。
2. 設成 repo 的 secret（擇一）：
   - 終端機：`gh secret set BUTLER_API_KEY -R curtislo226/<repo>`，貼上 key、Enter
   - 網頁：GitHub repo → Settings → Secrets and variables → Actions → New repository secret，名稱 `BUTLER_API_KEY`
3. itch.io 上先建立遊戲頁面（Web 版要把「Kind of project」設成 HTML，上傳後勾「This file will be played in the browser」）。
4. `build.cfg` 的 `[itch] target="<itch 帳號>/<遊戲網址名稱>"`；channel 預設 `html5`、`windows`，某個平台不想上傳就把它的 channel 留空（例如 `windows=""`）。
5. 推 `v*` tag，或 Actions → Build → Run workflow 勾「Also upload to itch.io」。

沒設 secret 時 CI 只會出警告、不會失敗。Steam 維持手動上傳。

## 規則與限制

- **`prune_dirs` 只適合「有靜態引用」的素材**：排除邏輯從主場景、autoload、翻譯、圖示、`shipped_dirs` 出發，沿資源相依與程式碼裡的 `"res://…"` 字串找。用目錄列表或組字串（`"res://ui/%s.png" % name`）載入的檔案找不到，會被排掉——這種資料夾不要放進 `prune_dirs`，或放進 `shipped_dirs`。
- Web 版不含 GDExtension：程式裡呼叫 GodotSteam 這類擴充前先 `Engine.has_singleton("Steam")`。
- `build.ps1` 只能有 ASCII（Windows PowerShell 5.1 用系統字碼頁讀）。
- 建置時會暫時改 `export_presets.cfg`（先備份到 `build/.export_presets.backup`）、寫 `addons/build_kit/build_info.gen.tres`，結束時還原／刪除。中途被強制結束（Ctrl+C、當掉）時，**下一次 check／test／build 一開始會自動還原並提示**。
- 測試需要環境變數（例如 ElementPath 的 `EP_TEST_LANGUAGE`）：寫在 `build.cfg` 的 `[test_env]`。
- 需要「測試輸出檢查」這類專案專屬的把關：寫成專案自己的 GDScript 測試入口（像 GodotToolBox 的 `tools/run_all_tests.gd`），`test_args` 指向它。
- 只支援 GDScript 專案（沒有 .NET 匯出）。

## 測試與 Demo

```
godot --headless --path . -s res://addons/build_kit/tests/build_kit_tests.gd     # 不真的匯出
./build.ps1                                                                      # 真的建一次（GodotToolBox 自己）
godot --path . -- --demo=build_kit
```

Demo：這個專案自己的建置狀態（`BuildInfo`、`build.cfg`、git 版本、preset 檢查、排除清單），不會真的匯出。

## 版本紀錄

- 0.1.2：install 不需要先匯入專案；`export_presets.cfg` 沒進 git 改成提醒（不擋本機建置）；清理舊建置只動 build_kit 自己的資料夾（ElementPath 遷移時發現）。
- 0.1.1：`prune_dirs`／`shipped_dirs` 寫相對路徑（`assets/`）也從專案根目錄算（KingsBall 安裝時發現）。
- 0.1.0：從 ElementPath 抽出；GodotToolBox 自己第一個使用。經 deep module 檢討：Pipeline 改成 check／test／build 三個方法回傳 Result、中途中斷自動還原、`-Check` 比對 Godot 版本與 `export_presets.cfg` 是否進 git、`[test_env]`、itch 某平台可留空、CI 錯誤註記。
