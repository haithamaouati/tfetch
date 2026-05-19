#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# Contributor: Reem Aouati
# GitHub: github.com/reemaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-05-19

set -euo pipefail

# Style - readonly constants
readonly CLEAR="\e[0m"
readonly BOLD="\e[1m"
readonly UNDERLINE="\e[4m"

# Helper function to generate color code
get_color_code() {
    local color_num=$1
    printf "\e[38;5;%sm" "$color_num"
}

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
    echo "  -C, --color NUM  Set color for ASCII art and headings (0-15, default: 7)"
    echo "  -h, --help       Show this help message and exit"
    exit 0
}

# Parse command-line flags
SHOW_PALETTE=false
SHOW_DATETIME=false
ASCII_MODE="tux"
COLOR_NUM=7

for arg in "$@"; do
    case "$arg" in
        -c|--clear)     printf "\033c" ;;
        -p|--palette)   SHOW_PALETTE=true ;;
        -t|--tux)       ASCII_MODE="tux" ;;
        -a|--android)   ASCII_MODE="android" ;;
        -d|--datetime)  SHOW_DATETIME=true ;;
        -C|--color)
            if [[ $2 =~ ^[0-9]+$ ]] && ((2 + 1 <= $#)); then
                COLOR_NUM=$2
                shift
            else
                echo "Error: --color requires a numeric argument (0-15)" >&2
                show_help
            fi
            ;;
        -h|--help)      show_help ;;
        *)              echo "Unknown option: $arg" >&2; show_help ;;
    esac
done

# Generate color code for ASCII art and headings
COLOR_CODE=$(get_color_code "$COLOR_NUM")

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
        printf "     ___    ${COLOR_CODE}${BOLD}%s@%s${CLEAR}\n" "$username" "$hostun"
        printf "    (.· |   ${COLOR_CODE}${BOLD}os     ${CLEAR}%s\n" "$os"
        printf "    (<> |   ${COLOR_CODE}${BOLD}host   ${CLEAR}%s\n" "$host"
        printf "   / __  \\  ${COLOR_CODE}${BOLD}kernel ${CLEAR}%s\n" "$kernel"
        printf "  ( /  \\ /| ${COLOR_CODE}${BOLD}uptime ${CLEAR}%s\n" "$uptime"
        printf " _/\\ __)/_) ${COLOR_CODE}${BOLD}pkgs   ${CLEAR}%s\n" "$pkgs"
        printf " \\/-____\\/  ${COLOR_CODE}${BOLD}memory ${CLEAR}%sMB\n" "$memory"

        if $SHOW_DATETIME; then
            printf "            ${COLOR_CODE}${BOLD}date${CLEAR}   %s\n" "$datetime"
        fi
    else
        printf "                    ${COLOR_CODE}${BOLD}%s@%s${CLEAR}\n" "$username" "$hostun"
        printf "  ;,           ,;   ${COLOR_CODE}${BOLD}os     ${CLEAR}%s\n" "$os"
        printf "   ';,.-----.,;'    ${COLOR_CODE}${BOLD}host   ${CLEAR}%s\n" "$host"
        printf "  ,'           ',   ${COLOR_CODE}${BOLD}kernel ${CLEAR}%s\n" "$kernel"
        printf " /    O     O    \\  ${COLOR_CODE}${BOLD}uptime ${CLEAR}%s\n" "$uptime"
        printf "|                 | ${COLOR_CODE}${BOLD}pkgs   ${CLEAR}%s\n" "$pkgs"
        printf "'-----------------' ${COLOR_CODE}${BOLD}memory ${CLEAR}%sMB\n" "$memory"

        if $SHOW_DATETIME; then
            printf "                    ${COLOR_CODE}${BOLD}date${CLEAR}   %s\n" "$datetime"
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
