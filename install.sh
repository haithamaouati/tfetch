#!/bin/bash

# install.sh — Installs tfetch in Termux

set -e

SOURCE="tfetch.sh"
TARGET="$PREFIX/bin/tfetch"

# Ensure bin directory exists
mkdir -p "$PREFIX/bin"

# Copy and rename tfetch.sh -> tfetch in $PREFIX/bin
cp "$SOURCE" "$TARGET"
chmod +x "$TARGET"

echo "Installed 'tfetch' to $TARGET"
echo "You can now run it with: tfetch"
