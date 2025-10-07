#!/usr/bin/env bash
#
# Configure Git global settings
#

set -euo pipefail

# --- Constants ---

readonly GIT_USER_EMAIL="me@crazyfirelee.tw"
readonly GIT_USER_NAME="Crazyfire Lee"
readonly GIT_EDITOR="vim"

# --- Pre-flight Check ---

if ! command -v git &>/dev/null; then
    echo "Error: Git is not installed. Please install git first." >&2
    exit 1
fi

# --- User Configuration ---

echo "Configuring Git user settings..."
git config --global user.email "${GIT_USER_EMAIL}"
git config --global user.name "${GIT_USER_NAME}"

# --- Preferences ---

echo "Configuring Git preferences..."
git config --global color.ui true
git config --global core.editor "${GIT_EDITOR}"

# --- Aliases ---

echo "Configuring Git aliases..."
git config --global alias.co commit
git config --global alias.lg "log --color --graph --all --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --"
git config --global alias.supdate "submodule update --init --recursive"
git config --global alias.supdate-remote "submodule update --remote --rebase"
git config --global alias.sstatus "submodule status"

# --- Verification ---

echo ""
echo "Git configuration completed successfully"
echo ""
echo "Current settings:"
echo "  User Name:  $(git config --global user.name || true)"
echo "  User Email: $(git config --global user.email || true)"
echo "  Editor:     $(git config --global core.editor || true)"
echo "  Color UI:   $(git config --global color.ui || true)"
echo ""
