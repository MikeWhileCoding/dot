#!/usr/bin/env zsh
# modules/uv.sh — uv Python package manager from GitHub releases

MODULE_NAME="uv"
MODULE_DESC="uv — fast Python package and project manager"

_uv_repo="astral-sh/uv"

_uv_asset() {
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "uv-aarch64-apple-darwin.tar.gz"        ;;
    macos-x86_64)  echo "uv-x86_64-apple-darwin.tar.gz"         ;;
    linux-x86_64)  echo "uv-x86_64-unknown-linux-musl.tar.gz"   ;;
    linux-arm64)   echo "uv-aarch64-unknown-linux-musl.tar.gz"  ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1    ;;
  esac
}

_uv_url() {
  local version="$1" asset
  asset="$(_uv_asset)" || return 1
  echo "https://github.com/${_uv_repo}/releases/download/${version}/${asset}"
}

_uv_install_from_release() {
  local version url tmpdir
  version="$(github_latest_version "$_uv_repo")" || return 1
  url="$(_uv_url "$version")" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading uv ${version}..."
  fetch "$url" "${tmpdir}/uv.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  tar -xzf "${tmpdir}/uv.tar.gz" -C "${tmpdir}" --strip-components=1

  cp "${tmpdir}/uv"  "${DOT_BIN}/uv"
  cp "${tmpdir}/uvx" "${DOT_BIN}/uvx"
  chmod +x "${DOT_BIN}/uv" "${DOT_BIN}/uvx"

  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "uv ${version} installed to ${DOT_BIN}/uv"
}

module_install() {
  if [[ -x "${DOT_BIN}/uv" ]]; then
    warn "uv is already installed (use 'dot update uv' to update)"
    return 0
  fi
  _uv_install_from_release
}

module_update() {
  local version url
  version="$(github_latest_version "$_uv_repo")" || return 1
  url="$(_uv_url "$version")" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/uv"; then
    info "Update available for uv"
    _uv_install_from_release
  else
    success "uv is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/uv" ]]; then
    local version stamp
    version="$("${DOT_BIN}/uv" --version 2>/dev/null)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "uv: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "uv is not installed"
  fi
}
