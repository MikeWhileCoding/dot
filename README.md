# dot

A portable dotfiles CLI written in pure zsh. Installs developer tools to `~/.local` without sudo, on both macOS and Linux.

## Requirements

- `zsh`
- `curl`
- `tar`

## Quick start

### Option 1: Run from git source

Clone anywhere and run `dot` directly:

```sh
git clone https://github.com/MikeWhileCoding/dot.git ~/dot
~/dot/dot install neovim
```

`dot` resolves paths relative to its own location, so the repo can live wherever you like. You can add an alias for convenience:

```sh
alias dot="$HOME/dot/dot"
```

### Option 2: Install to ~/.config

Clone into `~/.config` and add `dot` to your PATH:

```sh
git clone https://github.com/MikeWhileCoding/dot.git ~/.config/dot
ln -sf ~/.config/dot/dot ~/.local/bin/dot
```

Now `dot` is available as a command (assuming `~/.local/bin` is in your PATH — `dot` can set that up for you with `dot install --profile desktop`).

## Usage

```
dot install <module>              Install a single module
dot install --profile <name>      Install all modules in a profile
dot update [<module>|all]         Update one module or everything
dot status [<module>]             Show installed version / stamp
dot list                          List all modules and profiles
dot help                          Show help
```

### Examples

```sh
# Install neovim nightly
dot install neovim

# Set up a full desktop environment
dot install --profile desktop

# Set up a lean server
dot install --profile server

# Check what's installed
dot status

# Update everything
dot update all

# Update just neovim
dot update neovim
```

## Project structure

```
dot                  # main CLI entry point (zsh, executable)
lib/core.sh          # shared helpers (logging, OS detection, update checks)
modules/neovim.sh    # neovim nightly module
profiles/
  desktop.sh         # full workstation profile
  server.sh          # lean server profile
```

## How it works

**Modules** are sourced zsh files in `modules/` that expose `module_install`, `module_update`, and `module_status` functions. Each module installs a single tool.

**Profiles** are sourced zsh files in `profiles/` that define a `PROFILE_MODULES` array and an optional `profile_post_install` hook. Running `dot install --profile <name>` installs every module in the profile.

**Update checks** use HTTP ETag headers. When a module is installed, the remote ETag is saved to `~/.local/share/dot/<module>.etag`. On `dot update`, the remote ETag is compared against the saved stamp — the download only happens if they differ.

Everything installs into `~/.local`:

| Path | Purpose |
|---|---|
| `~/.local/bin` | Symlinks and shims |
| `~/.local/opt` | Extracted tool directories |
| `~/.local/share/dot` | ETag stamp files |

## Adding a module

Create `modules/<name>.sh`:

```sh
MODULE_NAME="mymodule"
MODULE_DESC="Short description"

module_install() {
  # install logic
}

module_update() {
  # update logic (use needs_update for ETag checks)
}

module_status() {
  # print version / stamp info
}
```

Then add it to any profile's `PROFILE_MODULES` array, or install it directly with `dot install mymodule`.

## Available modules

| Module | Description |
|---|---|
| `neovim` | Neovim nightly from GitHub release archives |

## Profiles

| Profile | Modules | Description |
|---|---|---|
| `desktop` | neovim (+ tmux, fzf, ripgrep, starship, zoxide planned) | Full workstation |
| `server` | neovim (+ tmux, fzf, ripgrep planned) | Lean baseline |
