#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-05-09

set -euo pipefail

# Style - readonly constants
readonly CLEAR="\e[0m"
readonly BOLD="\e[1m"
readonly UNDERLINE="\e[4m"

# Help function
show_help() {
    echo -e "\n${BOLD}tfetch${CLEAR}"
    echo -e "A tiny system info script for Termux, written in pure Bash.\n"
    echo -e " Author: Haitham Aouati"
    echo -e " GitHub: ${UNDERLINE}github.com/haithamaouati${CLEAR}"
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

# Parse command-line flags
SHOW_PALETTE=false
SHOW_DATETIME=false
ASCII_MODE="tux"

for arg in "$@"; do
    case "$arg" in
        -c|--clear)     printf "\033c" ;;
        -p|--palette)   SHOW_PALETTE=true ;;
        -t|--tux)       ASCII_MODE="tux" ;;
        -a|--android)   ASCII_MODE="android" ;;
        -d|--datetime)  SHOW_DATETIME=true ;;
        -h|--help)      show_help ;;
        *)              echo "Unknown option: $arg" >&2; show_help ;;
    esac
done

# Gather system information
username=$(whoami 2>/dev/null || echo "unknown")
hostun=$(hostname 2>/dev/null || echo "localhost")
os=$(uname -o 2>/dev/null || echo "unknown")
host=$(uname -m 2>/dev/null || echo "unknown")
kernel=$(uname -r 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
uptime=$(uptime -s 2>/dev/null || echo "unknown")

# Get package count
if command -v dpkg >/dev/null 2>&1; then
    pkgs=$(dpkg -l 2>/dev/null | grep -c "^ii" || echo "?")
else
    pkgs="?"
fi

# Get memory info
if command -v free >/dev/null 2>&1; then
    memory=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "?")
else
    memory=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}' || echo "?")
fi
memory=${memory:-"?"}

# Get datetime if requested (avoid duplicating logic)
if $SHOW_DATETIME; then
    datetime=$(date '+%Y-%m-%d %H:%M:%S')
fi

# Print color palette function
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

# Print system info output
print_system_info() {
    local palette_indent=$1
    
    echo
    if [ "$ASCII_MODE" = "tux" ]; then
        printf "     ___    ${BOLD}%s@%s${CLEAR}\n" "$username" "$hostun"
        printf "    (.· |   ${BOLD}os     ${CLEAR}%s\n" "$os"
        printf "    (<> |   ${BOLD}host   ${CLEAR}%s\n" "$host"
        printf "   / __  \\  ${BOLD}kernel ${CLEAR}%s\n" "$kernel"
        printf "  ( /  \\ /| ${BOLD}uptime ${CLEAR}%s\n" "$uptime"
        printf " _/\\ __)/_) ${BOLD}pkgs   ${CLEAR}%s\n" "$pkgs"
        printf " \\/-____\\/  ${BOLD}memory ${CLEAR}%sMB\n" "$memory"

        if $SHOW_DATETIME; then
            printf "            ${BOLD}date${CLEAR}   %s\n" "$datetime"
        fi
    else
        printf "                    ${BOLD}%s@%s${CLEAR}\n" "$username" "$hostun"
        printf "  ;,           ,;   ${BOLD}os     ${CLEAR}%s\n" "$os"
        printf "   ';,.-----.,;'    ${BOLD}host   ${CLEAR}%s\n" "$host"
        printf "  ,'           ',   ${BOLD}kernel ${CLEAR}%s\n" "$kernel"
        printf " /    O     O    \\  ${BOLD}uptime ${CLEAR}%s\n" "$uptime"
        printf "|                 | ${BOLD}pkgs   ${CLEAR}%s\n" "$pkgs"
        printf "'-----------------' ${BOLD}memory ${CLEAR}%sMB\n" "$memory"

        if $SHOW_DATETIME; then
            printf "                    ${BOLD}date${CLEAR}   %s\n" "$datetime"
        fi
    fi
    
    # Print color palette if requested
    if $SHOW_PALETTE; then
        echo
        print_colors "$palette_indent"
    fi
    
    echo
}

# Determine palette indent and print output
if [ "$ASCII_MODE" = "tux" ]; then
    print_system_info 12
else
    print_system_info 20
fi
