@echo off
set "QUEST_ROOT=%~dp0"
if exist "%QUEST_ROOT%tools\godot\Godot_v4.7.2-stable_win64.exe" (
    start "DoodleDrift" "%QUEST_ROOT%tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%QUEST_ROOT%."
) else (
    echo Open project.godot in Godot 4.7.2 and press F6 or F5.
    pause
)
