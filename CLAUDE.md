# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`dot` is a portable dotfiles CLI written in pure zsh that installs developer tools to `~/.local` without requiring sudo. It works on macOS and Linux.

## Usage

```sh
./bootstrap.sh                   # POSIX sh: install zsh if missing, then run `dot init`
./dot init                       # check environment: zsh, login shell, build tools, PATH
./dot install <module>            # install a single module
./dot install --profile <name>   # install all modules in a profile
./dot update [<module>|all]      # check/apply updates via ETag
./dot status [<module>]          # show installed versions and stamps
./dot list                       # list all modules and profiles
```

## Architecture

```
bootstrap.sh      # POSIX sh bootstrap — the only file that runs without zsh
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
- `configs/zshrc` is symlinked to `~/.zshrc` by the zsh module and holds the oh-my-zsh setup plus the `plugins=(...)` list; oh-my-zsh itself is cloned to `~/.local/opt/oh-my-zsh`.
- Modules that need a line in `~/.zshrc` must use `rc_append_once <rc> <needle> <comment> <line>` from `lib/core.sh` — it refuses to write into an rc file that is a symlink into the repo, which would otherwise dirty tracked files.
- tmux module builds from source on macOS (no Homebrew), and tries system package managers first on Linux before falling back to source.
- `bootstrap.sh` must stay POSIX `sh` — it is the only entry point that runs before zsh exists, so it cannot use zsh syntax or source `lib/core.sh`.
- Prerequisite checks live in `lib/core.sh`: `confirm()`, `pkg_manager()`, `pkg_install_cmd()` (the pseudo-package `build-tools` maps to make + gcc per distro), `have_build_tools()`, `ensure_build_tools()`, `ensure_ncurses()`, `cpu_count()`. Modules that compile anything should call `ensure_build_tools <reason>` first.
- `dot project` (in `lib/project.sh`, sourced by `dot`) is the per-project counterpart to the module commands: it detects Sail / a running container that bind-mounts the project / the compose file and writes `.nvim-tools.json`, and `dot project check` runs the tools in that environment. Its runner-prefix logic mirrors `configs/nvim/lua/project/runner.lua` — change both together.
- The Neovim config resolves *where* project tooling runs through `configs/nvim/lua/project/runner.lua`, which reads a per-project `.nvim-tools.json` (docker/compose/sail/custom) and maps host paths to container paths. Any new formatter, linter or debug adapter that shells out to a project binary must build its command with `require("project.runner").command()` rather than hard-coding a path.
- Beware `set -euo pipefail` in `dot`: `(( x++ ))` returns non-zero when `x` is 0 and will abort the script — use `x=$(( x + 1 ))`.
