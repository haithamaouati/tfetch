# tfetch

A tiny system info script for [Termux](https://termux.dev), written in pure Bash.  
No dependencies. No noise. Just the essentials.

![tfetch preview](preview.png)

## Features

- Displays basic system information:
  - Username and hostname
  - OS, architecture, kernel
  - Uptime, installed packages, memory
  - Color palette
- Works offline — no external dependencies
- Fast, lightweight, and silent on errors
- ASCII art included (yes, it's judging you)

## Installation

1. Clone the repository
```bash
git clone https://github.com/haithamaouati/tfetch.git
```
2. Change to the tfetch directory:
```
cd tfetch
```
3. Install the script
```
bash install.sh
```

## Usage
Usage: `tfetch`

##### Options:

`-c`, `--clear` Clear the screen before displaying info

`-p`, `--palette` Show the terminal color palette

`-h`, `--help` Show this help message and exit

## Uninstallation
```
bash uninstall.sh
```

## Environment
- Tested on [Termux](https://termux.dev/en/)

> [!IMPORTANT]  
> Give it a star ⭐ if you like it!

## License

**tfetch** is licensed under [WTFPL license](LICENSE)
