# build_kit: build this project locally (same code path as CI).
#   ./build.ps1                  build every target in build.cfg (runs the tests first)
#   ./build.ps1 -Target web      only the web build
#   ./build.ps1 -SkipTests       skip the tests
#   ./build.ps1 -Check           only check build.cfg and export_presets.cfg
#   ./build.ps1 -TestsOnly       only run the tests
#   ./build.ps1 -DebugBuild      debug export (Windows build keeps a console)
# Godot is found by: -Godot, else $env:GODOT_BIN, else the build.cfg godot_version
# under $env:GODOT_HOME (default: the folder that holds this project), else "godot" on PATH.
# Keep this file ASCII only (Windows PowerShell 5.1 reads it in the system code page).
param(
    [string]$Godot = "",
    [ValidateSet("all", "web", "windows")]
    [string]$Target = "all",
    [switch]$SkipTests,
    [switch]$TestsOnly,
    [switch]$Check,
    [switch]$DebugBuild
)

function Find-Godot {
    if ($Godot) { return $Godot }
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) { return $env:GODOT_BIN }
    $cfg = Join-Path $PSScriptRoot "build.cfg"
    $version = ""
    if (Test-Path -LiteralPath $cfg) {
        $match = Select-String -LiteralPath $cfg -Pattern '^\s*godot_version\s*=\s*"([^"]*)"' | Select-Object -First 1
        if ($match) { $version = $match.Matches[0].Groups[1].Value }
    }
    if ($version) {
        $root = if ($env:GODOT_HOME) { $env:GODOT_HOME } else { Split-Path -Parent $PSScriptRoot }
        $candidates = Get-ChildItem -LiteralPath $root -Filter ("Godot_v{0}_win64*" -f $version) -ErrorAction SilentlyContinue
        foreach ($item in $candidates) {
            if ($item.PSIsContainer) {
                $console = Get-ChildItem -LiteralPath $item.FullName -Recurse -Depth 2 -Filter "*_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($console) { return $console.FullName }
            } elseif ($item.Name -like "*_console.exe") {
                return $item.FullName
            }
        }
        Write-Host ("Godot {0} (build.cfg godot_version) not found under {1}: unzip Godot_v{0}_win64 there, or set GODOT_BIN / GODOT_HOME." -f $version, $root)
        return $null
    }
    $found = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    return $null
}

$exe = Find-Godot
if (-not $exe) {
    Write-Host "Godot executable not found. Set GODOT_BIN, set GODOT_HOME, or pass -Godot <path>."
    exit 2
}
Write-Host "Using $exe"

$cache = Join-Path $PSScriptRoot ".godot/global_script_class_cache.cfg"
if (-not (Test-Path -LiteralPath $cache) -or -not (Select-String -LiteralPath $cache -Pattern "BuildPipeline" -Quiet)) {
    Write-Host "Importing the project (first run, or build_kit was just added)..." 
    & $exe --headless --path $PSScriptRoot --import | Out-Null
    & $exe --headless --path $PSScriptRoot --import | Out-Null
}

$buildArgs = @()
if ($Target -ne "all") { $buildArgs += "--target=$Target" }
if ($SkipTests) { $buildArgs += "--skip-tests" }
if ($TestsOnly) { $buildArgs += "--tests-only" }
if ($Check) { $buildArgs += "--check" }
if ($DebugBuild) { $buildArgs += "--debug" }

& $exe --headless --path $PSScriptRoot -s res://addons/build_kit/tools/build.gd -- @buildArgs
exit $LASTEXITCODE
