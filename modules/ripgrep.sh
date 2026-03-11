#!/usr/bin/env zsh
# modules/ripgrep.sh — ripgrep (rg) from GitHub releases

MODULE_NAME="ripgrep"
MODULE_DESC="ripgrep — fast recursive search that respects .gitignore"

_rg_repo="BurntSushi/ripgrep"

_rg_asset() {
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "ripgrep-VERSION-aarch64-apple-darwin.tar.gz"       ;;
    macos-x86_64)  echo "ripgrep-VERSION-x86_64-apple-darwin.tar.gz"        ;;
    linux-x86_64)  echo "ripgrep-VERSION-x86_64-unknown-linux-musl.tar.gz"  ;;
    linux-arm64)   echo "ripgrep-VERSION-aarch64-unknown-linux-gnu.tar.gz"  ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1 ;;
  esac
}

_rg_latest_version() {
  curl -fsSL -o /dev/null -w '%{url_effective}' \
    "https://github.com/${_rg_repo}/releases/latest" \
    | sed 's|.*/||'
}

_rg_url() {
  local version asset
  version="$(_rg_latest_version)" || return 1
  asset="$(_rg_asset)" || return 1
  asset="${asset//VERSION/${version}}"
  echo "https://github.com/${_rg_repo}/releases/download/${version}/${asset}"
}

_rg_install_from_release() {
  local url version tmpdir
  version="$(_rg_latest_version)" || return 1
  url="$(_rg_url)" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading ripgrep ${version}..."
  fetch "$url" "${tmpdir}/rg.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  mkdir -p "${tmpdir}/out"
  tar -xzf "${tmpdir}/rg.tar.gz" -C "${tmpdir}/out" --strip-components=1

  cp "${tmpdir}/out/rg" "${DOT_BIN}/rg"
  chmod +x "${DOT_BIN}/rg"

  # Install man page if present
  if [[ -f "${tmpdir}/out/doc/rg.1" ]]; then
    mkdir -p "${HOME}/.local/share/man/man1"
    cp "${tmpdir}/out/doc/rg.1" "${HOME}/.local/share/man/man1/"
  fi

  # Install shell completions if present
  if [[ -f "${tmpdir}/out/complete/_rg" ]]; then
    mkdir -p "${HOME}/.local/share/zsh/site-functions"
    cp "${tmpdir}/out/complete/_rg" "${HOME}/.local/share/zsh/site-functions/"
  fi

  # Write etag stamp
  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "ripgrep ${version} installed to ${DOT_BIN}/rg"
}

module_install() {
  if [[ -x "${DOT_BIN}/rg" ]]; then
    warn "ripgrep is already installed (use 'dot update ripgrep' to update)"
    return 0
  fi
  _rg_install_from_release
}

module_update() {
  local url
  url="$(_rg_url)" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/rg"; then
    info "Update available for ripgrep"
    _rg_install_from_release
  else
    success "ripgrep is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/rg" ]]; then
    local version stamp
    version="$("${DOT_BIN}/rg" --version 2>/dev/null | head -1)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "ripgrep: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "ripgrep is not installed"
  fi
}
