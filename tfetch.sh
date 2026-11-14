#!/usr/bin/env bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-11-14

set -euo pipefail

readonly VERSION="1.0.0"

# Default settings
CLEAR_SCREEN=0
SHOW_PALETTE=0
SHOW_DATE=0
SHOW_TIME=0
COLOR_ART=0
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

# Styles for labels and banner, set after the arguments are parsed
HEADING=""
ART_STYLE=""

# Reset terminal styling on exit or interrupt
trap 'printf "%s" "$RESET"' EXIT
trap 'exit 130' INT TERM HUP

# Banners, add a new one by defining another ART_NAME array
# Rules: 7 lines, all the same width, single quotes
# A banner that breaks the rules is shown in full above the info
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

${BOLD}tfetch${RESET} ${VERSION}
A tiny system info script for Termux, written in pure Bash.

 Author: Haitham Aouati
 GitHub: ${UNDERLINE}github.com/haithamaouati${RESET}

Usage: tfetch [OPTIONS]

Options:
  -c, --clear         Clear the terminal screen before displaying info
  -p, --palette       Show the terminal color palette
  -b, --banner NAME   Choose the ASCII art banner (default: tux)
  -d, --date          Show the current date
  -t, --time          Show the current time (hours, minutes, seconds)
  -a, --all           Show all information, including -d, -t, and -p
  -C, --color VALUE   Set bold color for info labels: a 256-color index
                      (0-255) or an SGR sequence such as "1;31"
  -A, --art-color     Also apply the -C color to the banner
  -v, --version       Show the version and exit
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
            -d|--date|--datetime) SHOW_DATE=1 ;;
            -t|--time)     SHOW_TIME=1 ;;
            -a|--all)
                SHOW_DATE=1
                SHOW_TIME=1
                SHOW_PALETTE=1
                ;;
            -A|--art-color) COLOR_ART=1 ;;
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
            -v|--version)  printf 'tfetch %s\n' "$VERSION"; exit 0 ;;
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

# Build the label style and the optional banner style from the validated color
build_styles() {
    HEADING=$BOLD
    ART_STYLE=""

    if [[ -z $HEADING_COLOR ]]; then
        if (( COLOR_ART )); then
            die "option '-A' needs a color from -C." 2
        fi
        return 0
    fi

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
        if (( COLOR_ART )); then
            ART_STYLE=$'\e'"[${seq}m"
        fi
    fi
}

# Print the width of a line in characters, not bytes
line_width() {
    local LC_ALL=C
    local bare=${1//[$'\x80'-$'\xBF']/}
    printf '%d' "${#bare}"
}

# Succeed when the named banner array follows the rules
banner_is_valid() {
    local -n lines=$1
    local line first
    (( ${#lines[@]} == 7 )) || return 1
    first=$(line_width "${lines[0]}")
    (( first > 0 )) || return 1
    for line in "${lines[@]}"; do
        [[ $(line_width "$line") == "$first" ]] || return 1
    done
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

# Print the user and host title
print_title() {
    printf '%s%s@%s%s\n' "$HEADING" "$1" "$2" "$RESET"
}

# Print one info row
print_row() {
    printf '%s%-7s%s%s\n' "$HEADING" "$1" "$RESET" "$2"
}

main() {
    parse_args "$@"
    build_styles

    local user_name host_name os arch kernel uptime_str pkgs memory
    local date_str="" time_str=""

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

    local -a labels values
    labels=(os host kernel uptime pkgs memory)
    values=("$os" "$arch" "$kernel" "$uptime_str" "$pkgs" "$memory")

    if (( SHOW_DATE )); then
        printf -v date_str '%(%A, %B %d, %Y)T' -1
        labels+=(date)
        values+=("$date_str")
    fi

    if (( SHOW_TIME )); then
        printf -v time_str '%(%H:%M:%S)T' -1
        labels+=(time)
        values+=("$time_str")
    fi

    # Load the chosen banner and check it against the rules
    local banner_var="ART_${BANNER^^}"
    local -n banner_art="$banner_var"
    local -a art=("${banner_art[@]}")
    local width=0 pad="" line i
    local stacked=0
    if banner_is_valid "$banner_var"; then
        width=$(line_width "${art[0]}")
        printf -v pad '%*s' "$width" ''
    else
        stacked=1
    fi

    # Clear only after all arguments are validated
    if (( CLEAR_SCREEN )) && [[ -t 1 ]]; then
        printf '\e[H\e[2J\e[3J'
    fi

    printf '\n'
    if (( stacked )); then
        # Banner in full on top, info below it
        for line in "${art[@]}"; do
            printf '%s%s%s\n' "$ART_STYLE" "$line" "$RESET"
        done
        printf '\n'
        print_title "$user_name" "$host_name"
        for i in "${!labels[@]}"; do
            print_row "${labels[i]}" "${values[i]}"
        done
    else
        # Banner beside the info, extra rows get blank padding
        printf '%s%s%s' "$ART_STYLE" "${art[0]}" "$RESET"
        print_title "$user_name" "$host_name"
        for i in "${!labels[@]}"; do
            printf '%s%s%s' "$ART_STYLE" "${art[i + 1]:-$pad}" "$RESET"
            print_row "${labels[i]}" "${values[i]}"
        done
    fi

    if (( SHOW_PALETTE )); then
        printf '\n'
        print_palette "$width"
    fi
    printf '\n'
}

main "$@"
