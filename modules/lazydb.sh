#!/usr/bin/env zsh
# modules/lazydb.sh — LazyDB terminal database IDE + Claude Code MCP server

MODULE_NAME="lazydb"
MODULE_DESC="lazydb — terminal database IDE (with Claude Code MCP)"

_lazydb_installer="https://lazydb.yelog.org/install.sh"
# The installer resolves the release from this manifest, so its ETag changes
# exactly when a new stable release is published.
_lazydb_manifest="https://lazydb.yelog.org/channels/stable.json"

_lazydb_install() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  fetch "$_lazydb_installer" "${tmpdir}/install.sh" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  # --no-modify-path: the installer resolves ~/.zshrc through its symlink and
  # would write into configs/zshrc. DOT_BIN is already on PATH.
  # --mcp-setup skip: MCP is registered below, user-wide.
  info "Running LazyDB installer..."
  sh "${tmpdir}/install.sh" --install-dir "$DOT_BIN" --no-modify-path --mcp-setup skip \
    || { error "LazyDB installer failed"; rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"

  local etag
  etag="$(remote_etag "$_lazydb_manifest")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"
  success "lazydb installed to ${DOT_BIN}/lazydb"
}

# User-scoped so every project gets it; `--project .` resolves against the
# directory Claude Code runs in. Writes are allowed on non-production
# profiles only; production profiles stay read-only.
_lazydb_configure_mcp() {
  command -v claude &>/dev/null || { warn "claude not found — skipping LazyDB MCP registration"; return 0; }
  if claude mcp get lazydb &>/dev/null; then
    success "LazyDB MCP already registered with Claude Code"
    return 0
  fi
  claude mcp add --scope user lazydb -- lazydb mcp serve --project . --write-policy non-production \
    && success "LazyDB MCP registered with Claude Code (user scope, non-production writes)"
}

module_install() {
  if [[ -x "${DOT_BIN}/lazydb" ]]; then
    warn "lazydb is already installed (use 'dot update lazydb' to update)"
  else
    _lazydb_install || return 1
  fi
  _lazydb_configure_mcp
}

module_update() {
  if needs_update "$MODULE_NAME" "$_lazydb_manifest" "${DOT_BIN}/lazydb"; then
    info "Update available for lazydb"
    _lazydb_install || return 1
  else
    success "lazydb is already up to date"
  fi
  _lazydb_configure_mcp
}

module_status() {
  if [[ -x "${DOT_BIN}/lazydb" ]]; then
    local version stamp
    version="$("${DOT_BIN}/lazydb" version --json 2>/dev/null | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p')"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "lazydb: ${version:-unknown} (${DOT_BIN}/lazydb)"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  elif command -v lazydb &>/dev/null; then
    warn "lazydb found at $(command -v lazydb) but is not managed by dot"
  else
    warn "lazydb is not installed"
  fi

  if command -v claude &>/dev/null && claude mcp get lazydb &>/dev/null; then
    info "MCP: registered with Claude Code"
  else
    warn "MCP: not registered (run 'dot install lazydb')"
  fi
}
