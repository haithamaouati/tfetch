#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-11-11

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
    echo "  -b, --battery    Show battery status bar"
    echo "  -h, --help       Show this help message and exit"
    exit 0
}

# Parse command-line flags
SHOW_PALETTE=false
SHOW_DATETIME=false
SHOW_BATTERY=false
ASCII_MODE="tux"

for arg in "$@"; do
    case "$arg" in
        -c|--clear)     printf "\033c" ;;
        -p|--palette)   SHOW_PALETTE=true ;;
        -t|--tux)       ASCII_MODE="tux" ;;
        -a|--android)   ASCII_MODE="android" ;;
        -d|--datetime)  SHOW_DATETIME=true ;;
        -b|--battery)   SHOW_BATTERY=true ;;
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

# Print battery status bar function (cloned from battery.sh)
print_battery() {
    local indent=$1
    if ! command -v termux-battery-status >/dev/null 2>&1; then
        printf "%${indent}s" " "
        echo -e "\e[31mError: 'termux-battery-status' not found\e[0m"
        return
    fi

    local json_output
    json_output=$(termux-battery-status 2>/dev/null)
    if [ -z "$json_output" ]; then
        printf "%${indent}s" " "
        echo -e "\e[31mError: Failed to retrieve battery data\e[0m"
        return
    fi

    local percentage
    percentage=$(echo "$json_output" | sed -n 's/.*"percentage"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
    if [ -z "$percentage" ]; then
        printf "%${indent}s" " "
        echo -e "\e[31mError: Could not parse battery percentage\e[0m"
        return
    fi

    local width=20
    local filled=$(( (percentage * width) / 100 ))
    local empty=$(( width - filled ))

    local bar_remaining=""
    for ((i=0; i<filled; i++)); do
        bar_remaining="${bar_remaining}█"
    done

    local bar_consumed=""
    for ((i=0; i<empty; i++)); do
        bar_consumed="${bar_consumed}▒"
    done

    local GREEN="\033[32m"
    local YELLOW="\033[33m"
    local RED="\033[31m"
    local RESET="\033[0m"
    local BAR_COLOR

    if [ "$percentage" -ge 20 ]; then
        BAR_COLOR="$GREEN"
    elif [ "$percentage" -ge 15 ]; then
        BAR_COLOR="$YELLOW"
    else
        BAR_COLOR="$RED"
    fi

    printf "%${indent}s" " "
    echo -ne "${BAR_COLOR}${bar_remaining}${bar_consumed}${RESET} ${percentage}%\n"
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
    
    # Print battery status bar if requested (placed under the color palette)
    if $SHOW_BATTERY; then
        echo
        print_battery "$palette_indent"
    fi
    
    echo
}

# Determine palette indent and print output
if [ "$ASCII_MODE" = "tux" ]; then
    print_system_info 12
else
    print_system_info 20
fi
