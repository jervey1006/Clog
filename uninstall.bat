@echo off
echo === clog uninstall ===

:: 1. Remove scripts
set "CLAUDE_DIR=%USERPROFILE%\.claude"

if exist "%CLAUDE_DIR%\read_prompt.js" (
    del /f /q "%CLAUDE_DIR%\read_prompt.js"
    echo [OK] Removed read_prompt.js
) else (
    echo [--] read_prompt.js not found, skipped
)

if exist "%CLAUDE_DIR%\auto_commit.ps1" (
    del /f /q "%CLAUDE_DIR%\auto_commit.ps1"
    echo [OK] Removed auto_commit.ps1
) else (
    echo [--] auto_commit.ps1 not found, skipped
)

:: 2. Remove clog hooks from settings.json
set "SETTINGS=%CLAUDE_DIR%\settings.json"
if not exist "%SETTINGS%" (
    echo [--] settings.json not found, skipped
    goto done
)

powershell -ExecutionPolicy Bypass -NoProfile -Command ^
  "$utf8 = New-Object System.Text.UTF8Encoding $false;" ^
  "$path = $env:USERPROFILE + '\.claude\settings.json';" ^
  "$fwd = ($env:USERPROFILE + '\.claude') -replace '\\','/';" ^
  "$clogCmds = @(" ^
  "  \"node $fwd/read_prompt.js\"," ^
  "  \"powershell -ExecutionPolicy Bypass -NonInteractive -File $fwd/auto_commit.ps1\"" ^
  ");" ^
  "$raw = [System.IO.File]::ReadAllText($path, $utf8);" ^
  "try { $obj = $raw | ConvertFrom-Json } catch { Write-Host '[ERR] Could not parse settings.json'; exit 1 };" ^
  "if (-not $obj.hooks) { Write-Host '[--] No hooks found, skipped'; exit 0 };" ^
  "foreach ($event in @($obj.hooks.PSObject.Properties.Name)) {" ^
  "  $entries = $obj.hooks.$event;" ^
  "  if (-not $entries) { continue };" ^
  "  $filtered = @($entries | Where-Object {" ^
  "    $keep = $true;" ^
  "    foreach ($h in $_.hooks) { if ($clogCmds -contains $h.command) { $keep = $false } };" ^
  "    $keep" ^
  "  });" ^
  "  if ($filtered.Count -eq 0) {" ^
  "    $obj.hooks.PSObject.Properties.Remove($event);" ^
  "  } else {" ^
  "    $obj.hooks | Add-Member -NotePropertyName $event -NotePropertyValue $filtered -Force;" ^
  "  }" ^
  "};" ^
  "[System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 10), $utf8);"
echo [OK] Clog hooks removed from settings.json.

:done
echo.
echo Done! Restart Claude Code to complete uninstall.
pause
