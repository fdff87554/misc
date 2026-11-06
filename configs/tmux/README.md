# tmux Setup

搭配 Ghostty 與 [vim 設定](../vim/) 的 `.tmux.conf`。需要 tmux 3.2 以上（Ubuntu 22.04+ / Debian 12+ / Kali / Homebrew）。

## Installation

- macOS：`brew install tmux`
- Ubuntu / Debian / Kali：`sudo apt install tmux`

## Personal `.tmux.conf` setup

這是一份完整、帶有個人偏好的設定（見下方「設定內容」），不只是 true color。下載到獨立檔案，再由既有的 `~/.tmux.conf` 載入，不會覆寫原本的設定；`source-file` 這行加在檔案最後，所以會覆蓋前面的同名設定，個人覆寫請寫在它之後。重複執行只會更新共用檔，不會重複加入 `source-file`。

```bash
mkdir -p ~/.config/tmux
curl -fsSL https://raw.githubusercontent.com/fdff87554/misc/main/configs/tmux/.tmux.conf \
  -o ~/.config/tmux/misc.conf
grep -qxF 'source-file ~/.config/tmux/misc.conf' ~/.tmux.conf 2>/dev/null ||
  echo 'source-file ~/.config/tmux/misc.conf' >>~/.tmux.conf
# 已在執行中的 tmux 重新載入
tmux source-file ~/.tmux.conf
```

## 設定內容

| 設定 | 說明 |
| --- | --- |
| `mouse on` | 滑鼠捲動、選取、切換 pane |
| `history-limit 50000` | scrollback 上限（預設 2000） |
| `escape-time 10` | vim 按 Esc 不延遲（tmux 3.4 以前預設 500ms） |
| `focus-events on` | 讓 vim 切回視窗時自動重讀被外部修改的檔案 |
| `mode-keys vi` | copy-mode 使用 vi 按鍵 |
| `base-index 1` 等 | 視窗 / pane 從 1 開始編號，關閉後自動重新編號 |
| `default-terminal` + `terminal-features` | pane 內 true color；告訴 tmux 外層 Ghostty 支援 RGB 與剪貼簿 |
| `COLORTERM truecolor` | 讓 pane 內的 vim 啟用 `termguicolors` |
| `set-clipboard on` | copy-mode 與 vim 的 OSC52 選取同步到系統剪貼簿 |

## 驗證

| 檢查 | 指令 | 預期 |
| --- | --- | --- |
| true color | `tmux info \| grep RGB` | `RGB: (flag) true` |
| 剪貼簿 | 滑鼠拖曳選取後放開，在 Mac 貼上 | 內容一致 |
