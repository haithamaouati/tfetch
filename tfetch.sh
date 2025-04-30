#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: a tiny system info for Termux env.

# Style
CLEAR="\e[0m"
BOLD="\e[1m"
UNDERLINE="\e[4m"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"

# If "--clear" passed, clear the screen (fast, no dependency)
[[ "$1" == "--clear" ]] && printf "\033c"

# System info with fallbacks
username=$(whoami 2>/dev/null || echo "unknown")
hostun=$(hostname 2>/dev/null || echo "localhost")
os=$(uname -o 2>/dev/null || echo "unknown")
host=$(uname -m 2>/dev/null || echo "unknown")
kernel=$(uname -r 2>/dev/null || echo "unknown")
uptime=$(uptime -p 2>/dev/null || echo "unknown")

# Packages (Debian-like only)
if command -v dpkg >/dev/null 2>&1; then
    pkgs=$(dpkg -l | grep -c "^ii")
else
    pkgs="?"
fi

# Memory (fallback to /proc if 'free' not present)
if command -v free >/dev/null 2>&1; then
    memory=$(free -m | awk '/Mem/{print $2}')
else
    memory=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}')
fi
memory=${memory:-"?"}

# Output
printf "     ___    ${BOLD}%s@%s${CLEAR}\n" "$username" "$hostun"
printf "    (.· |   ${BOLD}os     ${CLEAR}%s\n" "$os"
printf "    (<> |   ${BOLD}host   ${CLEAR}%s\n" "$host"
printf "   / __  \\  ${BOLD}kernel ${CLEAR}%s\n" "$kernel"
printf "  ( /  \\ /| ${BOLD}uptime ${CLEAR}%s\n" "$uptime"
printf " _/\\ __)/_) ${BOLD}pkgs   ${CLEAR}%s\n" "$pkgs"
printf " \\/-____\\/  ${BOLD}memory ${CLEAR}%sMB\n\n" "$memory"
