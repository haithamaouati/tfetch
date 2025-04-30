#!/bin/bash

# uninstall.sh — Removes tfetch from Termux

set -e

TARGET="$PREFIX/bin/tfetch"

if [ -f "$TARGET" ]; then
    rm "$TARGET"
    echo "Uninstalled 'tfetch' from $TARGET"
else
    echo "'tfetch' is not installed."
fi
