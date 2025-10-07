#!/usr/bin/env bash
#
# Setup base development environment for Debian-based Linux systems
#

set -euo pipefail

# --- Pre-flight Checks ---

if [[ ${EUID} -eq 0 ]]; then
    echo "Error: Do not run as root" >&2
    exit 1
fi

if ! command -v apt &>/dev/null; then
    echo "Error: This script requires apt package manager (Debian/Ubuntu)" >&2
    exit 1
fi

# --- System Update and Package Installation ---

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y

echo "Installing essential packages..."
sudo apt install -y git vim curl wget tmux openssh-server

# --- SSH Configuration ---

echo "Configuring SSH..."

if [[ ! -f /etc/ssh/sshd_config.backup ]]; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
fi

sudo sed -i \
-e 's/^#*PermitRootLogin.*/PermitRootLogin no/' \
-e 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' \
-e 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' \
/etc/ssh/sshd_config

if command -v systemctl &>/dev/null; then
    sudo systemctl restart ssh && sudo systemctl enable ssh
fi

# --- Docker Installation ---

if command -v docker &>/dev/null; then
    echo "Docker is already installed: $(docker --version || true)"
else
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "${USER}"
    rm -f get-docker.sh
    echo "Docker installation completed"
fi

# --- Verification ---

echo ""
echo "Verifying installations..."

for cmd in git vim curl wget tmux docker; do
    if command -v "${cmd}" &>/dev/null; then
        echo "  [OK] ${cmd}"
    else
        echo "  [FAIL] ${cmd}" >&2
    fi
done

# --- Completion Message ---

echo ""
echo "=========================================="
echo "Environment setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Reboot your system to apply all changes"
echo "2. Verify docker access: docker run hello-world"
echo "3. Configure SSH keys in ~/.ssh/authorized_keys if needed"
echo ""
