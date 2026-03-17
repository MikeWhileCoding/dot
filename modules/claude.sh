#!/usr/bin/env zsh
# modules/claude.sh — Claude Code CLI via npm + claude-powerline statusline

MODULE_NAME="claude"
MODULE_DESC="claude — Anthropic's Claude Code CLI with powerline statusline"

_claude_npm_pkg="@anthropic-ai/claude-code"
_claude_registry_url="https://registry.npmjs.org/@anthropic-ai%2Fclaude-code/latest"

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

_claude_configure_statusline() {
  local settings_dir="${HOME}/.claude"
  local settings_file="${settings_dir}/settings.json"
  mkdir -p "$settings_dir"

  if [[ -f "$settings_file" ]]; then
    python3 - "$settings_file" <<'EOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
cfg['statusLine'] = {
    "type": "command",
    "command": "npx -y @owloops/claude-powerline@latest --style=powerline"
}
with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
EOF
  else
    cat > "$settings_file" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "npx -y @owloops/claude-powerline@latest --style=powerline"
  }
}
EOF
  fi

  success "Claude Code statusLine configured (claude-powerline)"
}

_claude_install_from_npm() {
  _claude_require_npm || return 1

  info "Installing ${_claude_npm_pkg}..."
  npm install -g --prefix "${HOME}/.local" "$_claude_npm_pkg" || {
    error "npm install failed"
    return 1
  }

  local etag
  etag="$(remote_etag "$_claude_registry_url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  info "Running claude install..."
  "${DOT_BIN}/claude" install || { error "claude install failed"; return 1; }

  _claude_configure_statusline

  local version
  version="$("${DOT_BIN}/claude" --version 2>/dev/null)"
  success "claude ${version} installed to ${DOT_BIN}/claude"
}

module_install() {
  if [[ -x "${DOT_BIN}/claude" ]]; then
    warn "claude is already installed (use 'dot update claude' to update)"
    return 0
  fi
  _claude_install_from_npm
}

module_update() {
  if needs_update "$MODULE_NAME" "$_claude_registry_url" "${DOT_BIN}/claude"; then
    info "Update available for claude"
    _claude_install_from_npm
  else
    success "claude is already up to date"
  fi
  _claude_configure_statusline
}

module_status() {
  if [[ -x "${DOT_BIN}/claude" ]]; then
    local version stamp
    version="$("${DOT_BIN}/claude" --version 2>/dev/null)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "claude: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"

    local settings="${HOME}/.claude/settings.json"
    if [[ -f "$settings" ]] && grep -q 'claude-powerline' "$settings" 2>/dev/null; then
      info "statusLine: claude-powerline (configured)"
    else
      warn "statusLine: not configured (run 'dot install claude' to fix)"
    fi
  else
    warn "claude is not installed"
  fi
}
