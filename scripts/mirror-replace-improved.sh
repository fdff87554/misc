#!/bin/bash
#
# Automatically detects system architecture (amd64/arm64) and replaces the
# APT source with a specified mirror, ensuring the setting is permanent.
# Version: 2.1 (Multi-Arch, Simplified)

set -eu

# --- Configuration ---
NEW_MIRROR_BASE_URI="https://mirror.twds.com.tw"

# --- Helper Functions ---
replace_mirrors() {
    local file="$1"
    local format="$2"
    
    if [ "$format" = "deb822" ]; then
        # Direct replacement for DEB822 format
        for pattern in "${DEFAULT_MIRROR_PATTERNS[@]}"; do
            sed -i "s|$pattern|$NEW_MIRROR_URI|g" "$file"
        done
    else
        # Use sed for legacy format (simpler approach)
        for pattern in "${DEFAULT_MIRROR_PATTERNS[@]}"; do
            sed -i "s|$pattern|$NEW_MIRROR_URI|g" "$file"
        done
    fi
}

# --- Pre-flight Checks ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# --- Detect APT Configuration ---
SOURCES_FILE=""
FILE_FORMAT=""

if [ -f "/etc/apt/sources.list.d/ubuntu.sources" ]; then
    SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
    FILE_FORMAT="deb822"
    echo "Info: Detected DEB822 format (Ubuntu 24.04+)"
elif [ -f "/etc/apt/sources.list" ]; then
    SOURCES_FILE="/etc/apt/sources.list"
    FILE_FORMAT="legacy"
    echo "Info: Detected legacy format (Ubuntu 22.04 and earlier)"
else
    echo "Error: No APT source file found." >&2
    exit 1
fi

# --- Architecture Configuration ---
ARCH=$(dpkg --print-architecture)
DEFAULT_MIRROR_PATTERNS=()
NEW_MIRROR_URI=""

case "$ARCH" in
    arm64)
        echo "Info: Detected arm64 architecture."
        DEFAULT_MIRROR_PATTERNS=(
            "http://ports.ubuntu.com/ubuntu-ports"
            "https://ports.ubuntu.com/ubuntu-ports"
        )
        NEW_MIRROR_URI="${NEW_MIRROR_BASE_URI}/ubuntu-ports"
    ;;
    amd64)
        echo "Info: Detected amd64 architecture."
        DEFAULT_MIRROR_PATTERNS=(
            "http://archive.ubuntu.com/ubuntu"
            "https://archive.ubuntu.com/ubuntu"
            "http://[a-z][a-z].archive.ubuntu.com/ubuntu"
            "https://[a-z][a-z].archive.ubuntu.com/ubuntu"
            "http://security.ubuntu.com/ubuntu"
            "https://security.ubuntu.com/ubuntu"
        )
        NEW_MIRROR_URI="${NEW_MIRROR_BASE_URI}/ubuntu"
    ;;
    *)
        echo "Error: Unsupported architecture '$ARCH'." >&2
        exit 1
    ;;
esac

# --- Check if replacement needed ---
needs_replacement=false
for pattern in "${DEFAULT_MIRROR_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$SOURCES_FILE"; then
        needs_replacement=true
        break
    fi
done

if ! $needs_replacement; then
    echo "Info: No default mirrors found. Already using custom mirror."
    exit 0
fi

# --- Core Operations ---
echo "Updating APT source mirror for $ARCH..."

# Prevent cloud-init from overwriting
CLOUD_CONFIG="/etc/cloud/cloud.cfg"
if [ -f "$CLOUD_CONFIG" ] && ! grep -qFx 'apt_preserve_sources_list: true' "$CLOUD_CONFIG"; then
    echo 'apt_preserve_sources_list: true' >> "$CLOUD_CONFIG"
fi

# Backup and replace
cp "$SOURCES_FILE" "${SOURCES_FILE}.bak"
replace_mirrors "$SOURCES_FILE" "$FILE_FORMAT"

# Update APT
echo "Updating APT package list..."
apt-get update

echo "Operation completed successfully."
exit 0