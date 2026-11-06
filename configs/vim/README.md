# Vim Setup

乾淨、可攜、無外掛的 `.vimrc`，user 與 root 共用同一份。目標 Vim 9.x（Ubuntu / Debian / Kali / macOS），搭配 Ghostty 與 [tmux 設定](../tmux/)。

## Installation

- macOS：系統內建 vim 即可（或 `brew install vim`）
- Ubuntu / Debian / Kali：`sudo apt install vim`

## Personal `.vimrc` setup

這是一份完整、帶有個人偏好的設定（見下方「重點功能」），會取代整個 `~/.vimrc`；既有檔案請先備份。

```bash
# user（既有 ~/.vimrc 先備份）
[ -f ~/.vimrc ] && cp -p ~/.vimrc ~/.vimrc.bak.$(date +%Y%m%d_%H%M%S)
curl -fsSL https://links.crazyfirelee.tw/.vimrc -o ~/.vimrc
# root（與 user 共用同一份）
sudo sh -c '[ -f /root/.vimrc ] && cp -p /root/.vimrc /root/.vimrc.bak.$(date +%Y%m%d_%H%M%S); true'
sudo curl -fsSL https://links.crazyfirelee.tw/.vimrc -o /root/.vimrc
```

## 重點功能

| 項目 | 說明 |
| --- | --- |
| 基底 | 載入 Vim 內建 `defaults.vim`（開檔跳回上次游標位置、`:DiffOrig` 等） |
| 介面 | 行號、游標行、自訂狀態列、顯示 Tab 與行尾空白、Ghostty / tmux 內啟用 true color |
| 縮排 | 預設 4 空白；YAML / JSON / Web / shell 2 空白；Makefile 真 Tab |
| swap / undo | 集中在 `~/.vim/swap`、`~/.vim/undodir`；undo 關檔後仍可復原 |
| 敏感檔案 | `*.env`、`*secret*`、`*.key`、`*.pem`、`~/.ssh/*`、`/tmp/*` 等不留 swap / undo |
| 剪貼簿 | `y` 自動同步到系統剪貼簿：macOS 用內建 clipboard，SSH / Linux 用 OSC52 |
| 拼字 | `spelllang=en,cjk`，中文不會被標成錯字；commit message 自動開啟 |

## 鍵位（Leader = 空白鍵）

| 按鍵 | 動作 |
| --- | --- |
| `<Space><Space>` | 清除搜尋反白 |
| `<Space>w` | 存檔 |
| `<Space>s` | 切換拼字檢查 |
| `<Space>l` | 切換顯示 Tab / 行尾空白 |
| `Y` | 複製到行尾 |
| `n` / `N` | 下一個 / 上一個搜尋結果並置中 |
| `Ctrl+h/j/k/l` | 切換分割視窗 |
| 視覺模式 `<` / `>` | 縮排後保持選取 |

## 注意

- map 指令同一行後面不能接 `"` 註解，會被當成按鍵的一部分；註解一律獨立成行。
- 在 tmux 內使用時，需搭配 [tmux 設定](../tmux/) 的 `focus-events`（自動重讀）、`COLORTERM`（true color）與 `set-clipboard`（OSC52）。
