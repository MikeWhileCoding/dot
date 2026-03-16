#!/usr/bin/env zsh
# modules/nvm.sh — Node Version Manager + Node.js LTS

MODULE_NAME="nvm"
MODULE_DESC="nvm — Node Version Manager with Node.js LTS (18+)"

_nvm_dir="${HOME}/.nvm"
_nvm_repo="nvm-sh/nvm"

_nvm_load() {
  export NVM_DIR="$_nvm_dir"
  [[ -s "${_nvm_dir}/nvm.sh" ]] && source "${_nvm_dir}/nvm.sh" --no-use
  # Activate the default alias so node/npm are in PATH
  nvm use default &>/dev/null || nvm use --lts &>/dev/null || true
}

_nvm_install() {
  local version url tmpfile
  version="$(github_latest_version "$_nvm_repo")" || return 1
  url="https://raw.githubusercontent.com/${_nvm_repo}/${version}/install.sh"
  tmpfile="$(mktemp)"

  info "Downloading nvm ${version}..."
  fetch "$url" "$tmpfile" || { error "Download failed"; rm -f "$tmpfile"; return 1; }

  # PROFILE=/dev/null prevents nvm from editing shell rc files; we do that ourselves
  info "Running nvm install script..."
  PROFILE=/dev/null bash "$tmpfile" || { error "nvm install script failed"; rm -f "$tmpfile"; return 1; }
  rm -f "$tmpfile"

  _nvm_load

  info "Installing Node.js LTS..."
  nvm install --lts || { error "Node.js LTS install failed"; return 1; }
  nvm alias default 'lts/*' 2>/dev/null || true

  # Add nvm init to .zshrc if not already present
  local nvm_init
  nvm_init='export NVM_DIR="${HOME}/.nvm"'$'\n''[[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"'
  if [[ -f "${HOME}/.zshrc" ]]; then
    grep -qF 'NVM_DIR' "${HOME}/.zshrc" || printf '\n# nvm\n%s\n' "$nvm_init" >> "${HOME}/.zshrc"
  fi

  local node_version
  node_version="$(node --version 2>/dev/null)"
  success "nvm ${version} + Node.js ${node_version} installed"
}

module_install() {
  if [[ -s "${_nvm_dir}/nvm.sh" ]]; then
    warn "nvm is already installed (use 'dot update nvm' to update)"
    _nvm_load
    if ! command -v node &>/dev/null; then
      info "Installing Node.js LTS..."
      nvm install --lts && nvm alias default 'lts/*' 2>/dev/null || true
    fi
    return 0
  fi
  _nvm_install
}

module_update() {
  if [[ ! -s "${_nvm_dir}/nvm.sh" ]]; then
    warn "nvm is not installed — run 'dot install nvm' first"
    return 1
  fi

  local latest installed
  latest="$(github_latest_version "$_nvm_repo")" || return 1
  _nvm_load
  installed="v$(nvm --version 2>/dev/null)"

  if [[ "$latest" != "$installed" ]]; then
    info "Updating nvm ${installed} → ${latest}"
    _nvm_install
  else
    info "Checking for Node.js LTS updates..."
    nvm install --lts && nvm alias default 'lts/*' 2>/dev/null || true
    success "nvm ${latest} is up to date"
  fi
}

module_status() {
  if [[ -s "${_nvm_dir}/nvm.sh" ]]; then
    _nvm_load
    local nvm_version node_version
    nvm_version="$(nvm --version 2>/dev/null)"
    node_version="$(node --version 2>/dev/null)"
    info "nvm: ${nvm_version}"
    info "node: ${node_version}"
  else
    warn "nvm is not installed"
  fi
}
