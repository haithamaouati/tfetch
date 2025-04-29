#!/bin/bash
set -e
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/haithamaouati/tfetch/main/tfetch.sh -o "$HOME/.local/bin/tfetch"
chmod +x "$HOME/.local/bin/tfetch"
echo "Installed to ~/.local/bin/tfetch"
