#!/bin/bash
#
# One-shot system update for apt-based distros (Ubuntu / Debian / Kali):
# update, full-upgrade, autoremove, autoclean, then report what is still
# pending and whether a reboot is needed.
#
# Install:
#   sudo curl -fsSL https://raw.githubusercontent.com/fdff87554/misc/main/scripts/sys-update.sh \
#     -o /usr/local/bin/sys-update && sudo chmod 755 /usr/local/bin/sys-update
# Usage:
#   sys-update                # interactive (normal terminal)
#   ssh host sys-update       # no TTY: non-interactive, keeps existing config files

set -euo pipefail

# --- Pre-flight Checks ---
if ! command -v apt-get >/dev/null 2>&1; then
    echo "Error: apt-get not found; only apt-based distros are supported." >&2
    exit 1
fi

SUDO=()
[[ "$(id -u)" -ne 0 ]] && SUDO=(sudo)

# Without a TTY, debconf cannot prompt: answer non-interactively and keep
# locally modified config files instead of failing or overwriting them.
APT_ENV=()
APT_OPTS=(-y)
if [[ ! -t 0 ]]; then
    APT_ENV=(DEBIAN_FRONTEND=noninteractive)
    APT_OPTS+=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
fi

apt_run() {
    "${SUDO[@]}" env "${APT_ENV[@]}" apt-get "$@"
}

# --- Update ---
apt_run update
apt_run "${APT_OPTS[@]}" full-upgrade
apt_run "${APT_OPTS[@]}" autoremove
apt_run autoclean

# --- Report ---
# Packages left here are usually phased updates or ones whose new
# dependencies are not published yet; apt keeps them back on purpose.
pending=$(apt list --upgradable 2>/dev/null | tail -n +2)
if [[ -n "$pending" ]]; then
    echo
    echo "== 尚未升級（多為分批推送或相依套件尚未發布，通常不用處理，之後再跑一次即可）："
    echo "$pending"
fi

echo
if [[ -f /var/run/reboot-required ]]; then
    # Ubuntu/Debian flag this for kernel, libc, systemd, etc.
    pkgs=$(sort -u /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' ')
    echo "== 需要重開機${pkgs:+（$pkgs）}"
elif compgen -G '/boot/vmlinuz-*' >/dev/null; then
    newest=$(find /boot -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sed 's/^vmlinuz-//' | sort -V | tail -1)
    if [[ "$(uname -r)" != "$newest" ]]; then
        echo "== 需要重開機：kernel $(uname -r) → $newest"
    else
        echo "== 完成，不需要重開機"
    fi
else
    # No kernel in /boot (e.g. OrbStack / containers): the host manages it.
    echo "== 完成（kernel 由宿主管理，不需重開機）"
fi
