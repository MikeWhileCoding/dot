#!/usr/bin/env zsh
# modules/fzf.sh — fzf fuzzy finder from GitHub releases

MODULE_NAME="fzf"
MODULE_DESC="fzf — fuzzy finder for shell history, files, and directories"

_fzf_repo="junegunn/fzf"

_fzf_asset() {
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "fzf-VERSION-darwin_arm64.zip"    ;;
    macos-x86_64)  echo "fzf-VERSION-darwin_amd64.zip"    ;;
    linux-x86_64)  echo "fzf-VERSION-linux_amd64.tar.gz"  ;;
    linux-arm64)   echo "fzf-VERSION-linux_arm64.tar.gz"  ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1 ;;
  esac
}

_fzf_latest_version() {
  curl -fsSL -o /dev/null -w '%{url_effective}' \
    "https://github.com/${_fzf_repo}/releases/latest" \
    | sed 's|.*/||'
}

_fzf_url() {
  local version asset
  version="$(_fzf_latest_version)" || return 1
  asset="$(_fzf_asset)" || return 1
  asset="${asset//VERSION/${version}}"
  echo "https://github.com/${_fzf_repo}/releases/download/${version}/${asset}"
}

_fzf_install_from_release() {
  local url version tmpdir
  version="$(_fzf_latest_version)" || return 1
  url="$(_fzf_url)" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading fzf ${version}..."
  fetch "$url" "${tmpdir}/fzf-archive" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  if [[ "$url" == *.zip ]]; then
    unzip -o "${tmpdir}/fzf-archive" -d "${tmpdir}/out" > /dev/null
  else
    mkdir -p "${tmpdir}/out"
    tar -xzf "${tmpdir}/fzf-archive" -C "${tmpdir}/out"
  fi

  cp "${tmpdir}/out/fzf" "${DOT_BIN}/fzf"
  chmod +x "${DOT_BIN}/fzf"

  # Write etag stamp
  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"

  # Deploy shell integration
  _fzf_setup_shell_integration

  success "fzf ${version} installed to ${DOT_BIN}/fzf"
}

_fzf_setup_shell_integration() {
  local fzf_config="${DOT_REPO}/configs/fzf.zsh"
  local target="${HOME}/.config/fzf/fzf.zsh"

  mkdir -p "${HOME}/.config/fzf"
  ln -sf "$fzf_config" "$target"

  # Source from .zshrc if not already present
  local source_line='[[ -f "${HOME}/.config/fzf/fzf.zsh" ]] && source "${HOME}/.config/fzf/fzf.zsh"'
  if [[ -f "${HOME}/.zshrc" ]]; then
    grep -qF 'fzf/fzf.zsh' "${HOME}/.zshrc" || printf '\n# fzf shell integration\n%s\n' "$source_line" >> "${HOME}/.zshrc"
  fi
}

module_install() {
  if [[ -x "${DOT_BIN}/fzf" ]]; then
    warn "fzf is already installed (use 'dot update fzf' to update)"
    return 0
  fi
  _fzf_install_from_release
}

module_update() {
  local url
  url="$(_fzf_url)" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/fzf"; then
    info "Update available for fzf"
    _fzf_install_from_release
  else
    success "fzf is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/fzf" ]]; then
    local version stamp
    version="$("${DOT_BIN}/fzf" --version 2>/dev/null | awk '{print $1}')"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "fzf: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "fzf is not installed"
  fi
}
