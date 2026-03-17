# dot

A portable dotfiles CLI written in pure zsh. Installs developer tools to `~/.local` without sudo, on both macOS and Linux.

_Note: this project is vibe-coded and may include errors. The intention for it being public is not to explicitly make it useful for others, some configuration might be very specific to my instance._

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
# Install neovim nightly (binary + config symlink)
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
dot                      # main CLI entry point (zsh, executable)
lib/core.sh              # shared helpers (logging, OS detection, update checks)
modules/                 # one file per tool
configs/
  nvim/                  # Neovim config (symlinked to ~/.config/nvim on install)
    init.lua
    lua/
      config/            # options, keymaps, lazy bootstrap
      plugins/           # one file per plugin category
profiles/
  desktop.sh             # full workstation profile
  server.sh              # lean server profile
```

## How it works

**Modules** are sourced zsh files in `modules/` that expose `module_install`, `module_update`, and `module_status` functions. Each module installs a single tool.

**Profiles** are sourced zsh files in `profiles/` that define a `PROFILE_MODULES` array and an optional `profile_post_install` hook. Running `dot install --profile <name>` installs every module in the profile.

**Update checks** use HTTP ETag headers. When a module is installed, the remote ETag is saved to `~/.local/share/dot/<module>.etag`. On `dot update`, the remote ETag is compared against the saved stamp — the download only happens if they differ.

**Configs** live in `configs/<tool>/` and are symlinked to their standard locations on install (e.g. `configs/nvim/` → `~/.config/nvim`).

Everything installs into `~/.local`:

| Path | Purpose |
|---|---|
| `~/.local/bin` | Symlinks and shims |
| `~/.local/opt` | Extracted tool directories |
| `~/.local/share/dot` | ETag stamp files |

## Available modules

| Module | Description |
|---|---|
| `neovim` | Neovim nightly — pre-built binary + symlinks `configs/nvim/` |
| `tmux` | tmux — built from source |
| `fzf` | fzf — fuzzy finder |
| `ripgrep` | ripgrep — fast grep |
| `delta` | delta — git diff pager |
| `gh` | GitHub CLI |
| `nvm` | Node Version Manager |
| `claude` | Claude Code CLI |

## Profiles

| Profile | Modules | Description |
|---|---|---|
| `desktop` | neovim, tmux, fzf, ripgrep, delta, gh, nvm, claude | Full workstation |
| `server` | neovim, tmux, fzf, ripgrep, delta | Lean baseline |

## Neovim config

The Neovim config in `configs/nvim/` is set up with [lazy.nvim](https://github.com/folke/lazy.nvim) and includes:

| Category | Plugins |
|---|---|
| Colorscheme | [vague.nvim](https://github.com/vague-theme/vague.nvim) |
| Fuzzy finder | telescope + fzf-native |
| File browser | oil.nvim (`<leader>pv`, `-`) |
| Quick marks | harpoon2 (`<leader>a`, `<C-e>`, `<C-h/t/n/s>`) |
| LSP | mason + nvim-lspconfig (nvim 0.11 native API) |
| Completion | nvim-cmp + LuaSnip |
| Syntax | nvim-treesitter + textobjects + context + rainbow-delimiters |
| Formatting | conform.nvim |
| Git | gitsigns + fugitive |
| UI | lualine, indent-blankline, dressing, which-key |

### Key bindings

| Key | Action |
|---|---|
| `<leader>pv` | Open file explorer |
| `<leader>pf` | Find files |
| `<C-p>` | Git files |
| `<leader>ps` | Grep with prompt |
| `<leader>a` | Harpoon add |
| `<C-e>` | Harpoon menu |
| `<C-h/t/n/s>` | Harpoon jump 1–4 |
| `<leader>sg` | Live grep |
| `<leader>sb` | Buffers |
| `K` | LSP hover |
| `gd` | Go to definition |
| `gr` | References |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |

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
