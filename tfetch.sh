#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.

# Style
clear="\e[0m"
bold="\e[1m"
underline="\e[4m"

# Help
show_help() {
    echo -e "\n${bold}tfetch${clear}"
    echo -e "A tiny system info script for Termux, written in pure Bash.\n"
    echo -e " Author: Haitham Aouati"
    echo -e " GitHub: ${underline}github.com/haithamaouati${clear}"
    echo
    echo "Usage: tfetch [OPTIONS]"
    echo
    echo "Options:"
    echo "  -c, --clear      clear the terminal screen before displaying info"
    echo "  -p, --palette    Show the terminal color palette"
    echo "  -t, --tux        Use Tux ASCII art (default)"
    echo "  -a, --android    Use Android ASCII art"
    echo "  -d, --datetime   Show current date and time"
    echo "  -h, --help       Show this help message and exit"
    exit 0
}

# Flags
SHOW_PALETTE=false
SHOW_DATETIME=false
ASCII_MODE="tux"

for arg in "$@"; do
    case "$arg" in
        -c|--clear) printf "\033c" ;;
        -p|--palette) SHOW_PALETTE=true ;;
        -t|--tux) ASCII_MODE="tux" ;;
        -a|--android) ASCII_MODE="android" ;;
        -d|--datetime) SHOW_DATETIME=true ;;
        -h|--help) show_help ;;
    esac
done

# System info
username=$(whoami 2>/dev/null || echo "unknown")
hostun=$(hostname 2>/dev/null || echo "localhost")
os=$(uname -o 2>/dev/null || echo "unknown")
host=$(uname -m 2>/dev/null || echo "unknown")
kernel=$(uname -r 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
uptime=$(uptime -s 2>/dev/null || echo "unknown")

if command -v dpkg >/dev/null 2>&1; then
    pkgs=$(dpkg -l | grep -c "^ii")
else
    pkgs="?"
fi

if command -v free >/dev/null 2>&1; then
    memory=$(free -m | awk '/Mem/{print $2}')
else
    memory=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}')
fi
memory=${memory:-"?"}

# Color palette
print_colors() {
    local indent=$1
    printf "%${indent}s" " "
    for i in {0..7}; do
        printf "\e[48;5;%sm  \e[0m" "$i"
    done
    echo
    printf "%${indent}s" " "
    for i in {8..15}; do
        printf "\e[48;5;%sm  \e[0m" "$i"
    done
    echo
}

# Output
echo
if [ "$ASCII_MODE" = "tux" ]; then
    printf "     ___    ${bold}%s@%s${clear}\n" "$username" "$hostun"
    printf "    (.· |   ${bold}os     ${clear}%s\n" "$os"
    printf "    (<> |   ${bold}host   ${clear}%s\n" "$host"
    printf "   / __  \\  ${bold}kernel ${clear}%s\n" "$kernel"
    printf "  ( /  \\ /| ${bold}uptime ${clear}%s\n" "$uptime"
    printf " _/\\ __)/_) ${bold}pkgs   ${clear}%s\n" "$pkgs"
    printf " \\/-____\\/  ${bold}memory ${clear}%sMB\n" "$memory"

    if $SHOW_DATETIME; then
        datetime=$(date '+%Y-%m-%d %H:%M:%S')
        printf "            ${bold}date${clear}   %s\n" "$datetime"
    fi

    PALETTE_INDENT=12
else
    printf "                    ${bold}%s@%s${clear}\n" "$username" "$hostun"
    printf "  ;,           ,;   ${bold}os     ${clear}%s\n" "$os"
    printf "   ';,.-----.,;'    ${bold}host   ${clear}%s\n" "$host"
    printf "  ,'           ',   ${bold}kernel ${clear}%s\n" "$kernel"
    printf " /    O     O    \\  ${bold}uptime ${clear}%s\n" "$uptime"
    printf "|                 | ${bold}pkgs   ${clear}%s\n" "$pkgs"
    printf "'-----------------' ${bold}memory ${clear}%sMB\n" "$memory"

    if $SHOW_DATETIME; then
        datetime=$(date '+%Y-%m-%d %H:%M:%S')
        printf "                    ${bold}date${clear}   %s\n" "$datetime"
    fi

    PALETTE_INDENT=20
fi

# Color palette printing with dynamic indent
if $SHOW_PALETTE; then
    echo
    print_colors "$PALETTE_INDENT"
fi

echo
