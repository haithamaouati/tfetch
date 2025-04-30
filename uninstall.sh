#!/bin/bash

# uninstall.sh — Removes tfetch from Termux

set -e

SCRIPT_NAME="tfetch"
TARGET="$PREFIX/bin/$SCRIPT_NAME"

if [ -f "$TARGET" ]; then
    rm "$TARGET"
    echo "Uninstalled '$SCRIPT_NAME' from $TARGET"
else
    echo "'$SCRIPT_NAME' is not installed."
fi
