#!/bin/bash

# uninstall.sh — Removes tfetch from Termux

set -euo pipefail

TARGET="$PREFIX/bin/tfetch"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display error messages
error() {
    echo "Error: $*" >&2
    exit 1
}

# Check if running in Termux environment
if [ -z "$PREFIX" ]; then
    error "PREFIX variable is not set. Are you running in Termux?"
fi

# Check if tfetch is installed
if [ -f "$TARGET" ]; then
    # Attempt to remove the file
    if rm "$TARGET" 2>/dev/null; then
        echo "Successfully uninstalled 'tfetch' from $TARGET"
    else
        error "Failed to remove '$TARGET'. Do you have permission to delete it?"
    fi
else
    echo "ℹ 'tfetch' is not installed at $TARGET"
fi

# Optional: Clean up any related files/directories
# Uncomment if you have config files or cache to clean
# CONFIG_DIR="$HOME/.config/tfetch"
# if [ -d "$CONFIG_DIR" ]; then
#     rm -rf "$CONFIG_DIR"
#     echo "Cleaned up config directory"
# fi
