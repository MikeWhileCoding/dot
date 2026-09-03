#!/usr/bin/env zsh
# modules/tree-sitter.sh — tree-sitter CLI from GitHub releases
#
# nvim-treesitter (`main` branch) shells out to the `tree-sitter` binary to
# build parsers, so Neovim reports "tree-sitter executable not found" and
# cannot install any parser without it.

MODULE_NAME="tree-sitter"
MODULE_DESC="tree-sitter CLI — required by nvim-treesitter to build parsers"

_ts_repo="tree-sitter/tree-sitter"

_ts_asset() {
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "tree-sitter-macos-arm64.gz" ;;
    macos-x86_64)  echo "tree-sitter-macos-x64.gz"   ;;
    linux-x86_64)  echo "tree-sitter-linux-x64.gz"   ;;
    linux-arm64)   echo "tree-sitter-linux-arm64.gz" ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1 ;;
  esac
}

_ts_url() {
  local version="$1" asset
  asset="$(_ts_asset)" || return 1
  echo "https://github.com/${_ts_repo}/releases/download/${version}/${asset}"
}

_ts_install_from_release() {
  local version url tmpdir
  version="$(github_latest_version "$_ts_repo")" || return 1
  url="$(_ts_url "$version")" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading tree-sitter ${version}..."
  fetch "$url" "${tmpdir}/tree-sitter.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  # The release asset is a single gzipped binary, not an archive.
  gunzip -c "${tmpdir}/tree-sitter.gz" > "${tmpdir}/tree-sitter" \
    || { error "Failed to decompress tree-sitter"; rm -rf "$tmpdir"; return 1; }

  mkdir -p "$DOT_BIN"
  cp "${tmpdir}/tree-sitter" "${DOT_BIN}/tree-sitter"
  chmod +x "${DOT_BIN}/tree-sitter"

  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "tree-sitter ${version} installed to ${DOT_BIN}/tree-sitter"
}

module_install() {
  if [[ -x "${DOT_BIN}/tree-sitter" ]]; then
    warn "tree-sitter is already installed (use 'dot update tree-sitter' to update)"
    return 0
  fi
  _ts_install_from_release
}

module_update() {
  local version url
  version="$(github_latest_version "$_ts_repo")" || return 1
  url="$(_ts_url "$version")" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/tree-sitter"; then
    info "Update available for tree-sitter"
    _ts_install_from_release
  else
    success "tree-sitter is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/tree-sitter" ]]; then
    local version stamp
    version="$("${DOT_BIN}/tree-sitter" --version 2>/dev/null | head -1)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "tree-sitter: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "tree-sitter is not installed (nvim-treesitter cannot build parsers)"
  fi
}
