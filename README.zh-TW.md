# Clog

[Claude Code](https://claude.ai/code) 的自動 commit 與提示詞紀錄系統。

每次送出提示詞，Clog 就會自動記錄並建立一筆 git commit。執行 `git reset` 回朔時，Clog 會偵測到並將受影響的紀錄以刪除線標記。

## 功能

- 每次 Claude 回應後自動 git commit
- Commit 訊息格式：`[YYYY-MM-DD HH:MM] 你的提示詞`
- 將每筆提示詞記錄至 `PROMPT_LOG.md`
- 偵測 `git reset`，並將回朔的紀錄標示為 `~~刪除線~~`
- 回朔時自動附加 `[RESET]` 標記列
- 適用於任何專案，無硬編碼路徑

## 系統需求

- [Claude Code](https://claude.ai/code)
- [Node.js](https://nodejs.org)
- Git

> 僅支援 Windows（使用 PowerShell 與 .bat）

## 安裝

```
git clone https://github.com/jervey1006/Clog.git
```

然後雙擊 `install.bat`。

完成。Clog 會自動套用至所有 Claude Code 專案。

> 安裝後請重新啟動 Claude Code 以啟用 hooks。
> 若已有 `settings.json`，Clog hooks 會合併寫入，不會覆蓋既有設定。

## 運作原理

| Hook | 腳本 | 說明 |
|---|---|---|
| `UserPromptSubmit` | `read_prompt.js` | 將提示詞內容與當前 git HEAD 寫入暫存檔 |
| `Stop` | `auto_commit.ps1` | 偵測回朔、更新紀錄、執行 commit |

兩個腳本會安裝至 `%USERPROFILE%\.claude\` 並註冊為全域 hooks，所有專案皆自動生效。

首次使用時會自動建立 `PROMPT_LOG.md` 與 `.gitignore`。

## 解除安裝

雙擊 `uninstall.bat`。

會移除 Clog 的腳本，並從全域 `settings.json` 中移除對應 hooks，其餘既有設定不受影響。

解除安裝後請重新啟動 Claude Code。

## PROMPT_LOG.md 範例

| 時間 | 提示詞 | Commit Hash |
|:---|:---|:---|
| 2026-03-23 10:00 | 新增玩家移動功能 | a1b2c3d |
| 2026-03-23 10:05 | 修正跳躍 bug | e4f5g6h |
| ~~2026-03-23 10:10~~ | ~~糟糕的方向~~ | ~~i7j8k9l~~ |
| 2026-03-23 10:12 | [RESET] [e4f5g6h] | - |
| 2026-03-23 10:15 | 換個方式重新嘗試 | m1n2o3p |
