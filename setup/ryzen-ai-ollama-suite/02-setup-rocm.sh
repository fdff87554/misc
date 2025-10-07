#!/usr/bin/env bash
#
# Install AMD ROCm GPU drivers and runtime for AI workloads
# This script requires reboot after driver installation
#

set -euo pipefail

# --- Auto-detect System Information ---

# Detect Ubuntu codename and version
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    UBUNTU_CODENAME="${VERSION_CODENAME:-noble}"
    UBUNTU_VERSION="${VERSION_ID:-24.04}"
else
    echo "Warning: /etc/os-release not found, using defaults" >&2
    UBUNTU_CODENAME="noble"
    UBUNTU_VERSION="24.04"
fi
readonly UBUNTU_CODENAME
readonly UBUNTU_VERSION

# Detect system architecture
SYSTEM_ARCH=$(dpkg --print-architecture)
readonly SYSTEM_ARCH

# --- Constants ---

readonly ROCM_VERSION="7.0.1"
readonly ROCM_GPG_KEY_URL="https://repo.radeon.com/rocm/rocm.gpg.key"
readonly ROCM_KEYRING="/etc/apt/keyrings/rocm.gpg"

# AMDGPU driver version mapping based on Ubuntu version
case "${UBUNTU_VERSION}" in
    24.04)
        AMDGPU_VERSION="6.2.4"
    ;;
    22.04)
        AMDGPU_VERSION="6.1.3"
    ;;
    20.04)
        AMDGPU_VERSION="6.0.2"
    ;;
    *)
        AMDGPU_VERSION="6.2.4"
        echo "Warning: Unknown Ubuntu version ${UBUNTU_VERSION}, using AMDGPU ${AMDGPU_VERSION}" >&2
    ;;
esac
readonly AMDGPU_VERSION

# --- Pre-flight Checks ---

if [[ ${EUID} -eq 0 ]]; then
    echo "Error: Do not run as root" >&2
    exit 1
fi

if ! command -v apt &>/dev/null; then
    echo "Error: This script requires apt package manager (Debian/Ubuntu)" >&2
    exit 1
fi

# --- System Information ---

echo "System Information:"
echo "==================="
echo "OS:           Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"
echo "Architecture: ${SYSTEM_ARCH}"
KERNEL_VERSION=$(uname -r)
echo "Kernel:       ${KERNEL_VERSION}"
echo ""
echo "ROCm Version:   ${ROCM_VERSION}"
echo "AMDGPU Version: ${AMDGPU_VERSION}"
echo ""

# --- Stage 1: Prerequisites and Permissions ---

echo "Installing prerequisites..."
sudo apt update
sudo apt install -y python3-setuptools python3-wheel wget gpg

echo "Current user groups:"
groups

echo "Adding user to video and render groups..."
sudo usermod -a -G video,render "${LOGNAME}"

echo ""
echo "==========================================="
echo "IMPORTANT: Group changes require re-login"
echo "==========================================="
echo "After this script completes:"
echo "1. Log out and log back in (or reboot)"
echo "2. Verify groups with: groups"
echo "3. Continue to driver installation"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to exit..."

# --- Stage 2: AMD GPU Kernel Driver Installation ---

echo ""
echo "Installing kernel headers..."
KERNEL_VERSION=$(uname -r)
sudo apt install -y "linux-headers-${KERNEL_VERSION}" "linux-modules-extra-${KERNEL_VERSION}"

# Setup ROCm repository key (shared for both AMDGPU and ROCm)
if [[ ! -f "${ROCM_KEYRING}" ]]; then
    echo "Setting up ROCm repository key..."
    sudo mkdir -p --mode=0755 /etc/apt/keyrings
    wget "${ROCM_GPG_KEY_URL}" -O - | \
    gpg --dearmor | sudo tee "${ROCM_KEYRING}" > /dev/null
else
    echo "ROCm repository key already exists"
fi

# Register AMDGPU kernel driver repository
echo "Registering AMDGPU driver repository..."

# Determine repository architecture based on system
if [[ "${SYSTEM_ARCH}" == "arm64" ]]; then
    REPO_ARCH="arm64"
    echo "Note: Using arm64 repository"
else
    REPO_ARCH="amd64,i386"
fi

sudo tee /etc/apt/sources.list.d/amdgpu.list > /dev/null << EOF
deb [arch=${REPO_ARCH} signed-by=${ROCM_KEYRING}] https://repo.radeon.com/amdgpu/${AMDGPU_VERSION}/ubuntu ${UBUNTU_CODENAME} main
EOF

sudo apt update

# Check if driver already installed
if dpkg -l | grep -q amdgpu-dkms; then
    echo "AMDGPU driver already installed"
else
    echo "Installing AMDGPU kernel driver..."
    sudo apt install -y amdgpu-dkms
    
    echo ""
    echo "==========================================="
    echo "DRIVER INSTALLATION COMPLETE"
    echo "==========================================="
    echo "REQUIRED: System reboot needed for driver to load"
    echo ""
    echo "After reboot:"
    echo "1. Verify driver: sudo dkms status"
    echo "2. Check GPU: lspci | grep -i vga"
    echo "3. Run this script again to continue ROCm installation"
    echo ""
    echo "Reboot now? (y/n)"
    read -r response
    if [[ "${response}" =~ ^[Yy]$ ]]; then
        echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        sudo reboot
    else
        echo "Please reboot manually before continuing"
        exit 0
    fi
fi

# Verify driver is loaded
echo "Verifying AMDGPU driver..."
if ! sudo dkms status | grep -q amdgpu; then
    echo "Error: AMDGPU driver not found. Please reboot and try again." >&2
    exit 1
fi
sudo dkms status

# --- Stage 3: ROCm Runtime Installation ---

echo ""
echo "Installing ROCm runtime..."

# Register ROCm runtime repository
sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null << EOF
deb [arch=${SYSTEM_ARCH} signed-by=${ROCM_KEYRING}] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${UBUNTU_CODENAME} main
deb [arch=${SYSTEM_ARCH} signed-by=${ROCM_KEYRING}] https://repo.radeon.com/graphics/${ROCM_VERSION}/ubuntu ${UBUNTU_CODENAME} main
EOF

# Set ROCm package priority
sudo tee /etc/apt/preferences.d/rocm-pin-600 > /dev/null << EOF
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF

sudo apt update

if command -v rocminfo &>/dev/null; then
    ROCM_VER=$(rocminfo --version 2>&1 | head -1 || echo 'unknown')
    echo "ROCm already installed: ${ROCM_VER}"
else
    echo "Installing ROCm..."
    sudo apt install -y rocm rocm-opencl-runtime
fi

# --- Stage 4: Environment Configuration ---

echo ""
echo "Configuring ROCm environment..."

# Configure shared libraries
if [[ ! -f /etc/ld.so.conf.d/rocm.conf ]]; then
    sudo tee /etc/ld.so.conf.d/rocm.conf > /dev/null << EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF
    sudo ldconfig
else
    echo "ROCm library configuration already exists"
fi

# Configure PATH via update-alternatives
sudo update-alternatives --display rocm || true

# Add ROCm to user profile if not already present
ROCM_ENV_CONFIG="${HOME}/.rocm_env"
if [[ ! -f "${ROCM_ENV_CONFIG}" ]]; then
    cat > "${ROCM_ENV_CONFIG}" << 'EOF'
# ROCm Environment Configuration
export PATH=/opt/rocm/bin:${PATH}
export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
EOF
    
    # Add source to .bashrc if not present
    if ! grep -q ".rocm_env" "${HOME}/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# ROCm Configuration"
            echo "[[ -f ~/.rocm_env ]] && source ~/.rocm_env"
        } >> "${HOME}/.bashrc"
    fi
    
    echo "ROCm environment configuration added to ~/.rocm_env"
    echo "Source it now for current session:"
    echo "  source ~/.rocm_env"
fi

# Source for current session
# shellcheck source=/dev/null
[[ -f "${ROCM_ENV_CONFIG}" ]] && source "${ROCM_ENV_CONFIG}"

# --- Stage 5: AMD SMI Installation ---

echo ""
echo "Installing AMD System Management Interface..."

AMDGPU_INSTALL_DEB="amdgpu-install_${ROCM_VERSION}.70001-1_all.deb"
if ! command -v amd-smi &>/dev/null; then
    wget "https://repo.radeon.com/amdgpu-install/latest/ubuntu/${UBUNTU_CODENAME}/${AMDGPU_INSTALL_DEB}" -O "/tmp/${AMDGPU_INSTALL_DEB}"
    sudo apt install -y "/tmp/${AMDGPU_INSTALL_DEB}"
    rm -f "/tmp/${AMDGPU_INSTALL_DEB}"
    
    sudo amdgpu-install --usecase=rocm
else
    echo "AMD SMI already installed"
fi

# --- Verification ---

echo ""
echo "Verifying ROCm installation..."
echo ""

if command -v rocminfo &>/dev/null; then
    echo "ROCm Info:"
    rocminfo | head -20
else
    echo "Warning: rocminfo not found" >&2
fi

echo ""
if command -v clinfo &>/dev/null; then
    echo "OpenCL Info:"
    clinfo | head -10
else
    echo "Warning: clinfo not found" >&2
fi

echo ""
if command -v amd-smi &>/dev/null; then
    echo "AMD SMI:"
    amd-smi version || amd-smi --help | head -5
else
    echo "Warning: amd-smi not found" >&2
fi

# --- Completion Message ---

echo ""
echo "=========================================="
echo "ROCm installation completed successfully!"
echo "=========================================="
echo ""
echo "Verification commands:"
echo "  rocminfo              - ROCm system information"
echo "  clinfo                - OpenCL information"
echo "  amd-smi               - GPU monitoring"
echo "  rocm-smi              - Alternative GPU monitoring"
echo ""
echo "Environment:"
echo "  ROCm is configured in ~/.rocm_env"
echo "  Restart your shell or run: source ~/.bashrc"
echo ""
