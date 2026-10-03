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
- `configs/nvim/lua/ai/init.lua` owns the on/off state for Copilot and Claude Code, persisted to `stdpath("state")/dot-ai.json`. `plugins/ai.lua` gates both plugins with a lazy `cond` that reads it, so anything that needs to know whether AI is on should call `require("ai").get(...)` / `.active()` rather than checking the plugins directly.
- Beware `set -euo pipefail` in `dot`: `(( x++ ))` returns non-zero when `x` is 0 and will abort the script — use `x=$(( x + 1 ))`.

# context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any Bash command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `ctx_fetch_and_index(url, source)` to fetch and index web pages
- `ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with Bash.
Instead use:
- `ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch — BLOCKED
WebFetch calls are denied entirely. The URL is extracted and you are told to use `ctx_fetch_and_index` instead.
Instead use:
- `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Bash (>20 lines output)
Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### Read (for analysis)
If you are reading a file to **Edit** it → Read is correct (Edit needs content in context).
If you are reading to **analyze, explore, or summarize** → use `ctx_execute_file(path, language, code)` instead. Only your printed summary enters context. The raw file content stays in the sandbox.

### Grep (large results)
Grep results can flood context. Use `ctx_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `ctx_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `ctx_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `ctx_execute(language, code)` | `ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `ctx_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically injected into their prompt. Bash-type subagents are upgraded to general-purpose so they have access to MCP tools. You do NOT need to manually instruct subagents about context-mode.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `ctx_search(source: "label")` later.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `ctx_stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `ctx_doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `ctx_upgrade` MCP tool, run the returned shell command, display as checklist |
