@echo off
set "DRIFT_ROOT=%~dp0"
if exist "%DRIFT_ROOT%tools\godot\Godot_v4.7.2-stable_win64.exe" (
    start "DoodleDrift" "%DRIFT_ROOT%tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%DRIFT_ROOT%."
) else (
    echo Open project.godot in Godot 4.7.2 and press F5.
    pause
)
