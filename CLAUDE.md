# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`dot` is a portable dotfiles CLI written in pure zsh that installs developer tools to `~/.local` without requiring sudo. It works on macOS and Linux.

## Usage

```sh
./dot install <module>            # install a single module
./dot install --profile <name>   # install all modules in a profile
./dot update [<module>|all]      # check/apply updates via ETag
./dot status [<module>]          # show installed versions and stamps
./dot list                       # list all modules and profiles
```

## Architecture

```
dot               # CLI entry point — parses commands, sources modules
lib/core.sh       # shared helpers: logging, OS/arch detection, fetch(), ETag stamping
modules/*.sh      # one file per tool; each defines module_install(), module_update(), module_status()
profiles/*.sh     # ordered list of modules to install together, plus post-install hooks
configs/          # managed config files that modules symlink into place
```

**Install paths** (no sudo anywhere):
- Binaries / symlinks → `~/.local/bin/`
- Tool directories → `~/.local/opt/<tool>/`
- ETag stamps → `~/.local/share/dot/<tool>.etag`

## Adding a module

1. Create `modules/<name>.sh` with three functions: `module_install()`, `module_update()`, `module_status()`.
2. Use helpers from `lib/core.sh`: `fetch()`, `info/success/warn/error()`, `os_type`, `arch`.
3. Store the ETag after downloading so `module_update()` can detect new releases cheaply.
4. Add the module name to any relevant profiles in `profiles/`.

## Key conventions

- ETag-based update checks: download with `curl -I` to compare `ETag` against the stamp file; only re-download when they differ.
- GitHub release asset selection is done inline in each module — pick by `os_type`/`arch` values set in `lib/core.sh` (`macos`/`linux`, `arm64`/`x86_64`).
- Config files (e.g. `configs/tmux.conf`) are symlinked by the module during install, not copied.
- tmux module builds from source on macOS (no Homebrew), and tries system package managers first on Linux before falling back to source.
