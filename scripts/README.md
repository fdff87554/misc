# Scripts

| Script | 用途 |
| --- | --- |
| `sys-update.sh` | apt 系統（Ubuntu / Debian / Kali）一鍵更新與重開機檢查 |
| `mirror-replace.sh` / `mirror-replace-improved.sh` | 將 APT 來源換成指定 mirror（improved 版自動判斷 amd64 / arm64） |

## sys-update

```bash
# 安裝（之後重跑同一段即可更新；先下載到暫存檔，成功後才取代，避免中斷時留下不完整的腳本）
sudo sh -c 'curl -fsSL https://raw.githubusercontent.com/fdff87554/misc/main/scripts/sys-update.sh \
  -o /usr/local/bin/sys-update.tmp && chmod 755 /usr/local/bin/sys-update.tmp &&
  mv /usr/local/bin/sys-update.tmp /usr/local/bin/sys-update'

sys-update                 # 本機執行
ssh -t host sys-update     # 遠端執行（-t 保留互動；不加 -t 則自動非互動，設定檔衝突時保留現有版本）
```

流程：`update` → `full-upgrade` → `autoremove` → `autoclean`，最後回報：

- **尚未升級的套件**：多為分批推送（phased updates）或相依套件尚未發布，apt 會刻意保留，通常不用處理。
- **是否需要重開機**：優先依 `/var/run/reboot-required`（kernel、libc、systemd 等更新時出現），否則比對 `/boot` 內最新 kernel 與執行中的版本；`/boot` 內沒有 kernel（OrbStack、container）時略過。

機器專屬的步驟（例如更新 CLI 工具）請放在本機的 wrapper，先呼叫 `sys-update` 再接自己的指令。
