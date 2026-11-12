param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$Godot = '',
    [string]$AndroidSdk = '',
    [string]$JavaSdk = '',
    [string]$TemplatesRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $Godot = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
    if (-not (Test-Path -LiteralPath $Godot)) {
        $foundGodot = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $foundGodot) { throw 'Install Godot 4.7.2 or pass -Godot with its executable path.' }
        $Godot = $foundGodot.Source
    }
}
if (-not $AndroidSdk) { $AndroidSdk = Join-Path $PSScriptRoot 'android-sdk' }
if (-not $JavaSdk) { $JavaSdk = $env:JAVA_HOME }
if (-not $JavaSdk) {
    $foundJava = Get-Command java -ErrorAction SilentlyContinue
    if ($null -ne $foundJava) { $JavaSdk = Split-Path -Parent (Split-Path -Parent $foundJava.Source) }
}
if (-not $JavaSdk -or -not (Test-Path -LiteralPath (Join-Path $JavaSdk 'bin/keytool.exe'))) {
    throw 'Pass -JavaSdk pointing to a JDK (Godot recommends JDK 17).'
}
if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdk 'platform-tools/adb.exe'))) {
    throw 'Install Android SDK platform-tools and build-tools, then pass -AndroidSdk.'
}
$AndroidSdk = (Resolve-Path -LiteralPath $AndroidSdk).Path
$JavaSdk = (Resolve-Path -LiteralPath $JavaSdk).Path
$profileRoot = Join-Path $PSScriptRoot 'android-home'
$profileAppData = Join-Path $profileRoot 'AppData'
$profileLocalData = Join-Path $profileRoot 'LocalAppData'
$godotSettings = Join-Path $profileAppData 'Godot'
$templateDestination = Join-Path $godotSettings 'export_templates/4.7.2.stable'
New-Item -ItemType Directory -Force -Path $profileLocalData, $templateDestination, (Join-Path $projectRoot 'builds') | Out-Null
if (-not $TemplatesRoot) {
    if (Test-Path -LiteralPath (Join-Path $templateDestination 'android_debug.apk')) {
        $TemplatesRoot = $templateDestination
    } else {
        $TemplatesRoot = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $TemplatesRoot 'android_debug.apk'))) {
    throw 'Install the official 4.7.2 export templates or pass -TemplatesRoot.'
}
if (([IO.Path]::GetFullPath($TemplatesRoot)) -ne ([IO.Path]::GetFullPath($templateDestination))) {
    foreach ($templateName in @('android_debug.apk', 'android_release.apk', 'android_source.zip')) {
        $sourceTemplate = Join-Path $TemplatesRoot $templateName
        if (Test-Path -LiteralPath $sourceTemplate) {
            Copy-Item -LiteralPath $sourceTemplate -Destination $templateDestination -Force
        }
    }
}

$debugKey = Join-Path $profileRoot 'debug.keystore'
if ($Configuration -eq 'Debug' -and -not (Test-Path -LiteralPath $debugKey)) {
    & (Join-Path $JavaSdk 'bin/keytool.exe') -genkeypair -keystore $debugKey -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Could not generate the development-only signing key.' }
}
if ($Configuration -eq 'Release') {
    foreach ($secretName in @('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')) {
        if (-not [Environment]::GetEnvironmentVariable($secretName)) { throw "Provide $secretName through a secret manager before release export." }
    }
    $gradleBuild = Join-Path $projectRoot 'android/build'
    if (-not (Test-Path -LiteralPath (Join-Path $gradleBuild 'build.gradle'))) {
        $sourceZip = Join-Path $templateDestination 'android_source.zip'
        if (-not (Test-Path -LiteralPath $sourceZip)) { throw 'Install the exact Android source export template.' }
        Expand-Archive -LiteralPath $sourceZip -DestinationPath $gradleBuild -Force
        [IO.File]::WriteAllText((Join-Path $gradleBuild '.gdignore'), '')
        [IO.File]::WriteAllText((Join-Path $projectRoot 'android/.build_version'), "4.7.2.stable`n")
    }
}

# Keep editor settings and debug keys task-local. Do not change the user's global
# Godot settings, store a production key, or print release secret values.
$settingsText = @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path="$($JavaSdk.Replace('\', '/'))"
export/android/android_sdk_path="$($AndroidSdk.Replace('\', '/'))"
export/android/debug_keystore="$($debugKey.Replace('\', '/'))"
"@
[IO.File]::WriteAllText((Join-Path $godotSettings 'editor_settings-4.7.tres'), $settingsText)
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA
$oldJavaSdk = $env:JAVA_HOME
try {
    $env:APPDATA = $profileAppData
    $env:LOCALAPPDATA = $profileLocalData
    $env:JAVA_HOME = $JavaSdk
    $isDebug = $Configuration -eq 'Debug'
    $presetName = if ($isDebug) { 'Android Debug APK' } else { 'Android Release AAB' }
    $artifactName = if ($isDebug) { 'doodledrift-debug.apk' } else { 'doodledrift-release.aab' }
    $exportFlag = if ($isDebug) { '--export-debug' } else { '--export-release' }
    $outputArtifact = Join-Path $projectRoot "builds/$artifactName"
    $exportLog = Join-Path $projectRoot 'builds/android-export-debug.log'
    if (-not $isDebug) { $exportLog = Join-Path $projectRoot 'builds/android-export-release.log' }
    & $Godot --headless --path $projectRoot $exportFlag $presetName $outputArtifact --log-file $exportLog
    if ($LASTEXITCODE -ne 0) { throw "Godot Android export failed (exit $LASTEXITCODE)." }
    if ($isDebug) {
        $buildToolDirectory = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory | Sort-Object Name -Descending | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') } | Select-Object -First 1
        if ($null -eq $buildToolDirectory) { throw 'Android apksigner was not found.' }
        # The official 4.7.2 prebuilt exporter rewrites both provider authorities
        # to .fileprovider. Repair only AndroidX's authority, then align and sign
        # again; the Python helper verifies every unrelated attribute is unchanged.
        $unsignedApk = Join-Path $projectRoot 'builds/doodledrift-debug-unsigned.apk'
        $alignedApk = Join-Path $projectRoot 'builds/doodledrift-debug-aligned.apk'
        & python (Join-Path $PSScriptRoot 'fix_android_manifest.py') $outputArtifact $unsignedApk *> (Join-Path $projectRoot 'builds/android-manifest-repair.log')
        if ($LASTEXITCODE -ne 0) { throw 'Android provider authority repair failed.' }
        & (Join-Path $buildToolDirectory.FullName 'zipalign.exe') -f -P 16 4 $unsignedApk $alignedApk
        if ($LASTEXITCODE -ne 0) { throw 'Repaired APK alignment failed.' }
        & (Join-Path $buildToolDirectory.FullName 'apksigner.bat') sign --ks $debugKey --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --v4-signing-enabled false --out $outputArtifact $alignedApk
        if ($LASTEXITCODE -ne 0) { throw 'Repaired debug APK signing failed.' }
        & (Join-Path $buildToolDirectory.FullName 'zipalign.exe') -c -P 16 4 $outputArtifact *> (Join-Path $projectRoot 'builds/android-alignment-verification.log')
        if ($LASTEXITCODE -ne 0) { throw 'Final APK alignment verification failed.' }
        & (Join-Path $buildToolDirectory.FullName 'apksigner.bat') verify --verbose $outputArtifact *> (Join-Path $projectRoot 'builds/android-signature-verification.log')
        if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
        & (Join-Path $buildToolDirectory.FullName 'aapt2.exe') dump badging $outputArtifact *> (Join-Path $projectRoot 'builds/android-manifest-verification.log')
        if ($LASTEXITCODE -ne 0) { throw 'APK manifest inspection failed.' }
        & (Join-Path $buildToolDirectory.FullName 'aapt2.exe') dump xmltree $outputArtifact --file AndroidManifest.xml *> (Join-Path $projectRoot 'builds/android-manifest-xml.log')
        if ($LASTEXITCODE -ne 0) { throw 'Final APK manifest XML inspection failed.' }
        & (Join-Path $buildToolDirectory.FullName 'aapt2.exe') dump xmltree $outputArtifact --file res/mipmap-anydpi-v26/icon.xml *> (Join-Path $projectRoot 'builds/android-icon-verification.log')
        if ($LASTEXITCODE -ne 0) { throw 'Final APK adaptive icon inspection failed.' }
    }
    $digest = (Get-FileHash -LiteralPath $outputArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $projectRoot 'builds/android-sha256.txt'), "$digest  $artifactName`n")
    Write-Output "Built $artifactName ($((Get-Item -LiteralPath $outputArtifact).Length) bytes)."
    Write-Output "SHA-256: $digest"
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
    $env:JAVA_HOME = $oldJavaSdk
}
