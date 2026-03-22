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

:: 2. Merge clog hooks into global settings.json
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
  "$utf8 = New-Object System.Text.UTF8Encoding $false;" ^
  "$fwd = ($env:USERPROFILE + '\.claude') -replace '\\','/';" ^
  "$path = $env:USERPROFILE + '\.claude\settings.json';" ^
  "$clogHooks = @{" ^
  "  UserPromptSubmit = @(@{ hooks = @(@{ type = 'command'; command = \"node $fwd/read_prompt.js\" }) })" ^
  "  Stop             = @(@{ hooks = @(@{ type = 'command'; command = \"powershell -ExecutionPolicy Bypass -NonInteractive -File $fwd/auto_commit.ps1\" }) })" ^
  "};" ^
  "if (Test-Path $path) {" ^
  "  $raw = [System.IO.File]::ReadAllText($path, $utf8);" ^
  "  try { $obj = $raw | ConvertFrom-Json } catch { $obj = [pscustomobject]@{} };" ^
  "} else { $obj = [pscustomobject]@{} };" ^
  "if (-not $obj.hooks) { $obj | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) };" ^
  "foreach ($event in $clogHooks.Keys) {" ^
  "  $clogCmd = $clogHooks[$event][0].hooks[0].command;" ^
  "  $existing = $obj.hooks.$event;" ^
  "  $alreadyIn = $false;" ^
  "  if ($existing) { foreach ($h in $existing) { foreach ($hh in $h.hooks) { if ($hh.command -eq $clogCmd) { $alreadyIn = $true } } } };" ^
  "  if (-not $alreadyIn) {" ^
  "    $newEntry = @{ hooks = @(@{ type = 'command'; command = $clogCmd }) };" ^
  "    if ($existing) { $merged = @($existing) + @($newEntry) } else { $merged = @($newEntry) };" ^
  "    $obj.hooks | Add-Member -NotePropertyName $event -NotePropertyValue $merged -Force;" ^
  "  }" ^
  "};" ^
  "[System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 10), $utf8);"
echo [OK] Global hooks merged into settings.json.

echo.
echo Done! clog is active for all Claude Code projects.
pause
