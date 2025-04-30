#!/bin/bash

# install.sh — Installs tfetch in Termux

set -e

SCRIPT_NAME="tfetch"
TARGET="$PREFIX/bin/$SCRIPT_NAME"

# Ensure bin directory exists
mkdir -p "$PREFIX/bin"

# Copy tfetch to bin and make it executable
cp "$SCRIPT_NAME" "$TARGET"
chmod +x "$TARGET"

echo "Installed '$SCRIPT_NAME' to $TARGET"
echo "You can now run it with: $SCRIPT_NAME"
