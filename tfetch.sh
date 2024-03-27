#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati
# A super tiny system information fetch script written in BASH

# Custom
CLEAR="\e[0m"
BOLD="\e[1m"
UNDERLINE="\e[4m"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"

clear

# Username
username=$(whoami)

# Hostname
hostun=$(hostname)

# OS
os=$(uname -o)

# Host
host=$(uname -m)

# Kernel version
kernel=$(uname -r)

# Uptime
uptime=$(uptime -p)

# Number of installed packages
pkgs=$(dpkg -l | grep -c "^ii")

# Memory (in MB)
memory=$(free -m | awk '/Mem/{print $2}')

# Displaying information
echo -e "\n"
echo -e "     ___    ${BOLD}$username@$hostun"
echo -e "    (.· |   ${BOLD}os${CLEAR}     $os"
echo -e "    (<> |   ${BOLD}host${CLEAR}   $host"
echo -e "   / __  \  ${BOLD}kernel${CLEAR} $kernel"
echo -e "  ( /  \ /| ${BOLD}uptime${CLEAR} $uptime"
echo -e " _/\ __)/_) ${BOLD}pkgs${CLEAR}   $pkgs"
echo -e " \/-____\/  ${BOLD}memory${CLEAR} ${memory}MB\n"

# Author
echo -e "${BOLD}tfetch ${CLEAR}by Haitham Aouati"
echo -e "${BOLD}GitHub:${CLEAR} ${UNDERLINE}github.com/haithamaouati${CLEAR}\n"

# Exit
exit 0
