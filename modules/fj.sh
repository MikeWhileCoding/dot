#!/usr/bin/env zsh
# modules/fj.sh — forgejo-cli (fj), CLI for Forgejo instances such as Codeberg

MODULE_NAME="fj"
MODULE_DESC="fj — Forgejo CLI (forgejo-cli)"

_fj_repo="forgejo-contrib/forgejo-cli"

_fj_latest_version() {
  local version
  version="$(curl -fsSL "https://codeberg.org/api/v1/repos/${_fj_repo}/releases/latest" \
    | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)"
  if [[ -z "$version" ]]; then
    error "Failed to resolve latest version for ${_fj_repo}"
    return 1
  fi
  echo "$version"
}

# Upstream only ships Linux binaries; macOS has to build via cargo.
_fj_url() {
  local version="$1" asset
  case "${OS}-${ARCH}" in
    linux-x86_64) asset="forgejo-cli-x86_64-linux.tar.gz"  ;;
    linux-arm64)  asset="forgejo-cli-aarch64-linux.tar.gz" ;;
    *) return 1 ;;
  esac
  echo "https://codeberg.org/${_fj_repo}/releases/download/${version}/${asset}"
}

_fj_install_with_cargo() {
  if ! command -v cargo &>/dev/null; then
    error "No fj release binary for ${OS}-${ARCH} and cargo is not installed"
    return 1
  fi
  info "Building fj with cargo..."
  cargo install --locked --root "${HOME}/.local" forgejo-cli || return 1
  success "fj installed to ${DOT_BIN}/fj"
}

_fj_install() {
  local version url tmpdir
  version="$(_fj_latest_version)" || return 1
  url="$(_fj_url "$version")" || { _fj_install_with_cargo; return; }
  tmpdir="$(mktemp -d)"

  info "Downloading fj ${version}..."
  fetch "$url" "${tmpdir}/fj.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  # The release tarball is flat: fj sits at the archive root.
  tar -xzf "${tmpdir}/fj.tar.gz" -C "$tmpdir" fj
  cp "${tmpdir}/fj" "${DOT_BIN}/fj"
  chmod +x "${DOT_BIN}/fj"

  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "fj ${version} installed to ${DOT_BIN}/fj"
}

module_install() {
  if [[ -x "${DOT_BIN}/fj" ]]; then
    warn "fj is already installed (use 'dot update fj' to update)"
    return 0
  fi
  _fj_install
}

module_update() {
  local version url
  version="$(_fj_latest_version)" || return 1
  url="$(_fj_url "$version")" || { _fj_install_with_cargo; return; }

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/fj"; then
    info "Update available for fj"
    _fj_install
  else
    success "fj is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/fj" ]]; then
    local version stamp
    # fj has no --version flag; `fj version` prints "fj vX.Y.Z" plus a hint line.
    version="$("${DOT_BIN}/fj" version 2>/dev/null | awk '/^fj v/ { print $2; exit }')" || true
    stamp="$(read_stamp "$MODULE_NAME")"
    info "fj: ${version:-unknown} (${DOT_BIN}/fj)"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  elif command -v fj &>/dev/null; then
    warn "fj found at $(command -v fj) but is not managed by dot"
  else
    warn "fj is not installed"
  fi
}
