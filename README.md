# Clog

Auto-commit and prompt logging system for [Claude Code](https://claude.ai/code).

Every time you send a prompt, Clog records it and creates a git commit automatically. When you roll back with `git reset`, Clog detects it and marks the affected log entries with strikethrough.

## Features

- Auto git commit after every Claude response
- Commit message format: `[YYYY-MM-DD HH:MM] your prompt`
- Logs every prompt to `PROMPT_LOG.md`
- Detects `git reset` and marks rolled-back entries with `~~strikethrough~~`
- Appends a `[RESET]` marker row when rollback is detected
- Works for any project — no hardcoded paths

## Requirements

- [Claude Code](https://claude.ai/code)
- [Node.js](https://nodejs.org)
- Git

## Installation

```
git clone https://github.com/jervey1006/Clog.git
```

Then double-click `install.bat`.

That's it. Clog is now active for all Claude Code projects.

## How it works

| Hook | Script | What it does |
|---|---|---|
| `UserPromptSubmit` | `read_prompt.js` | Saves the prompt text and current git HEAD to temp files |
| `Stop` | `auto_commit.ps1` | Detects resets, updates log, commits changes |

Both scripts are installed to `%USERPROFILE%\.claude\` and registered as global hooks, so every project gets Clog automatically.

`PROMPT_LOG.md` and `.gitignore` are created automatically on first use.

## Uninstall

Double-click `uninstall.bat`.

This removes the clog scripts and its hooks from your global `settings.json`. Other existing settings are preserved.

Restart Claude Code to complete the uninstall.

## PROMPT_LOG.md example

| Time | Prompt | Commit Hash |
|:---|:---|:---|
| 2026-03-23 10:00 | add player movement | a1b2c3d |
| 2026-03-23 10:05 | fix jump bug | e4f5g6h |
| ~~2026-03-23 10:10~~ | ~~bad idea~~ | ~~i7j8k9l~~ |
| 2026-03-23 10:12 | [RESET] [e4f5g6h] | - |
| 2026-03-23 10:15 | try a different approach | m1n2o3p |
