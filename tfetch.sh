#!/usr/bin/env bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-11-13

set -euo pipefail

# Default settings
CLEAR_SCREEN=0
SHOW_PALETTE=0
SHOW_DATETIME=0
BANNER="tux"
HEADING_COLOR=""

# Use colors only on a real terminal and respect NO_COLOR
if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-} != dumb ]]; then
    USE_COLOR=1
else
    USE_COLOR=0
fi

BOLD="" UNDERLINE="" RESET=""
if (( USE_COLOR )); then
    BOLD=$'\e[1m'
    UNDERLINE=$'\e[4m'
    RESET=$'\e[0m'
fi
readonly USE_COLOR BOLD UNDERLINE RESET

# Reset terminal styling on exit or interrupt
trap 'printf "%s" "$RESET"' EXIT
trap 'exit 130' INT TERM HUP

# Banners, add a new one by defining another ART_NAME array
# Rules: 7 lines, all the same width, first line plain ASCII, single quotes
readonly ART_TUX=(
'     ___    '
'    (.· |   '
'    (<> |   '
'   / __  \  '
'  ( /  \ /| '
' _/\ __)/_) '
' \/-____\/  '
)
readonly ART_ANDROID=(
'                    '
'  ;,           ,;   '
"   ';,.-----.,;'    "
"  ,'           ',   "
' /    O     O    \  '
'|                 | '
"'-----------------' "
)
readonly ART_TERM=(
' __________  '
'| >_       | '
'|          | '
'|  ~ $ ls  | '
'|          | '
'|__________| '
'   _|__|_    '
)

# Print the available banner names
list_banners() {
    local -a vars
    local var names=""
    mapfile -t vars < <(compgen -A variable ART_)
    for var in "${vars[@]}"; do
        names+="${var#ART_}, "
    done
    names=${names,,}
    printf '%s' "${names%, }"
}

usage() {
    cat <<EOF

${BOLD}tfetch${RESET}
A tiny system info script for Termux, written in pure Bash.

 Author: Haitham Aouati
 GitHub: ${UNDERLINE}github.com/haithamaouati${RESET}

Usage: tfetch [OPTIONS]

Options:
  -c, --clear         Clear the terminal screen before displaying info
  -p, --palette       Show the terminal color palette
  -b, --banner NAME   Choose the ASCII art banner (default: tux)
  -d, --datetime      Show current date and time
  -C, --color VALUE   Set bold color for info labels: a 256-color index
                      (0-255) or an SGR sequence such as "1;31"
  -h, --help          Show this help message and exit

Banners: $(list_banners)
EOF
}

die() {
    printf 'tfetch: %s\n' "$1" >&2
    exit "${2:-1}"
}

# Accept only names that match an ART_ array
set_banner() {
    local name=${1,,}
    if [[ $name =~ ^[a-z0-9_]+$ ]] && declare -p "ART_${name^^}" >/dev/null 2>&1; then
        BANNER=$name
    else
        die "unknown banner '$1' (available: $(list_banners))." 2
    fi
}

parse_args() {
    while (( $# )); do
        case $1 in
            -c|--clear)    CLEAR_SCREEN=1 ;;
            -p|--palette)  SHOW_PALETTE=1 ;;
            -d|--datetime) SHOW_DATETIME=1 ;;
            -b|--banner)
                (( $# >= 2 )) || die "option '$1' requires a banner name." 2
                set_banner "$2"
                shift
                ;;
            --banner=*)    set_banner "${1#*=}" ;;
            -C|--color)
                (( $# >= 2 )) || die "option '$1' requires a value." 2
                HEADING_COLOR=$2
                shift
                ;;
            --color=*)     HEADING_COLOR=${1#*=} ;;
            -h|--help)     usage; exit 0 ;;
            *)
                printf 'tfetch: unknown option: %s\n' "$1" >&2
                printf "Try 'tfetch --help' for more information.\n" >&2
                exit 2
                ;;
        esac
        shift
    done
}

# Build the label style from bold plus the validated color
build_heading() {
    HEADING=$BOLD
    [[ -n $HEADING_COLOR ]] || return 0

    local seq
    if [[ $HEADING_COLOR =~ ^[0-9]{1,3}$ ]] && (( 10#$HEADING_COLOR <= 255 )); then
        seq="38;5;$((10#$HEADING_COLOR))"
    elif [[ $HEADING_COLOR =~ ^[0-9]+(;[0-9]+)+$ ]]; then
        seq=$HEADING_COLOR
    else
        die "invalid color '$HEADING_COLOR' (use 0-255 or an SGR sequence like 1;31)." 2
    fi

    if (( USE_COLOR )); then
        HEADING+=$'\e'"[${seq}m"
    fi
}

# Each getter prints one value and always succeeds
get_uname() {
    uname "$1" 2>/dev/null || printf 'unknown'
}

get_kernel() {
    local raw
    raw=$(uname -r 2>/dev/null || true)
    if [[ $raw =~ ^[0-9]+(\.[0-9]+)* ]]; then
        printf '%s' "${BASH_REMATCH[0]}"
    else
        printf 'unknown'
    fi
}

# Print seconds since boot, or nothing when no source works
get_uptime_secs() {
    local secs rest stat tick
    local -a f

    # Preferred source
    if { read -r secs rest </proc/uptime; } 2>/dev/null && [[ $secs =~ ^[0-9]+ ]]; then
        printf '%s' "${secs%%.*}"
        return 0
    fi

    # Android may block /proc/uptime, so use the start time of this shell
    if { read -r stat <"/proc/$$/stat"; } 2>/dev/null; then
        stat=${stat##*) }
        read -ra f <<<"$stat"
        tick=$(getconf CLK_TCK 2>/dev/null || true)
        [[ $tick =~ ^[1-9][0-9]*$ ]] || tick=100
        if [[ ${f[19]:-} =~ ^[0-9]+$ ]]; then
            printf '%s' $(( f[19] / tick + SECONDS ))
        fi
    fi
    return 0
}

# Show only the two largest units to keep the line short
get_uptime() {
    local secs d h m
    secs=$(get_uptime_secs)
    if [[ -z $secs ]]; then
        printf 'unknown'
        return 0
    fi

    d=$(( secs / 86400 ))
    h=$(( secs % 86400 / 3600 ))
    m=$(( secs % 3600 / 60 ))
    if (( d > 0 )); then
        printf '%dd %dh' "$d" "$h"
    elif (( h > 0 )); then
        printf '%dh %dm' "$h" "$m"
    else
        printf '%dm' "$m"
    fi
}

get_pkgs() {
    local n=""
    if command -v dpkg-query >/dev/null 2>&1; then
        # shellcheck disable=SC2016
        n=$(dpkg-query -W -f='${db:Status-Abbrev}\n' 2>/dev/null \
            | awk '/^ii/ { c++ } END { print c + 0 }') || n=""
    elif command -v pacman >/dev/null 2>&1; then
        n=$(pacman -Qq 2>/dev/null | awk 'END { print NR }') || n=""
    fi
    printf '%s' "${n:-?}"
}

# Print a size given in KiB as MiB, or as GiB from 1 GiB up
format_kib() {
    local kib=$1 tenths
    if (( kib >= 1048576 )); then
        tenths=$(( kib * 10 / 1048576 ))
        printf '%d.%d GiB' $(( tenths / 10 )) $(( tenths % 10 ))
    else
        printf '%d MiB' $(( kib / 1024 ))
    fi
}

# Read used and total memory straight from /proc/meminfo
get_memory() {
    local key val rest total="" avail="" memfree=""
    if [[ -r /proc/meminfo ]]; then
        while read -r key val rest; do
            case $key in
                MemTotal:)     total=$val ;;
                MemAvailable:) avail=$val ;;
                MemFree:)      memfree=$val ;;
            esac
        done </proc/meminfo
    fi
    # Old kernels have no MemAvailable
    avail=${avail:-$memfree}

    if [[ $total =~ ^[0-9]+$ && $avail =~ ^[0-9]+$ ]]; then
        printf '%s / %s' "$(format_kib $(( total - avail )))" "$(format_kib "$total")"
    else
        printf '? / ?'
    fi
}

print_palette() {
    local indent=$1 start i
    for start in 0 8; do
        printf '%*s' "$indent" ''
        for (( i = start; i < start + 8; i++ )); do
            printf '\e[48;5;%dm  \e[0m' "$i"
        done
        printf '\n'
    done
}

main() {
    parse_args "$@"
    build_heading

    local user_name host_name os arch kernel uptime_str pkgs memory datetime=""

    user_name=${USER:-$(id -un 2>/dev/null || true)}
    user_name=${user_name:-unknown}
    host_name=${HOSTNAME:-$(uname -n 2>/dev/null || true)}
    host_name=${host_name:-localhost}
    os=$(get_uname -o)
    arch=$(get_uname -m)
    kernel=$(get_kernel)
    uptime_str=$(get_uptime)
    pkgs=$(get_pkgs)
    memory=$(get_memory)

    # Load the chosen banner by name
    local -n banner_art="ART_${BANNER^^}"
    local -a art=("${banner_art[@]}") labels values
    local pad=${art[0]//?/ }

    labels=(os host kernel uptime pkgs memory)
    values=("$os" "$arch" "$kernel" "$uptime_str" "$pkgs" "$memory")

    if (( SHOW_DATETIME )); then
        printf -v datetime '%(%Y-%m-%d %H:%M:%S)T' -1
        labels+=(date)
        values+=("$datetime")
    fi

    # Clear only after all arguments are validated
    if (( CLEAR_SCREEN )) && [[ -t 1 ]]; then
        printf '\e[H\e[2J\e[3J'
    fi

    # Rows past the end of the banner get blank padding
    printf '\n'
    printf '%s%s%s@%s%s\n' "${art[0]}" "$HEADING" "$user_name" "$host_name" "$RESET"
    local i
    for i in "${!labels[@]}"; do
        printf '%s%s%-7s%s%s\n' "${art[i + 1]:-$pad}" "$HEADING" "${labels[i]}" "$RESET" "${values[i]}"
    done

    if (( SHOW_PALETTE )); then
        printf '\n'
        print_palette "${#art[0]}"
    fi
    printf '\n'
}

main "$@"
