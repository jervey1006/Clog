@echo off
echo === clog install ===

:: 0. Check git user identity
for /f "delims=" %%i in ('git config --global user.name 2^>nul') do set GIT_NAME=%%i
for /f "delims=" %%i in ('git config --global user.email 2^>nul') do set GIT_EMAIL=%%i

if not defined GIT_NAME (
    set /p GIT_NAME="Git user.name not set. Enter name: "
    git config --global user.name "%GIT_NAME%"
)
if not defined GIT_EMAIL (
    set /p GIT_EMAIL="Git user.email not set. Enter email: "
    git config --global user.email "%GIT_EMAIL%"
)
echo [OK] Git identity: %GIT_NAME% ^<%GIT_EMAIL%^>

:: 1. Copy scripts to global .claude
copy "%~dp0global\read_prompt.js"  "%USERPROFILE%\.claude\read_prompt.js"  /Y
copy "%~dp0global\auto_commit.ps1" "%USERPROFILE%\.claude\auto_commit.ps1" /Y
echo [OK] Scripts copied.

:: 2. Write global settings.json (hooks for all projects)
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
  "$fwd = ($env:USERPROFILE + '\.claude') -replace '\\','/';" ^
  "$s = '{\"hooks\":{\"UserPromptSubmit\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"node ' + $fwd + '/read_prompt.js\"}]}],\"Stop\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"powershell -ExecutionPolicy Bypass -NonInteractive -File ' + $fwd + '/auto_commit.ps1\"}]}]}}' ;" ^
  "[System.IO.File]::WriteAllText($env:USERPROFILE + '\.claude\settings.json', $s, (New-Object System.Text.UTF8Encoding $false));"
echo [OK] Global hooks configured.

echo.
echo Done! clog is active for all Claude Code projects.
pause
