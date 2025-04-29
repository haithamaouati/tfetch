# tfetch

**tfetch** is a tiny, paranoid, zero-dependency system info fetcher made for Termux — or any shell that breathes POSIX.

It prints your system stats in a clean, minimal layout. No ANSI vomit. No feature bloat. Just you, your shell, and the truth.

## Preview

```
     ___    u0_a2304@localhost
    (.· |   os     Android
    (<> |   host   aarch64
   / __  \  kernel 4.19.157-perf-g1a6087bc0325-dirty
  ( /  \ /| uptime up 1 day, 5 hours, 7 minutes
 _/\ __)/_) pkgs   103
 \/-____\/  memory 3713MB
```

## Features

- Works on Termux, Linux, or anything POSIX-ish
- Pure Bash (no dependencies)
- Fast
- No clutter
- Optional `--clear` flag to wipe the screen

## Install (rogue style)

Paste this in your terminal:

```bash
install -Dm700 <(curl -fsSL https://raw.githubusercontent.com/haithamaouati/tfetch/main/tfetch.sh) ~/.local/bin/tfetch
```

Or, clone manually:
```
git clone https://github.com/haithamaouati/tfetch
cd tfetch
chmod +x tfetch.sh
mv tfetch.sh ~/.local/bin/tfetch
```

**Ensure** `~/.local/bin` is in your `$PATH`:
```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Usage
```
tfetch          # prints info
tfetch --clear  # clears screen first
```

## License

[MIT](LICENSE).
Do what you want — just don’t make it suck.
