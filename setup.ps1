# setup.ps1 — 安裝 clog 到新專案
# 用法：在新專案根目錄執行：
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\clog\setup.ps1"

$kitDir     = $PSScriptRoot
$globalDest = Join-Path $env:USERPROFILE ".claude"
$projectDir = Get-Location

Write-Host "=== clog setup ===" -ForegroundColor Cyan
Write-Host "Project : $projectDir"
Write-Host "Global  : $globalDest"

# 0. 確認 git user identity
$gitName  = git config --global user.name  2>$null
$gitEmail = git config --global user.email 2>$null
if (-not $gitName) {
    $gitName = Read-Host "Git user.name 未設定，請輸入名稱"
    git config --global user.name $gitName
}
if (-not $gitEmail) {
    $gitEmail = Read-Host "Git user.email 未設定，請輸入 Email"
    git config --global user.email $gitEmail
}
Write-Host "[OK] Git identity: $gitName <$gitEmail>" -ForegroundColor Green

# 1. 複製全域腳本
New-Item -ItemType Directory -Force -Path $globalDest | Out-Null
Copy-Item "$kitDir\global\read_prompt.js"  "$globalDest\read_prompt.js"  -Force
Copy-Item "$kitDir\global\auto_commit.ps1" "$globalDest\auto_commit.ps1" -Force
Write-Host "[OK] Scripts copied to $globalDest" -ForegroundColor Green

# 2. 建立 .claude/settings.json
$settingsDir = Join-Path $projectDir ".claude"
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

$fwd      = $globalDest -replace '\\', '/'
$nodePath = "node $fwd/read_prompt.js"
$ps1Path  = "powershell -ExecutionPolicy Bypass -NonInteractive -File $fwd/auto_commit.ps1"

$utf8NoBOM = New-Object System.Text.UTF8Encoding $false
$settings = @"
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$nodePath"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$ps1Path"
          }
        ]
      }
    ]
  }
}
"@
[System.IO.File]::WriteAllText("$settingsDir\settings.json", $settings, $utf8NoBOM)
Write-Host "[OK] .claude/settings.json created" -ForegroundColor Green

# 3. 確認 git repo（若不存在則 init）
$isGit = git -C $projectDir rev-parse --git-dir 2>$null
if (-not $isGit) {
    git init $projectDir | Out-Null
    Write-Host "[OK] git init completed" -ForegroundColor Green
} else {
    Write-Host "[--] Already a git repo, skipped git init" -ForegroundColor Yellow
}

# 4. 建立 PROMPT_LOG.md（若不存在）
$logPath = Join-Path $projectDir "PROMPT_LOG.md"
if (-not (Test-Path $logPath)) {
    [System.IO.File]::WriteAllText($logPath, "| Time | Prompt | Commit Hash |`r`n|:---|:---|:---|`r`n", $utf8NoBOM)
    Write-Host "[OK] PROMPT_LOG.md created" -ForegroundColor Green
} else {
    Write-Host "[--] PROMPT_LOG.md already exists, skipped" -ForegroundColor Yellow
}

# 5. 確認 .gitignore 包含 PROMPT_LOG.md
$ignorePath = Join-Path $projectDir ".gitignore"
if (Test-Path $ignorePath) {
    $content = Get-Content $ignorePath -Raw
    if ($content -notmatch "PROMPT_LOG\.md") {
        Add-Content $ignorePath "`r`nPROMPT_LOG.md"
        Write-Host "[OK] PROMPT_LOG.md added to .gitignore" -ForegroundColor Green
    } else {
        Write-Host "[--] .gitignore already has PROMPT_LOG.md" -ForegroundColor Yellow
    }
} else {
    [System.IO.File]::WriteAllText($ignorePath, "PROMPT_LOG.md`r`n", $utf8NoBOM)
    Write-Host "[OK] .gitignore created" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Restart Claude Code in this project to activate hooks." -ForegroundColor Cyan
