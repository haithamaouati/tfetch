#!/usr/bin/env bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# tfetch: A tiny system info script for Termux, written in pure Bash.
# Last updated: 2026-11-20

set -euo pipefail

readonly VERSION="1.1.0"

# Where -u downloads the latest script from
# TFETCH_UPDATE_URL can override it, for example for testing
readonly UPDATE_URL="https://raw.githubusercontent.com/haithamaouati/tfetch/main/tfetch.sh"

# Default settings
CLEAR_SCREEN=0
SHOW_PALETTE=0
SHOW_DATE=0
SHOW_TIME=0
LAYOUT="side"
BANNER="tux"
HEADING_COLOR=""
BANNER_COLOR=""
ASCII_FILE=""
NO_ART=0

# Info lines that can be hidden with --disable
readonly INFO_LINES=(title os host kernel uptime pkgs shell memory date time)
declare -A DISABLED=()

# Custom banner and info rows
CUSTOM_ART=()
LABELS=()
VALUES=()

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
BANNER_STYLE=""

# Temporary file used by the updater
TMP_FILE=""

# Reset terminal styling and remove the temporary file on exit or interrupt
cleanup() {
    printf '%s' "$RESET"
    if [[ -n $TMP_FILE ]]; then
        rm -f -- "$TMP_FILE"
    fi
}
trap cleanup EXIT
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
' __________   '
'| >_       |  '
'|          |  '
'|  ~ $ ls  |  '
'|          |  '
'|__________|  '
'   _|__|_     '
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

# Print the info line names that --disable accepts
list_info_lines() {
    local names
    printf -v names '%s, ' "${INFO_LINES[@]}"
    printf '%s' "${names%, }"
}

usage() {
    cat <<EOF

${BOLD}tfetch${RESET} ${VERSION}
A tiny system info script for Termux, written in pure Bash.

 Author: Haitham Aouati
 GitHub: ${UNDERLINE}github.com/haithamaouati${RESET}

${BOLD}Usage:${RESET} tfetch [OPTIONS]

${BOLD}Information:${RESET}
  -d, --date                 Show the current date
  -t, --time                 Show the current time (hours, minutes, seconds)
  -p, --palette              Show the terminal color palette
  -a, --all                  Show all information (same as -d -t -p)
      --disable NAME...      Hide the given info lines (see Info lines below)

${BOLD}Appearance:${RESET}
  -C, --color COLOR [COLOR]  Set the bold color of the info labels and,
                             optionally, of the ASCII art
      --ascii NAME|FILE      Use a built-in ASCII art or a text file
      --off                  Show the info without ASCII art
  -l, --layout NAME          Show the info beside (side) or below the ASCII art
  -c, --clear                Clear the terminal screen before displaying info

${BOLD}General:${RESET}
  -u, --update               Update tfetch from the GitHub repository
  -v, --version              Show the version and exit
  -h, --help                 Show this help message and exit

COLOR is a 256-color index (0-255) or an SGR sequence such as "1;31".
Built-in ASCII art: $(list_banners)
Info lines: $(list_info_lines)

${BOLD}Examples:${RESET}
  tfetch -a
  tfetch -C 32 34 --ascii android
  tfetch --ascii ~/art.txt -l below
  tfetch --off -d -t
  tfetch --disable os memory
EOF
}

die() {
    printf 'tfetch: %s\n' "$1" >&2
    exit "${2:-1}"
}

# Use a built-in banner when the name matches an ART_ array, otherwise a file
set_art() {
    local name=${1,,}
    if [[ $name =~ ^[a-z0-9_]+$ ]] && declare -p "ART_${name^^}" >/dev/null 2>&1; then
        BANNER=$name
        ASCII_FILE=""
    else
        ASCII_FILE=$1
    fi
}

# Download the latest script, check it, and replace this file
update_self() {
    local url=${TFETCH_UPDATE_URL:-$UPDATE_URL}
    local target dir first remote_version mode

    target=$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || true)
    [[ -n $target && -f $target ]] || die "cannot locate the script file to update."
    dir=${target%/*}
    [[ -w $target && -w $dir ]] || die "no write permission for '$target'."

    TMP_FILE=$(mktemp "$dir/.tfetch.XXXXXX") || die "cannot create a temporary file."

    printf 'Checking %s\n' "$url"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 30 -o "$TMP_FILE" "$url" || die "download failed."
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$TMP_FILE" "$url" || die "download failed."
    else
        die "curl or wget is required to update."
    fi

    # Refuse anything that does not look like a working tfetch script
    IFS= read -r first <"$TMP_FILE" || true
    remote_version=$(sed -n '/^readonly VERSION="/{s/^readonly VERSION="\([^"]*\)".*/\1/;p;q;}' "$TMP_FILE") || remote_version=""
    if [[ $first != '#!'*bash* || -z $remote_version ]] || ! bash -n "$TMP_FILE" 2>/dev/null; then
        die "the downloaded file is not a valid tfetch script, keeping the current version."
    fi

    if [[ $(<"$TMP_FILE") == "$(<"$target")" ]]; then
        printf 'tfetch %s is already up to date.\n' "$VERSION"
        exit 0
    fi

    # Keep the permissions of the old file and swap it in one step
    mode=$(stat -c %a -- "$target" 2>/dev/null || printf '755')
    chmod "$mode" "$TMP_FILE"
    mv -f -- "$TMP_FILE" "$target"
    TMP_FILE=""
    printf 'Updated tfetch from %s to %s.\n' "$VERSION" "$remote_version"
    exit 0
}

# Accept only the two layouts
set_layout() {
    case ${1,,} in
        side|below) LAYOUT=${1,,} ;;
        *) die "unknown layout '$1' (use side or below)." 2 ;;
    esac
}

# Take the label color and an optional ASCII art color, separated by a comma
set_colors() {
    HEADING_COLOR=${1%%,*}
    if [[ $1 == *,* ]]; then
        BANNER_COLOR=${1#*,}
    fi
}

# Mark info lines as hidden, names can be separated by commas
add_disabled() {
    local item name
    local -a items
    IFS=, read -ra items <<<"$1"
    for item in "${items[@]}"; do
        name=${item,,}
        [[ -n $name ]] || continue
        if [[ " ${INFO_LINES[*]} " == *" $name "* ]]; then
            DISABLED[$name]=1
        else
            die "unknown info line '$item' (available: $(list_info_lines))." 2
        fi
    done
}

parse_args() {
    while (( $# )); do
        case $1 in
            -d|--date|--datetime) SHOW_DATE=1 ;;
            -t|--time)     SHOW_TIME=1 ;;
            -p|--palette)  SHOW_PALETTE=1 ;;
            -a|--all)
                SHOW_DATE=1
                SHOW_TIME=1
                SHOW_PALETTE=1
                ;;
            --disable)
                (( $# >= 2 )) && [[ $2 != -* ]] || die "option '$1' requires at least one info line name." 2
                shift
                # Take every name up to the next option
                while (( $# )) && [[ $1 != -* ]]; do
                    add_disabled "$1"
                    shift
                done
                continue
                ;;
            --disable=*)
                [[ -n ${1#*=} ]] || die "option '--disable' requires at least one info line name." 2
                add_disabled "${1#*=}"
                ;;
            -C|--color)
                (( $# >= 2 )) || die "option '$1' requires a color." 2
                set_colors "$2"
                shift
                # An optional second color is for the ASCII art and starts with a digit
                if (( $# >= 2 )) && [[ $2 =~ ^[0-9] ]]; then
                    BANNER_COLOR=$2
                    shift
                fi
                ;;
            --color=*)     set_colors "${1#*=}" ;;
            --ascii)
                (( $# >= 2 )) && [[ $2 != -* ]] || die "option '$1' requires a name or a file path." 2
                set_art "$2"
                shift
                ;;
            --ascii=*)
                [[ -n ${1#*=} ]] || die "option '--ascii' requires a name or a file path." 2
                set_art "${1#*=}"
                ;;
            --off)         NO_ART=1 ;;
            -l|--layout)
                (( $# >= 2 )) || die "option '$1' requires a value (side or below)." 2
                set_layout "$2"
                shift
                ;;
            --layout=*)    set_layout "${1#*=}" ;;
            -c|--clear)    CLEAR_SCREEN=1 ;;
            -u|--update)   update_self ;;
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

# Turn a color value into an SGR sequence, fail when it is invalid
color_to_seq() {
    local value=$1
    if [[ $value =~ ^[0-9]{1,3}$ ]] && (( 10#$value <= 255 )); then
        printf '38;5;%d' "$((10#$value))"
    elif [[ $value =~ ^[0-9]+(;[0-9]+)+$ ]]; then
        printf '%s' "$value"
    else
        return 1
    fi
}

# Build the label style and the bold ASCII art style from the validated colors
build_styles() {
    local label_seq="" art_seq=""
    HEADING=$BOLD
    BANNER_STYLE=""

    if [[ -n $HEADING_COLOR ]]; then
        label_seq=$(color_to_seq "$HEADING_COLOR") \
            || die "invalid color '$HEADING_COLOR' (use 0-255 or an SGR sequence like 1;31)." 2
    fi
    if [[ -n $BANNER_COLOR ]]; then
        art_seq=$(color_to_seq "$BANNER_COLOR") \
            || die "invalid ASCII art color '$BANNER_COLOR' (use 0-255 or an SGR sequence like 1;31)." 2
    fi

    (( USE_COLOR )) || return 0

    if [[ -n $label_seq ]]; then
        HEADING+=$'\e'"[${label_seq}m"
    fi
    if [[ -n $art_seq ]]; then
        BANNER_STYLE=$BOLD$'\e'"[${art_seq}m"
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

# Read a custom banner from a file into CUSTOM_ART
# Plain text only, color codes are removed and short lines are padded
load_ascii_file() {
    local file=$1 line i max=0 pad
    local sgr=$'\e\\[[0-9;]*m'
    local -a widths=()

    [[ -f $file && -r $file ]] \
        || die "'$file' is not a built-in ASCII art or a readable file (built-in: $(list_banners))."

    CUSTOM_ART=()
    while IFS= read -r line || [[ -n $line ]]; do
        (( ${#CUSTOM_ART[@]} < 200 )) || die "ASCII art file '$file' has more than 200 lines."
        line=${line%$'\r'}
        line=${line//$'\t'/    }
        while [[ $line =~ $sgr ]]; do
            line=${line//"${BASH_REMATCH[0]}"/}
        done
        line=${line//[[:cntrl:]]/}
        CUSTOM_ART+=("$line")
    done <"$file"

    # Drop blank lines at the end
    while (( ${#CUSTOM_ART[@]} )) && [[ -z ${CUSTOM_ART[-1]//[[:space:]]/} ]]; do
        unset 'CUSTOM_ART[-1]'
    done
    (( ${#CUSTOM_ART[@]} )) || die "ASCII art file '$file' is empty."

    # Pad every line to the width of the widest one plus a two space gap
    for (( i = 0; i < ${#CUSTOM_ART[@]}; i++ )); do
        widths[i]=$(line_width "${CUSTOM_ART[i]}")
        if (( widths[i] > max )); then
            max=${widths[i]}
        fi
    done
    max=$(( max + 2 ))
    for (( i = 0; i < ${#CUSTOM_ART[@]}; i++ )); do
        printf -v pad '%*s' $(( max - widths[i] )) ''
        CUSTOM_ART[i]+=$pad
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

# Print the name of the login shell
get_shell() {
    local sh=${SHELL:-}
    if [[ -n $sh ]]; then
        printf '%s' "${sh##*/}"
    else
        printf 'unknown'
    fi
}

# Short date, for example Sat, Nov 14, 2026
get_date() {
    printf '%(%a, %b %d, %Y)T' -1
}

get_time() {
    printf '%(%H:%M:%S)T' -1
}

# Add an info row unless it is hidden, the value is only computed when needed
add_row() {
    local label=$1
    shift
    [[ -z ${DISABLED[$label]:-} ]] || return 0
    LABELS+=("$label")
    VALUES+=("$("$@")")
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
    build_styles

    local mode="side"
    local -a art=() info=()
    local width=0 pad="" i total line banner_var

    # Load the banner unless art is turned off
    if (( NO_ART )); then
        mode="off"
    else
        banner_var="ART_${BANNER^^}"
        if [[ -n $ASCII_FILE ]]; then
            load_ascii_file "$ASCII_FILE"
            banner_var="CUSTOM_ART"
        fi
        local -n banner_art="$banner_var"
        art=("${banner_art[@]}")
        if banner_is_valid "$banner_var"; then
            width=$(line_width "${art[0]}")
            printf -v pad '%*s' "$width" ''
        else
            # A banner that breaks the rules goes above the info
            mode="below"
        fi
        if [[ $LAYOUT == below ]]; then
            mode="below"
        fi
    fi
    if [[ $mode != side ]]; then
        width=0
    fi

    # Info rows, hidden lines are skipped before any work is done
    add_row os get_uname -o
    add_row host get_uname -m
    add_row kernel get_kernel
    add_row uptime get_uptime
    add_row pkgs get_pkgs
    add_row shell get_shell
    add_row memory get_memory
    if (( SHOW_DATE )); then
        add_row date get_date
    fi
    if (( SHOW_TIME )); then
        add_row time get_time
    fi

    # Build the final text of every info line
    if [[ -z ${DISABLED[title]:-} ]]; then
        local user_name host_name
        user_name=${USER:-$(id -un 2>/dev/null || true)}
        user_name=${user_name:-unknown}
        host_name=${HOSTNAME:-$(uname -n 2>/dev/null || true)}
        host_name=${host_name:-localhost}
        info+=("${HEADING}${user_name}@${host_name}${RESET}")
    fi
    for (( i = 0; i < ${#LABELS[@]}; i++ )); do
        printf -v line '%s%-7s%s%s' "$HEADING" "${LABELS[i]}" "$RESET" "${VALUES[i]}"
        info+=("$line")
    done

    # Clear only after all arguments are validated
    if (( CLEAR_SCREEN )) && [[ -t 1 ]]; then
        printf '\e[H\e[2J\e[3J'
    fi

    printf '\n'
    case $mode in
        off)
            for (( i = 0; i < ${#info[@]}; i++ )); do
                printf '%s\n' "${info[i]}"
            done
            ;;
        below)
            # Banner in full on top, info below it
            for (( i = 0; i < ${#art[@]}; i++ )); do
                printf '%s%s%s\n' "$BANNER_STYLE" "${art[i]}" "$RESET"
            done
            if (( ${#info[@]} )); then
                printf '\n'
            fi
            for (( i = 0; i < ${#info[@]}; i++ )); do
                printf '%s\n' "${info[i]}"
            done
            ;;
        side)
            # Banner beside the info, the shorter side gets blank padding
            total=${#art[@]}
            if (( ${#info[@]} > total )); then
                total=${#info[@]}
            fi
            for (( i = 0; i < total; i++ )); do
                printf '%s%s%s' "$BANNER_STYLE" "${art[i]:-$pad}" "$RESET"
                printf '%s\n' "${info[i]:-}"
            done
            ;;
    esac

    if (( SHOW_PALETTE )); then
        printf '\n'
        print_palette "$width"
    fi
    printf '\n'
}

main "$@"
