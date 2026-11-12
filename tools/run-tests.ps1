param([string]$Godot = "$PSScriptRoot/godot/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA
$script:TestResults = [System.Collections.Generic.List[object]]::new()

function Invoke-CurrentCheck {
    param([string]$Name, [string]$Program, [string[]]$Arguments, [string]$EngineLog = '')
    $consoleLog = Join-Path $projectRoot "builds/$Name-console.log"
    $started = [DateTimeOffset]::UtcNow
    Write-Host "Running $Name..."
    if (-not (Get-Command $Program -ErrorAction SilentlyContinue)) {
        throw "Required test program is unavailable: $Program"
    }
    # Native test frameworks use stderr for ordinary diagnostics as well as
    # failures. The exit code and engine-log audit determine the outcome.
    $nativePreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Program @Arguments *> $consoleLog
    $nativeExit = $LASTEXITCODE
    $ErrorActionPreference = $nativePreference
    $unexpected = @()
    if ($EngineLog -and (Test-Path -LiteralPath $EngineLog)) {
        $unexpected = @(Select-String -LiteralPath $EngineLog -Pattern '^SCRIPT ERROR:|^ERROR: (?!Failed to read the root certificate store\.)|^WARNING:.*(?:leaked|ObjectDB)')
    }
    $passed = $nativeExit -eq 0 -and $unexpected.Count -eq 0
    $script:TestResults.Add([ordered]@{
        suite = $Name
        status = $(if ($passed) { 'PASS' } else { 'FAIL' })
        exit_code = $nativeExit
        unexpected_engine_messages = $unexpected.Count
        seconds = [Math]::Round(([DateTimeOffset]::UtcNow - $started).TotalSeconds, 3)
        log = "builds/$Name-console.log"
    })
    Get-Content -LiteralPath $consoleLog -Tail 7 | ForEach-Object { Write-Host $_ }
    if (-not $passed) { Write-Host "FAILED $Name (exit=$nativeExit; unexpected engine messages=$($unexpected.Count))." }
    return $passed
}

try {
    $env:APPDATA = Join-Path $projectRoot 'tools/test-home/AppData'
    $env:LOCALAPPDATA = Join-Path $projectRoot 'tools/test-home/LocalAppData'
    New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'builds'), $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    Push-Location $projectRoot
    try {
        $null = Invoke-CurrentCheck 'campaign-structure' 'python' @('tests/campaign_validator.py')
        $null = Invoke-CurrentCheck 'python-regressions' 'python' @('-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py', '-v')
        $importLog = Join-Path $projectRoot 'builds/import.log'
        $imported = Invoke-CurrentCheck 'project-import' $Godot @('--headless', '--path', $projectRoot, '--log-file', $importLog, '--editor', '--import', '--quit') $importLog
        if ($imported) {
            $suites = @('test_runner', 'physics_suite', 'persistence_test', 'audio_suite',
                'audio_shutdown_probe', 'ui_smoke', 'doodledrift_ui', 'integration_suite',
                'puzzle_suite', 'revision_suite', 'stress_suite')
            foreach ($suite in $suites) {
                if (-not (Test-Path -LiteralPath "tests/$suite.gd")) { continue }
                $engineLog = Join-Path $projectRoot "builds/$suite.log"
                $null = Invoke-CurrentCheck $suite $Godot @('--headless', '--path', $projectRoot,
                    '--fixed-fps', '60', '--log-file', $engineLog, '--script', "res://tests/$suite.gd") $engineLog
            }
        }
        $summary = [ordered]@{
            game = 'DoodleDrift'
            campaign_revision = 3
            engine_pin = 'Godot 4.7.2 stable'
            completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
            suites = $script:TestResults.ToArray()
            historical_excluded = @([ordered]@{
                suite = 'tests/campaign_physics.gd'
                reason = 'Historical revision-2 static-support bridge bot; not a solver for revision-3 moving-island, crate-key, constrained-ink or timing puzzles.'
            })
            limits = 'Current structural safety, mechanics, selected actual puzzle scenarios and negative bypass checks; not a 50-level completion proof, human playthrough, Android device test, audibility test or FPS claim.'
        }
        $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath 'builds/current-test-results.json' -Encoding utf8
        $failures = @($script:TestResults | Where-Object { $_.status -eq 'FAIL' })
        Write-Host "Current test runner: $($script:TestResults.Count) suites, $($failures.Count) failures."
        if ($failures.Count -gt 0) { throw 'Current regression checks failed; inspect builds/current-test-results.json and the named logs.' }
    } finally { Pop-Location }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
}
