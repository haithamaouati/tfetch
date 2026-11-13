#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-11-13

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
    echo "  -C, --color      Set custom bold color for info labels (0–255 or ANSI code)"
    echo "  -h, --help       Show this help message and exit"
    exit 0
}

# Parse command-line flags
SHOW_PALETTE=false
SHOW_DATETIME=false
ASCII_MODE="tux"
HEADING_COLOR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clear)     printf "\033c"; shift ;;
        -p|--palette)   SHOW_PALETTE=true; shift ;;
        -t|--tux)       ASCII_MODE="tux"; shift ;;
        -a|--android)   ASCII_MODE="android"; shift ;;
        -d|--datetime)  SHOW_DATETIME=true; shift ;;
        -C|--color)
            if [ -n "${2:-}" ]; then
                HEADING_COLOR="$2"
                shift 2
            else
                echo "Error: --color requires a value." >&2
                exit 1
            fi
            ;;
        -h|--help)      show_help ;;
        *)              echo "Unknown option: $1" >&2; show_help ;;
    esac
done

# Define heading format (bold + optional custom color)
HEADING_FORMAT="${BOLD}"
if [ -n "$HEADING_COLOR" ]; then
    if [[ "$HEADING_COLOR" =~ ^[0-9]+$ ]] && [ "$HEADING_COLOR" -ge 0 ] && [ "$HEADING_COLOR" -le 255 ]; then
        HEADING_FORMAT="${BOLD}\e[38;5;${HEADING_COLOR}m"
    else
        HEADING_FORMAT="${BOLD}\e[${HEADING_COLOR}m"
    fi
fi

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

# Get memory info (Used / Total in MB)
if command -v free >/dev/null 2>&1; then
    memory=$(free -m 2>/dev/null | awk '/^Mem:/{print $3 " / " $2}' || echo "? / ?")
elif [ -r /proc/meminfo ]; then
    total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    
    # Fallback to MemFree if MemAvailable is missing
    [ -z "$avail" ] && avail=$(awk '/MemFree/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    
    if [ -n "$total" ] && [ -n "$avail" ]; then
        used=$((total - avail))
        memory="${used} / ${total}"
    else
        memory="? / ?"
    fi
else
    memory="? / ?"
fi

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
        printf "     ___    ${HEADING_FORMAT}%s@%s${CLEAR}\n" "$username" "$hostun"
        printf "    (.· |   ${HEADING_FORMAT}os     ${CLEAR}%s\n" "$os"
        printf "    (<> |   ${HEADING_FORMAT}host   ${CLEAR}%s\n" "$host"
        printf "   / __  \\  ${HEADING_FORMAT}kernel ${CLEAR}%s\n" "$kernel"
        printf "  ( /  \\ /| ${HEADING_FORMAT}uptime ${CLEAR}%s\n" "$uptime"
        printf " _/\\ __)/_) ${HEADING_FORMAT}pkgs   ${CLEAR}%s\n" "$pkgs"
        printf " \\/-____\\/  ${HEADING_FORMAT}memory ${CLEAR}%sMB\n" "$memory"

        if $SHOW_DATETIME; then
            printf "            ${HEADING_FORMAT}date${CLEAR}   %s\n" "$datetime"
        fi
    else
        printf "                    ${HEADING_FORMAT}%s@%s${CLEAR}\n" "$username" "$hostun"
        printf "  ;,           ,;   ${HEADING_FORMAT}os     ${CLEAR}%s\n" "$os"
        printf "   ';,.-----.,;'    ${HEADING_FORMAT}host   ${CLEAR}%s\n" "$host"
        printf "  ,'           ',   ${HEADING_FORMAT}kernel ${CLEAR}%s\n" "$kernel"
        printf " /    O     O    \\  ${HEADING_FORMAT}uptime ${CLEAR}%s\n" "$uptime"
        printf "|                 | ${HEADING_FORMAT}pkgs   ${CLEAR}%s\n" "$pkgs"
        printf "'-----------------' ${HEADING_FORMAT}memory ${CLEAR}%sMB\n" "$memory"

        if $SHOW_DATETIME; then
            printf "                    ${HEADING_FORMAT}date${CLEAR}   %s\n" "$datetime"
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
