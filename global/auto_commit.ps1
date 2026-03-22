# Hook: Stop
# Reads project dir from temp file — works for any project, no hardcoded paths.

$tmp  = [System.IO.Path]::GetTempPath()
$utf8 = New-Object System.Text.UTF8Encoding $false

$PF = Join-Path $tmp "last_prompt.txt"
$HF = Join-Path $tmp "last_head.txt"
$DF = Join-Path $tmp "last_dir.txt"

# Read project dir
if (-not (Test-Path $DF)) { exit 0 }
$projectDir = [System.IO.File]::ReadAllText($DF, $utf8).Trim()
if (-not (Test-Path $projectDir)) { exit 0 }

Set-Location $projectDir

# Auto-init git repo if not already one
if (-not (Test-Path (Join-Path $projectDir ".git"))) {
    git init 2>$null
}

$LF = Join-Path $projectDir "PROMPT_LOG.md"
$DT = Get-Date -Format "yyyy-MM-dd HH:mm"

# Read previous HEAD
$prevHead = $null
if (Test-Path $HF) { $prevHead = (Get-Content $HF -Raw).Trim() }

# Get current HEAD
$currentHead = $null
try { $currentHead = (git rev-parse HEAD 2>$null).Trim() } catch {}

# Detect git reset (HEAD moved backward)
if ($prevHead -and $currentHead -and $prevHead -ne $currentHead) {
    git merge-base --is-ancestor $currentHead $prevHead 2>$null
    if ($LASTEXITCODE -eq 0) {

        $rolledBack = @(git rev-list "$currentHead..$prevHead" 2>$null | Where-Object { $_ })

        if ($rolledBack.Count -gt 0 -and (Test-Path $LF)) {
            $fileContent = [System.IO.File]::ReadAllText($LF, $utf8)
            foreach ($fullHash in $rolledBack) {
                $sh   = $fullHash.Substring(0, 7)
                $pat  = "(?m)^\| (?!~~)(.+?) \| (.+?) \| $sh \|"
                $repl = "| ~~`$1~~ | ~~`$2~~ | ~~$sh~~ |"
                $fileContent = [regex]::Replace($fileContent, $pat, $repl)
            }
            [System.IO.File]::WriteAllText($LF, $fileContent, $utf8)
        }

        $shortCur = $currentHead.Substring(0, 7)
        [System.IO.File]::AppendAllText($LF, "| $DT | [RESET] [$shortCur] | - |`r`n", $utf8)
    }
}

# Normal commit flow
$status = git status --porcelain 2>$null
if (-not $status) { exit 0 }

$MSG = "auto commit"
if (Test-Path $PF) {
    $c = [System.IO.File]::ReadAllText($PF, $utf8).Trim()
    if ($c) { $MSG = $c }
}

# Auto-add PROMPT_LOG.md to .gitignore if needed
$ignorePath = Join-Path $projectDir ".gitignore"
if (Test-Path $ignorePath) {
    $ig = Get-Content $ignorePath -Raw
    if ($ig -notmatch "PROMPT_LOG\.md") {
        Add-Content $ignorePath "`r`nPROMPT_LOG.md"
    }
} else {
    [System.IO.File]::WriteAllText($ignorePath, "PROMPT_LOG.md`r`n", $utf8)
}

# Init PROMPT_LOG.md if not exists
if (-not (Test-Path $LF)) {
    [System.IO.File]::WriteAllText($LF, "| Time | Prompt | Commit Hash |`r`n|:---|:---|:---|`r`n", $utf8)
}

git add -A
git commit -m "[$DT] $MSG"
if ($LASTEXITCODE -ne 0) { exit 0 }

$HASH = (git rev-parse --short HEAD 2>$null).Trim()
[System.IO.File]::AppendAllText($LF, "| $DT | $MSG | $HASH |`r`n", $utf8)
