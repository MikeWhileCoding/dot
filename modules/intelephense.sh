#!/usr/bin/env zsh
# modules/intelephense.sh — Intelephense PHP language server + premium licence

MODULE_NAME="intelephense"
MODULE_DESC="Intelephense PHP language server (+ premium licence setup)"

# Where our Neovim config looks for the key first. Intelephense's own default
# is ~/intelephense/licence.txt, which we offer to link at the end.
_intelephense_licence_file="${HOME}/.config/intelephense/licence.txt"
_intelephense_native_file="${HOME}/intelephense/licence.txt"
_intelephense_dir="${DOT_OPT}/intelephense"

_intelephense_mask() {
  # _intelephense_mask <key> — show enough to recognise it, not to reuse it
  local key="$1"
  if (( ${#key} <= 8 )); then
    printf '%s\n' "********"
  else
    printf '%s…%s\n' "${key:0:4}" "${key: -4}"
  fi
}

_intelephense_stored_key() {
  local file
  for file in "$_intelephense_licence_file" "$_intelephense_native_file"; do
    if [[ -s "$file" ]]; then
      tr -d '[:space:]' < "$file"
      return 0
    fi
  done
  return 1
}

_intelephense_write_key() {
  # _intelephense_write_key <key>
  local key="$1"
  mkdir -p "${_intelephense_licence_file:h}"
  printf '%s' "$key" > "$_intelephense_licence_file"
  chmod 600 "$_intelephense_licence_file"
  success "Licence saved to ${_intelephense_licence_file} (mode 600)"

  # Intelephense itself reads ~/intelephense/licence.txt. Neovim passes the key
  # directly, but linking it means any other editor or a bare `intelephense`
  # run picks it up too.
  if [[ ! -e "$_intelephense_native_file" ]]; then
    if confirm "Also link ${_intelephense_native_file} (Intelephense's own default)?"; then
      mkdir -p "${_intelephense_native_file:h}"
      ln -sf "$_intelephense_licence_file" "$_intelephense_native_file"
      success "Linked ${_intelephense_native_file} → ${_intelephense_licence_file}"
    fi
  fi
}

_intelephense_setup_licence() {
  header "Intelephense licence"

  local existing=""
  if existing="$(_intelephense_stored_key)"; then
    success "A licence key is already configured: $(_intelephense_mask "$existing")"
    info "  File: $([[ -s $_intelephense_licence_file ]] && echo $_intelephense_licence_file || echo $_intelephense_native_file)"
    confirm "Replace it with a different key?" || return 0
  else
    info "Intelephense is free to use; the premium licence adds rename,"
    info "code actions, find-implementations and go-to-type-definition."
    info "It is a one-time purchase (USD 25, lifetime) from:"
    info "  ${_c_bold}https://intelephense.com${_c_reset}"
    echo
    info "You receive the key by email — it looks like a 15-character string."
  fi

  # Non-interactive (profile install, CI): leave a breadcrumb and move on.
  if [[ ! -t 0 ]]; then
    warn "Not a TTY — skipping the licence prompt"
    info "  Run later: dot config intelephense"
    return 0
  fi

  local key=""
  if [[ -n "${INTELEPHENSE_LICENCE_KEY:-}" ]]; then
    if confirm "Use the key from \$INTELEPHENSE_LICENCE_KEY ($(_intelephense_mask "$INTELEPHENSE_LICENCE_KEY"))?"; then
      key="$INTELEPHENSE_LICENCE_KEY"
    fi
  fi

  if [[ -z "$key" ]]; then
    confirm "Enter your licence key now?" || {
      info "Skipped — run 'dot config intelephense' whenever you have the key"
      return 0
    }
    printf "%s[?]%s     Licence key (input hidden): " "$_c_yellow" "$_c_reset"
    read -rs key || return 0
    echo
  fi

  key="$(printf '%s' "$key" | tr -d '[:space:]')"

  if [[ -z "$key" ]]; then
    warn "No key entered — nothing written"
    return 0
  fi
  if (( ${#key} < 10 )); then
    warn "That looks too short for a licence key (${#key} characters) — not saving"
    info "  Re-run: dot config intelephense"
    return 0
  fi

  _intelephense_write_key "$key"
  info "Neovim reads it on the next start; check with :LspInfo (premium features work immediately)"
}

_intelephense_npm() {
  if command -v npm &>/dev/null; then
    return 0
  fi
  warn "npm not found — Intelephense is a Node package"
  info "  Install Node first:  dot install nvm"
  info "  Or let Neovim handle the server:  :MasonInstall intelephense"
  return 1
}

_intelephense_install_server() {
  _intelephense_npm || return 1

  info "Installing intelephense via npm into ${_intelephense_dir}..."
  mkdir -p "$_intelephense_dir"
  # --prefix keeps it out of the global node prefix, so no sudo and no clash
  # with whatever the current nvm version has installed.
  if ! npm install --prefix "$_intelephense_dir" --silent intelephense; then
    error "npm install intelephense failed"
    return 1
  fi

  ln -sf "${_intelephense_dir}/node_modules/.bin/intelephense" "${DOT_BIN}/intelephense"
  success "Intelephense installed: ${DOT_BIN}/intelephense"
}

module_config() {
  _intelephense_setup_licence
}

module_install() {
  _intelephense_install_server || warn "Continuing with licence setup only"
  _intelephense_setup_licence
}

module_update() {
  if [[ ! -d "${_intelephense_dir}/node_modules" ]]; then
    warn "Intelephense is not installed here (use 'dot install intelephense')"
    return 0
  fi
  _intelephense_npm || return 1

  info "Updating intelephense..."
  npm update --prefix "$_intelephense_dir" --silent intelephense \
    && success "Intelephense: $("${DOT_BIN}/intelephense" --version 2>/dev/null || echo updated)" \
    || error "Update failed"
}

module_status() {
  if [[ -x "${DOT_BIN}/intelephense" ]]; then
    info "Intelephense: $("${DOT_BIN}/intelephense" --version 2>/dev/null || echo installed) (${DOT_BIN}/intelephense)"
  elif command -v intelephense &>/dev/null; then
    info "Intelephense: $(intelephense --version 2>/dev/null || echo found) ($(command -v intelephense))"
  else
    warn "Intelephense: not installed (Mason may still provide it inside Neovim)"
  fi

  local key
  if key="$(_intelephense_stored_key)"; then
    success "Licence: $(_intelephense_mask "$key") — premium features enabled"
  else
    warn "Licence: none — run 'dot config intelephense' to add your key"
  fi
}
