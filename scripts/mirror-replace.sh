#!/usr/bin/env bash
#
# Automatically detects system architecture (amd64/arm64) and replaces the
# APT source with a specified mirror, ensuring the setting is permanent.

set -euo pipefail

# --- Constants ---

# This mirror MUST support both 'ubuntu/' and 'ubuntu-ports/' paths
readonly NEW_MIRROR_BASE_URI="https://mirror.twds.com.tw"

readonly SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
readonly CLOUD_CONFIG_FILE="/etc/cloud/cloud.cfg"


# --- Pre-flight Checks ---

if [[ ${EUID} -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

if [[ ! -f "${SOURCES_FILE}" ]]; then
    echo "Error: Source file '${SOURCES_FILE}' not found. Aborting." >&2
    exit 1
fi


# --- Architecture Detection and Configuration ---

ARCH=$(dpkg --print-architecture)
DEFAULT_MIRROR_URI=""
NEW_MIRROR_URI=""

case "${ARCH}" in
    arm64)
        echo "Info: Detected arm64 architecture."
        DEFAULT_MIRROR_URI="http://ports.ubuntu.com/ubuntu-ports"
        NEW_MIRROR_URI="${NEW_MIRROR_BASE_URI}/ubuntu-ports"
    ;;
    amd64)
        echo "Info: Detected amd64 architecture."
        # Default URI can be country-specific (e.g., tw.archive.ubuntu.com)
        # This script targets the canonical archive.ubuntu.com
        DEFAULT_MIRROR_URI="http://archive.ubuntu.com/ubuntu"
        NEW_MIRROR_URI="${NEW_MIRROR_BASE_URI}/ubuntu"
    ;;
    *)
        echo "Error: Unsupported architecture '${ARCH}'. This script only supports arm64 and amd64." >&2
        exit 1
    ;;
esac


# --- Idempotency & Sanity Checks ---

if grep -qF "${NEW_MIRROR_URI}" "${SOURCES_FILE}"; then
    echo "Info: Mirror is already set to '${NEW_MIRROR_URI}'. No changes needed."
    exit 0
fi

if ! grep -qF "${DEFAULT_MIRROR_URI}" "${SOURCES_FILE}"; then
    echo "Error: Default mirror '${DEFAULT_MIRROR_URI}' not found in ${SOURCES_FILE}." >&2
    echo "The file might have been already modified. Aborting for safety." >&2
    exit 1
fi


# --- Core Operations ---

echo "Updating APT source mirror for ${ARCH}..."

# Prevent cloud-init from overwriting changes on reboot
if [[ -f "${CLOUD_CONFIG_FILE}" ]] && ! grep -qFx 'apt_preserve_sources_list: true' "${CLOUD_CONFIG_FILE}"; then
    echo 'apt_preserve_sources_list: true' >> "${CLOUD_CONFIG_FILE}"
fi

# Backup original file with .bak extension
sed -i.bak "s|${DEFAULT_MIRROR_URI}|${NEW_MIRROR_URI}|g" "${SOURCES_FILE}"

echo "Updating APT package list..."
apt-get update

echo "Operation completed successfully."

exit 0
