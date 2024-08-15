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

# Clear the screen
clear

# System information
username=$(whoami) # Username
hostun=$(hostname) # Hostname
os=$(uname -o) # OS
host=$(uname -m) # Host
kernel=$(uname -r) # Kernel version
uptime=$(uptime -p) # Uptime
pkgs=$(dpkg -l | grep -c "^ii") # Number of installed packages
memory=$(free -m | awk '/Mem/{print $2}') # Memory (in MB)

# Fetch information
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
