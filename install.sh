#!/bin/bash

# install.sh — Installs tfetch in Termux

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/tfetch.sh"
PREFIX="${PREFIX:=/data/data/com.termux/files/usr}"
TARGET="$PREFIX/bin/tfetch"

# Verify source file exists
if [ ! -f "$SOURCE" ]; then
  echo "Error: $SOURCE not found" >&2
  exit 1
fi

# Ensure bin directory exists
mkdir -p "$PREFIX/bin" || { echo "Error: Failed to create $PREFIX/bin" >&2; exit 1; }

# Copy and rename tfetch.sh -> tfetch in $PREFIX/bin
echo "Installing tfetch from $SOURCE to $TARGET..."
cp "$SOURCE" "$TARGET" || { echo "Error: Failed to copy file" >&2; exit 1; }
chmod +x "$TARGET" || { echo "Error: Failed to make $TARGET executable" >&2; exit 1; }

echo "Successfully installed tfetch to $TARGET"
echo "You can now run it with: tfetch"
