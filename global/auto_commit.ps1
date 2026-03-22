# Hook: Stop
# Reads project dir from session-scoped temp file, deletes it after use.

$tmp  = [System.IO.Path]::GetTempPath()
$utf8 = New-Object System.Text.UTF8Encoding $false

# Read session_id from stdin
$stdinRaw = [Console]::In.ReadToEnd()
$sessionId = "default"
try {
    $stdinObj = $stdinRaw | ConvertFrom-Json
    if ($stdinObj.session_id) { $sessionId = $stdinObj.session_id }
} catch {}

$JF = Join-Path $tmp "clog_$sessionId.json"
if (-not (Test-Path $JF)) { exit 0 }

# Read and immediately delete the session temp file
$sessionData = $null
try {
    $sessionData = [System.IO.File]::ReadAllText($JF, $utf8) | ConvertFrom-Json
} catch {}
Remove-Item $JF -ErrorAction SilentlyContinue

if (-not $sessionData) { exit 0 }

$projectDir = $sessionData.dir
$prevHead   = $sessionData.head
$MSG        = if ($sessionData.prompt) { $sessionData.prompt } else { "auto commit" }

if (-not (Test-Path $projectDir)) { exit 0 }

Set-Location $projectDir

# Auto-init git repo if not already one
if (-not (Test-Path (Join-Path $projectDir ".git"))) {
    git init 2>$null
}

$LF = Join-Path $projectDir "PROMPT_LOG.md"
$DT = Get-Date -Format "yyyy-MM-dd HH:mm"

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

# Normal commit flow
$status = git status --porcelain 2>$null
if (-not $status) {
    # No file changes — still log the prompt with "-" as hash
    [System.IO.File]::AppendAllText($LF, "| $DT | $MSG | - |`r`n", $utf8)
    exit 0
}

git add -A
git commit -m "[$DT] $MSG"
if ($LASTEXITCODE -ne 0) { exit 0 }

$HASH = (git rev-parse --short HEAD 2>$null).Trim()
[System.IO.File]::AppendAllText($LF, "| $DT | $MSG | $HASH |`r`n", $utf8)
