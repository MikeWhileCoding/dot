#!/usr/bin/env zsh
# modules/claude.sh — Claude Code CLI via npm + claude-powerline statusline

MODULE_NAME="claude"
MODULE_DESC="claude — Anthropic's Claude Code CLI with powerline statusline"

_claude_npm_pkg="@anthropic-ai/claude-code"
_claude_registry_url="https://registry.npmjs.org/@anthropic-ai%2Fclaude-code/latest"

# `claude install` migrates from the npm shim to the native build: it stores
# the binary under ~/.local/share/claude/versions/<v> and points
# ~/.local/bin/claude at it. npm refuses to overwrite that symlink (EEXIST),
# so once the native build is in place updates must go through `claude update`.
_claude_is_native() {
  [[ -L "${DOT_BIN}/claude" ]] || return 1
  local target
  target="$(readlink "${DOT_BIN}/claude")"
  [[ "$target" == */share/claude/versions/* ]]
}

_claude_local_version() {
  "${DOT_BIN}/claude" --version 2>/dev/null | awk '{print $1}'
}

_claude_remote_version() {
  # The registry's /latest endpoint sends no ETag, so compare versions instead.
  curl -fsSL "$_claude_registry_url" 2>/dev/null \
    | sed -n 's/.*"version":"\([^"]*\)".*/\1/p'
}

_claude_require_npm() {
  # Try to activate nvm if npm isn't already in PATH
  if ! command -v npm &>/dev/null; then
    if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
      export NVM_DIR="${HOME}/.nvm"
      source "${NVM_DIR}/nvm.sh"
    fi
  fi
  if ! command -v npm &>/dev/null; then
    error "npm is required — install the nvm module first: dot install nvm"
    return 1
  fi
}

# Listing effortless in enabledPlugins/extraKnownMarketplaces doesn't fetch it,
# so add the marketplace and install the plugin through the CLI as well.
_claude_install_effortless() {
  local claude="${DOT_BIN}/claude"
  if "$claude" plugin list --json 2>/dev/null | grep -q '"effortless@effortless"'; then
    return 0
  fi

  if ! "$claude" plugin marketplace list --json 2>/dev/null | grep -q '"name": *"effortless"'; then
    info "Adding effortless marketplace..."
    "$claude" plugin marketplace add HeyCubit/effortless || {
      warn "Could not add the effortless marketplace"
      return 0
    }
  fi

  info "Installing effortless plugin..."
  "$claude" plugin install effortless@effortless || warn "Could not install the effortless plugin"
}

_claude_configure() {
  _claude_install_effortless

  local settings_dir="${HOME}/.claude"
  local settings_file="${settings_dir}/settings.json"
  mkdir -p "$settings_dir"

  [[ -f "$settings_file" ]] || echo '{}' > "$settings_file"
  python3 - "$settings_file" "${DOT_REPO}"/configs/claude/*.json <<'EOF'
import json, sys
path, fragments = sys.argv[1], sys.argv[2:]
with open(path) as f:
    cfg = json.load(f)

def merge(dst, src):
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            merge(dst[k], v)
        else:
            dst[k] = v

for fragment in fragments:
    with open(fragment) as f:
        merge(cfg, json.load(f))
cfg['statusLine'] = {
    "type": "command",
    "command": "npx -y @owloops/claude-powerline@latest --style=powerline"
}
with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
EOF

  success "Claude Code settings configured (claude-powerline, configs/claude/*.json)"
}

_claude_install_from_npm() {
  _claude_require_npm || return 1

  info "Installing ${_claude_npm_pkg}..."
  npm install -g --prefix "${HOME}/.local" "$_claude_npm_pkg" || {
    error "npm install failed"
    return 1
  }

  info "Running claude install (switching to the native build)..."
  "${DOT_BIN}/claude" install || { error "claude install failed"; return 1; }

  _claude_configure

  local version
  version="$(_claude_local_version)"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "$version"
  success "claude ${version} installed to ${DOT_BIN}/claude"
}

_claude_update_native() {
  info "Running claude update..."
  "${DOT_BIN}/claude" update || { error "claude update failed"; return 1; }

  local version
  version="$(_claude_local_version)"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "$version"
  success "claude ${version} is installed"
}

module_config() {
  _claude_configure
}

module_install() {
  if [[ -x "${DOT_BIN}/claude" ]]; then
    warn "claude is already installed (use 'dot update claude' to update)"
    _claude_configure
    return 0
  fi
  _claude_install_from_npm
}

module_update() {
  if [[ ! -x "${DOT_BIN}/claude" ]]; then
    _claude_install_from_npm
    return
  fi

  local local_version remote_version
  local_version="$(_claude_local_version)"
  remote_version="$(_claude_remote_version)"

  if [[ -n "$remote_version" && "$local_version" == "$remote_version" ]]; then
    success "claude ${local_version} is already up to date"
    write_stamp "$MODULE_NAME" "$local_version"
  elif _claude_is_native; then
    [[ -n "$remote_version" ]] && info "Update available for claude: ${local_version} -> ${remote_version}"
    _claude_update_native || return 1
  else
    [[ -n "$remote_version" ]] && info "Update available for claude: ${local_version} -> ${remote_version}"
    _claude_install_from_npm || return 1
  fi
  _claude_configure
}

module_status() {
  if [[ -x "${DOT_BIN}/claude" ]]; then
    local version
    version="$(_claude_local_version)"
    if _claude_is_native; then
      info "claude: ${version} (native build, self-updating)"
    else
      info "claude: ${version} (npm shim — 'dot update claude' will switch to the native build)"
    fi

    local settings="${HOME}/.claude/settings.json"
    if [[ -f "$settings" ]] && grep -q 'claude-powerline' "$settings" 2>/dev/null; then
      info "statusLine: claude-powerline (configured)"
    else
      warn "statusLine: not configured (run 'dot config claude' to fix)"
    fi

    if "${DOT_BIN}/claude" plugin list --json 2>/dev/null | grep -q '"effortless@effortless"'; then
      info "effortless: installed"
    else
      warn "effortless: not installed (run 'dot config claude' to fix)"
    fi
  else
    warn "claude is not installed"
  fi
}
