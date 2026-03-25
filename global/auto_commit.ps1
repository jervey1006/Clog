# Hook: Stop
# Reads project dir from session-scoped temp file (array), deletes it after use.

$tmp  = [System.IO.Path]::GetTempPath()
$utf8 = New-Object System.Text.UTF8Encoding $false

# Read session_id from stdin using ConvertFrom-Json (consistent with read_prompt.js)
$stdinRaw = [Console]::In.ReadToEnd()
$sessionId = "default"
try {
    $stdinObj = $stdinRaw | ConvertFrom-Json -ErrorAction Stop
    if ($stdinObj.session_id) { $sessionId = $stdinObj.session_id }
} catch {
    # Fallback to regex if JSON parse fails
    if ($stdinRaw -match '"session_id"\s*:\s*"([^"]+)"') {
        $sessionId = $Matches[1]
    }
}

$JF = Join-Path $tmp "clog_$sessionId.json"
if (-not (Test-Path $JF)) { exit 0 }

# Read and immediately delete the session temp file
$entries = $null
try {
    $raw = [System.IO.File]::ReadAllText($JF, $utf8)
    $parsed = $raw | ConvertFrom-Json
    $entries = if ($parsed -is [array]) { $parsed } else { @($parsed) }
} catch {}
Remove-Item $JF -ErrorAction SilentlyContinue

if (-not $entries -or $entries.Count -eq 0) { exit 0 }

# Use first entry's HEAD for reset detection, last entry's dir as project
$projectDir = $entries[-1].dir
$prevHead   = $entries[0].head

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

# Commit message uses the last (most recent) prompt
$MSG = if ($entries[-1].prompt) { $entries[-1].prompt } else { "auto commit" }

# Normal commit flow
$status = git status --porcelain 2>$null
if (-not $status) {
    # No file changes — log all pending prompts with "-" as hash
    foreach ($entry in $entries) {
        $entryMsg = if ($entry.prompt) { $entry.prompt } else { "auto commit" }
        [System.IO.File]::AppendAllText($LF, "| $DT | $entryMsg | - |`r`n", $utf8)
    }
    exit 0
}

git add -A
git commit -m "[$DT] $MSG"
if ($LASTEXITCODE -ne 0) { exit 0 }

$HASH = (git rev-parse --short HEAD 2>$null).Trim()

# Log all pending prompts; only the last one (which triggered the commit) gets the hash
for ($i = 0; $i -lt $entries.Count; $i++) {
    $entryMsg = if ($entries[$i].prompt) { $entries[$i].prompt } else { "auto commit" }
    $hash = if ($i -eq $entries.Count - 1) { $HASH } else { "-" }
    [System.IO.File]::AppendAllText($LF, "| $DT | $entryMsg | $hash |`r`n", $utf8)
}
