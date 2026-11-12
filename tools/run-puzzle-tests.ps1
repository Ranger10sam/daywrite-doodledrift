param([string]$Godot="$PSScriptRoot/godot/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$env:APPDATA=Join-Path $projectRoot 'tools/test-home/AppData'
$env:LOCALAPPDATA=Join-Path $projectRoot 'tools/test-home/LocalAppData'
foreach($suite in @('puzzle_suite','physics_suite','ui_smoke')) {
    & $Godot --headless --path $projectRoot --fixed-fps 60 --script "res://tests/$suite.gd" --log-file (Join-Path $projectRoot "builds/puzzle-$suite.log")
    if($LASTEXITCODE -ne 0){throw "$suite failed"}
}
