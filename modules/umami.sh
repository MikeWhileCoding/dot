#!/usr/bin/env zsh
# modules/umami.sh — Umami analytics MCP server for Claude Code

MODULE_NAME="umami"
MODULE_DESC="umami — Umami analytics MCP for Claude Code (token kept out of ~/.claude.json)"

_umami_url="https://apollo.mikedegroot.dev"
_umami_token_file="${HOME}/.config/umami/token"

# The MCP command reads the token from a mode-600 file at launch, so it never
# lands in ~/.claude.json (which Claude Code also copies into its backups).
_umami_configure_mcp() {
  command -v claude &>/dev/null || { warn "claude not found — skipping Umami MCP registration"; return 0; }
  if claude mcp get umami &>/dev/null; then
    success "Umami MCP already registered with Claude Code"
    return 0
  fi
  claude mcp add umami --scope user -e UMAMI_URL="$_umami_url" -- \
    sh -c 'UMAMI_API_TOKEN="$(cat "$HOME/.config/umami/token")" exec npx -y @umami/mcp' \
    && success "Umami MCP registered with Claude Code (user scope)"
}

_umami_setup_token() {
  if [[ -s "$_umami_token_file" ]]; then
    success "Umami API token already stored in ${_umami_token_file}"
    confirm "Replace it?" || return 0
  fi
  if [[ ! -t 0 ]]; then
    warn "Not a TTY — skipping the token prompt (run 'dot config umami' later)"
    return 0
  fi

  local token=""
  printf "%s[?]%s     Umami API token (input hidden, empty to skip): " "$_c_yellow" "$_c_reset"
  read -rs token || return 0
  echo
  token="$(printf '%s' "$token" | tr -d '[:space:]')"
  [[ -z "$token" ]] && { info "Skipped — run 'dot config umami' when you have the token"; return 0; }

  mkdir -p "${_umami_token_file:h}"
  ( umask 077; printf '%s' "$token" > "$_umami_token_file" )
  chmod 600 "$_umami_token_file"
  success "Token saved to ${_umami_token_file} (mode 600)"
}

module_config() {
  _umami_setup_token
}

module_install() {
  _umami_setup_token
  _umami_configure_mcp
}

module_update() {
  # npx -y fetches the latest @umami/mcp on each launch; nothing to update.
  _umami_configure_mcp
}

module_status() {
  if command -v claude &>/dev/null && claude mcp get umami &>/dev/null; then
    info "MCP: registered with Claude Code (${_umami_url})"
  else
    warn "MCP: not registered (run 'dot install umami')"
  fi
  if [[ -s "$_umami_token_file" ]]; then
    success "Token: stored in ${_umami_token_file}"
  else
    warn "Token: none — run 'dot config umami'"
  fi
}
