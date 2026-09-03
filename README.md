# dot

A portable dotfiles CLI written in pure zsh. Installs developer tools to `~/.local` without sudo, on both macOS and Linux.

_Note: this project is vibe-coded and may include errors. The intention for it being public is not to explicitly make it useful for others, some configuration might be very specific to my instance._

## Requirements

- `zsh` — `dot` is written in zsh, so it cannot run without it. Use `./bootstrap.sh` (POSIX `sh`) to install zsh on a machine that doesn't have it.
- `curl`
- `tar`
- `make` + `gcc`/`clang` — only needed for source-built modules (`tmux`, `zsh`) and for Neovim plugins that compile native code (treesitter parsers, telescope-fzf-native). `dot init` checks for these and offers to install them.

## Quick start

### Option 0: No zsh yet? Bootstrap first

`dot` is a zsh script, so a machine without zsh can't run it. `bootstrap.sh` is plain POSIX `sh`: it installs zsh (package manager first, source build into `~/.local` as the sudo-free fallback) and then hands off to `dot init`.

```sh
git clone https://github.com/MikeWhileCoding/dot.git ~/.config/dot
~/.config/dot/bootstrap.sh          # add --yes to skip the prompts
```

If you already have zsh, skip straight to `dot init`:

```sh
./dot init
```

`dot init` checks the environment and tells you how to fix what's missing:

- zsh is installed, and whether it's your **login shell** (prints the `chsh` command if not)
- `curl`, `tar`, `git` — offers to install any that are missing
- `make` + a C compiler — offers to install them (`build-essential`, `base-devel`, …)
- `~/.local/bin` is on your `PATH` — adds it to your shell rc if not
- offers to symlink `dot` into `~/.local/bin`

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
dot init                          Check the environment (zsh, build tools, PATH)
dot install <module>              Install a single module
dot install --profile <name>      Install all modules in a profile
dot update [<module>|all]         Update one module or everything
dot status [<module>]             Show installed version / stamp
dot config [<module>|all]         Re-apply config symlinks / settings
dot list                          List all modules and profiles
dot help                          Show help

Per-project (run inside a project):
dot project show                  Show where this project's tools run
dot project init [--local]        Detect containers and write .nvim-tools.json
dot project check                 Verify php/pint/phpstan/biome are reachable
```

### Examples

```sh
# Check the environment before installing anything
dot init

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
bootstrap.sh             # POSIX sh entry point — installs zsh, then runs `dot init`
dot                      # main CLI entry point (zsh, executable)
lib/core.sh              # shared helpers (logging, OS detection, update checks)
modules/                 # one file per tool
configs/
  zshrc                  # managed ~/.zshrc — oh-my-zsh setup and plugin list
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
| `zsh` | zsh itself + oh-my-zsh — installs both if missing, symlinks `configs/zshrc` → `~/.zshrc` |
| `intelephense` | Intelephense PHP language server + guided premium licence setup |
| `neovim` | Neovim nightly — pre-built binary + symlinks `configs/nvim/` |
| `tmux` | tmux — built from source |
| `fzf` | fzf — fuzzy finder |
| `ripgrep` | ripgrep — fast grep |
| `delta` | delta — git diff pager |
| `gh` | GitHub CLI |
| `nvm` | Node Version Manager |
| `uv` | uv — Python package/project manager |
| `posting` | posting — TUI HTTP client |
| `aliases` | Shell aliases sourced from `configs/aliases.zsh` |
| `claude` | Claude Code CLI |

## Profiles

| Profile | Modules | Description |
|---|---|---|
| `desktop` | zsh, neovim, tmux, fzf, ripgrep, delta, gh, nvm, uv, posting, claude | Full workstation |
| `server` | zsh, neovim, tmux, fzf, ripgrep, delta | Lean baseline |

## Shell config (oh-my-zsh)

`dot install zsh` clones [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) into `~/.local/opt/oh-my-zsh` and symlinks `configs/zshrc` → `~/.zshrc`. An existing unmanaged `~/.zshrc` is backed up to `~/.zshrc.bak` first.

Enabled plugins:

| Plugin | What it adds |
|---|---|
| `git` | `gst`, `gco`, `gp`, `gd`, `glog`, `gcm`, … plus branch helpers |
| `github` | `gh`/`hub` completion and GitHub helper functions |
| `docker` | docker CLI completion, `dps`, `dbl`, container/image shortcuts |

To change them, edit the `plugins=(...)` array in `configs/zshrc` and open a new shell — no reinstall needed, since `~/.zshrc` is a symlink into the repo. `dot update zsh` pulls the latest oh-my-zsh (its own auto-update prompt is disabled).

Machine-specific settings that shouldn't be committed go in `~/.zshrc.local`, which the managed `zshrc` sources last.

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
| Formatting | conform.nvim (pint, blade-formatter, biome, prettier, …) |
| Linting | nvim-lint (phpstan/larastan, biome) |
| PHP / Laravel | intelephense + [laravel.nvim](https://github.com/adalessa/laravel.nvim) |
| Debugging | nvim-dap + dap-ui (Xdebug) |
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
| `<leader>li` | Import class under cursor (PHP) |
| `<leader>lf` | Format buffer |
| `<leader>ln` | Lint buffer now |
| `<leader>ll` | Laravel picker (artisan, routes, make, …) |
| `<leader>la` | Artisan commands |
| `<leader>lr` | Routes |
| `<leader>lu` | Artisan hub (serve, pail, vite, …) |
| `<C-g>` | Blade view finder |
| `gf` | Follow `route()` / `view()` / `config()` / `Inertia::render()` |
| `<leader>bb` | Toggle breakpoint |
| `<leader>bc` / `<F5>` | Start / continue debugging |
| `<leader>bt` | Toggle debug UI |

### PHP / Laravel

`configs/nvim/lua/plugins/php.lua` wires up [laravel.nvim](https://github.com/adalessa/laravel.nvim)
(artisan, routes, model info, blade-aware `gf`, Tinker, completion for views/routes/config/env),
Intelephense as the language server, treesitter `php`/`php_only`/`phpdoc`/`blade`, pint for
formatting, phpstan/larastan for diagnostics and Xdebug through nvim-dap.

One-time setup:

```sh
dot install intelephense          # language server + guided licence setup
nvim +"MasonInstall php-debug-adapter" +qa
npm i -g blade-formatter          # optional: blade template formatting
```

**Intelephense licence** — `dot install intelephense` explains what the premium
licence adds, points at [intelephense.com](https://intelephense.com), then reads
the key with hidden input and stores it in `~/.config/intelephense/licence.txt`
(mode 600, never in this repo). Run it again any time with:

```sh
dot config intelephense           # add or replace the key
dot status intelephense           # masked key + server version
```

Neovim reads the key from `$INTELEPHENSE_LICENCE_KEY`,
`~/.config/intelephense/licence.txt` or `~/intelephense/licence.txt`, in that
order — so a key you already have keeps working.

**Auto-importing** — with the licence, accepting a class from the completion
menu writes its `use` statement (`completion.insertUseDeclaration`). For a
symbol you already typed, `<leader>li` applies Intelephense's import code
action directly.

**Eloquent magic methods** — `Model::create(…)` / `Model::where(…)` are flagged
as undefined until the stubs exist. `:LaravelIdeHelper` runs
`ide-helper:generate`, `ide-helper:models --nowrite` and `ide-helper:meta`
(through the project's runner, so it works in a container) and restarts
Intelephense afterwards. Install the package first:

```sh
composer require --dev barryvdh/laravel-ide-helper
```

laravel.nvim also generates a typed `Builder<Model>` doc-block in `vendor/`
(`eloquent_generate_doc_blocks`, on by default), which fixes most query chains.

**Blade** — `@` directives complete from `lua/snippets/blade.lua`
(`@foreach`, `@forelse`, `@props`, `@error`, …, with their closing tags);
laravel.nvim completes view names, routes, config keys and env vars.

### Running project tools in Docker

pint, phpstan, artisan, biome and friends usually live *inside* a project's
container. Drop a `.nvim-tools.json` in the project root (`:ProjectToolsInit`
scaffolds one) and every integration — conform, nvim-lint, nvim-dap and
laravel.nvim's artisan/composer/npm — runs its commands there and translates
paths between host and container:

```jsonc
{
  "runner": "compose",            // local | docker | compose | sail | custom
  "service": "app",               // compose/sail service
  "workdir": "/var/www/html",     // project root inside the container
  "user": "www-data",             // optional
  "compose_file": "docker-compose.dev.yml",
  "xdebug": { "port": 9003 },
  "tools": {
    "phpstan": { "args": ["--memory-limit=1G"], "level": 6 },
    "blade-formatter": { "runner": "local" },
    "biome": { "service": "node", "workdir": "/app" }
  }
}
```

| Runner | Command it builds |
|---|---|
| `local` | `vendor/bin/pint …` |
| `docker` | `docker exec -i -w <workdir> <container> vendor/bin/pint …` |
| `compose` | `docker compose exec -T -w <workdir> <service> vendor/bin/pint …` |
| `sail` | `vendor/bin/sail run vendor/bin/pint …` |
| `custom` | `<prefix…> vendor/bin/pint …` |

Every key can be overridden per tool, so a project whose front end lives in a
different container than PHP just says so under `tools`. `.nvim-tools.local.json`
is layered on top for machine-specific tweaks (handy when the shared file is
committed). JS/TS/JSON/CSS use **biome** when the project has a `biome.json`
(or a `tools.biome` entry) and fall back to prettier otherwise.

Rather than writing that file by hand, run `dot project init` in the project —
it detects the setup and fills it in:

```sh
dot project init          # detect and write .nvim-tools.json
dot project init --local  # machine-only override, offers to git-exclude it
dot project show          # the exact command each tool will run
dot project check         # run php/pint/phpstan/biome there and verify the workdir
```

Detection order: `vendor/bin/sail` → a **running container that bind-mounts this
project** (preferring its compose service name over the container name, so a
renamed container keeps working) → the compose file → local. `dot project check`
is the one to run when something looks wrong: it executes each tool in the
configured environment and confirms `workdir` really holds the project, which is
what makes phpstan diagnostics and Xdebug breakpoints land on the right lines.

| Command | What it does |
|---|---|
| `dot project init` | Detect containers and write `.nvim-tools.json` |
| `dot project check` | Verify the tools and path mapping actually work |
| `:ProjectTools` | Show the resolved command for every tool in this project |
| `:ProjectToolsInit` | Create/open `.nvim-tools.json` |
| `:ProjectToolsReload` | Re-read it (also automatic on save) |
| `:LaravelIdeHelper` | Regenerate ide-helper stubs in that same environment |

An annotated example lives in `configs/nvim/examples/nvim-tools.json`.

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
