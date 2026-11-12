param([string]$Godot = "$PSScriptRoot/godot/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$profileRoot = Join-Path $PSScriptRoot 'web-home'
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $profileRoot 'AppData'
    $env:LOCALAPPDATA = Join-Path $profileRoot 'LocalAppData'
    New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'builds/web'), $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $template = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable/web_nothreads_debug.zip'
    if (Test-Path -LiteralPath $template) {
        & $Godot --headless --path $projectRoot --export-debug 'Web Browser Preview' (Join-Path $projectRoot 'builds/web/index.html') --log-file (Join-Path $projectRoot 'builds/web-export.log')
    } else {
        # The official live-editor build also runs games without --editor.
        # This local preview uses that exact pinned runtime when archive downloads
        # are unavailable. It is larger and threaded; serve-web.py provides its headers.
        foreach ($runtimeFile in @('godot.editor.js', 'godot.editor.wasm', 'godot.editor.audio.worklet.js', 'godot.editor.audio.position.worklet.js')) {
            $cachedRuntime = Join-Path $PSScriptRoot "web-downloads/$runtimeFile"
            if (-not (Test-Path -LiteralPath $cachedRuntime)) {
                throw "Missing $runtimeFile. Install Godot 4.7.2 Web export templates, or cache the official live-editor runtime under tools/web-downloads."
            }
            Copy-Item -LiteralPath $cachedRuntime -Destination (Join-Path $projectRoot "builds/web/$runtimeFile") -Force
        }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'web-preview.html') -Destination (Join-Path $projectRoot 'builds/web/index.html') -Force
        & $Godot --headless --path $projectRoot --export-pack 'Web Browser Preview' (Join-Path $projectRoot 'builds/web/index.pck') --log-file (Join-Path $projectRoot 'builds/web-pack.log')
    }
    if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed; inspect builds/web-export.log.' }
    $fontDestination=Join-Path $projectRoot 'builds/web/fonts'
    New-Item -ItemType Directory -Force -Path $fontDestination | Out-Null
    Copy-Item -Path (Join-Path $projectRoot 'assets/fonts/*') -Destination $fontDestination -Exclude '*.import' -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/icon.svg') -Destination (Join-Path $projectRoot 'builds/web/favicon.svg') -Force
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
}
