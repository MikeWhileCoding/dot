#!/usr/bin/env zsh
# modules/neovim.sh — Neovim nightly from GitHub releases

MODULE_NAME="neovim"
MODULE_DESC="Neovim nightly — pre-built from GitHub releases"

_nvim_base_url="https://github.com/neovim/neovim/releases/download/nightly"

_nvim_asset() {
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "nvim-macos-arm64.tar.gz"   ;;
    macos-x86_64)  echo "nvim-macos-x86_64.tar.gz"  ;;
    linux-x86_64)  echo "nvim-linux-x86_64.tar.gz"  ;;
    linux-arm64)   echo "nvim-linux-arm64.tar.gz"    ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1 ;;
  esac
}

_nvim_url() {
  local asset
  asset="$(_nvim_asset)" || return 1
  echo "${_nvim_base_url}/${asset}"
}

_nvim_install_from_archive() {
  local url tmpdir
  url="$(_nvim_url)" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading Neovim nightly..."
  fetch "$url" "${tmpdir}/nvim.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  rm -rf "${DOT_OPT}/nvim"
  mkdir -p "${DOT_OPT}/nvim"
  tar -xzf "${tmpdir}/nvim.tar.gz" -C "${DOT_OPT}/nvim" --strip-components=1

  # Symlink the binary
  ln -sf "${DOT_OPT}/nvim/bin/nvim" "${DOT_BIN}/nvim"

  # Create vim wrapper shim
  cat > "${DOT_BIN}/vim" <<'SHIM'
#!/usr/bin/env zsh
exec "${HOME}/.local/bin/nvim" "$@"
SHIM
  chmod +x "${DOT_BIN}/vim"

  # Write etag stamp
  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "Neovim installed to ${DOT_OPT}/nvim"
}

module_install() {
  if [[ -x "${DOT_BIN}/nvim" ]]; then
    warn "Neovim is already installed (use 'dot update neovim' to update)"
    return 0
  fi
  _nvim_install_from_archive
}

module_update() {
  local url
  url="$(_nvim_url)" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/nvim"; then
    info "Update available for Neovim"
    _nvim_install_from_archive
  else
    success "Neovim is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/nvim" ]]; then
    local version stamp
    version="$("${DOT_BIN}/nvim" --version 2>/dev/null | head -1)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "Neovim: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "Neovim is not installed"
  fi
}
