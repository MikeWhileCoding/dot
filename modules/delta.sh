#!/usr/bin/env zsh
# modules/delta.sh — delta git diff pager from GitHub releases

MODULE_NAME="delta"
MODULE_DESC="delta — syntax-highlighting pager for git diffs"

_delta_repo="dandavison/delta"

_delta_asset() {
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "delta-VERSION-aarch64-apple-darwin.tar.gz"          ;;
    macos-x86_64)  echo "delta-VERSION-x86_64-apple-darwin.tar.gz"           ;;
    linux-x86_64)  echo "delta-VERSION-x86_64-unknown-linux-musl.tar.gz"     ;;
    linux-arm64)   echo "delta-VERSION-aarch64-unknown-linux-gnu.tar.gz"     ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1 ;;
  esac
}

_delta_latest_version() {
  curl -fsSL -o /dev/null -w '%{url_effective}' \
    "https://github.com/${_delta_repo}/releases/latest" \
    | sed 's|.*/||'
}

_delta_url() {
  local version asset
  version="$(_delta_latest_version)" || return 1
  asset="$(_delta_asset)" || return 1
  asset="${asset//VERSION/${version}}"
  echo "https://github.com/${_delta_repo}/releases/download/${version}/${asset}"
}

_delta_install_from_release() {
  local url version tmpdir
  version="$(_delta_latest_version)" || return 1
  url="$(_delta_url)" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading delta ${version}..."
  fetch "$url" "${tmpdir}/delta.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  mkdir -p "${tmpdir}/out"
  tar -xzf "${tmpdir}/delta.tar.gz" -C "${tmpdir}/out" --strip-components=1

  cp "${tmpdir}/out/delta" "${DOT_BIN}/delta"
  chmod +x "${DOT_BIN}/delta"

  # Write etag stamp
  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"

  # Configure git to use delta
  _delta_configure_git

  success "delta ${version} installed to ${DOT_BIN}/delta"
}

_delta_configure_git() {
  # Set delta as the git pager
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"

  # Delta-specific git config
  git config --global delta.navigate true
  git config --global delta.dark true
  git config --global delta.line-numbers true
  git config --global delta.syntax-theme "ansi"
  git config --global delta.side-by-side false

  # Better merge conflict display
  git config --global merge.conflictstyle zdiff3

  info "Configured git to use delta as pager"
}

module_install() {
  if [[ -x "${DOT_BIN}/delta" ]]; then
    warn "delta is already installed (use 'dot update delta' to update)"
    return 0
  fi
  _delta_install_from_release
}

module_update() {
  local url
  url="$(_delta_url)" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/delta"; then
    info "Update available for delta"
    _delta_install_from_release
  else
    success "delta is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/delta" ]]; then
    local version stamp
    version="$("${DOT_BIN}/delta" --version 2>/dev/null)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "delta: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
    local pager
    pager="$(git config --global --get core.pager 2>/dev/null)"
    if [[ "$pager" == "delta" ]]; then
      info "Git pager: configured"
    else
      warn "Git pager: not configured (run 'dot install delta' to set up)"
    fi
  else
    warn "delta is not installed"
  fi
}
