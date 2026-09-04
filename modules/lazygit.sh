#!/usr/bin/env zsh
# modules/lazygit.sh — lazygit TUI for git + managed config

MODULE_NAME="lazygit"
MODULE_DESC="lazygit — terminal UI for git"

_lazygit_repo="jesseduffield/lazygit"

_lazygit_asset() {
  local version="${1#v}"
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "lazygit_${version}_Darwin_arm64.tar.gz"  ;;
    macos-x86_64)  echo "lazygit_${version}_Darwin_x86_64.tar.gz" ;;
    linux-x86_64)  echo "lazygit_${version}_Linux_x86_64.tar.gz"  ;;
    linux-arm64)   echo "lazygit_${version}_Linux_arm64.tar.gz"   ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1      ;;
  esac
}

_lazygit_url() {
  local version="$1" asset
  asset="$(_lazygit_asset "$version")" || return 1
  echo "https://github.com/${_lazygit_repo}/releases/download/${version}/${asset}"
}

# Mirrors lazygit's own config-dir resolution (see `lazygit --print-config-dir`):
# XDG_CONFIG_HOME wins, then macOS uses Application Support, else ~/.config.
_lazygit_config_dir() {
  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    echo "${XDG_CONFIG_HOME}/lazygit"
  elif [[ "$OS" == "macos" ]]; then
    echo "${HOME}/Library/Application Support/lazygit"
  else
    echo "${HOME}/.config/lazygit"
  fi
}

_lazygit_install_from_release() {
  local version url tmpdir
  version="$(github_latest_version "$_lazygit_repo")" || return 1
  url="$(_lazygit_url "$version")" || return 1
  tmpdir="$(mktemp -d)"

  info "Downloading lazygit ${version}..."
  fetch "$url" "${tmpdir}/lazygit.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  mkdir -p "${tmpdir}/out"
  # The release tarball is flat: lazygit sits at the archive root.
  tar -xzf "${tmpdir}/lazygit.tar.gz" -C "${tmpdir}/out" lazygit

  cp "${tmpdir}/out/lazygit" "${DOT_BIN}/lazygit"
  chmod +x "${DOT_BIN}/lazygit"

  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "lazygit ${version} installed to ${DOT_BIN}/lazygit"
}

_lazygit_deploy_config() {
  local src="${DOT_REPO}/configs/lazygit.yml"
  local dir dst
  dir="$(_lazygit_config_dir)"
  dst="${dir}/config.yml"

  if [[ ! -f "$src" ]]; then
    warn "No lazygit config found at ${src} — skipping config link"
    return 0
  fi

  if [[ -L "$dst" ]]; then
    success "lazygit config already linked"
    return 0
  fi

  if [[ -f "$dst" ]]; then
    warn "${dst} exists and is not a symlink; backing up to ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi

  mkdir -p "$dir"
  ln -sf "$src" "$dst"
  success "lazygit config linked: ${dst} → ${src}"
}

module_config() {
  _lazygit_deploy_config
}

module_install() {
  if [[ -x "${DOT_BIN}/lazygit" ]]; then
    warn "lazygit is already installed (use 'dot update lazygit' to update)"
  else
    _lazygit_install_from_release || return 1
  fi
  _lazygit_deploy_config
}

module_update() {
  local version url
  version="$(github_latest_version "$_lazygit_repo")" || return 1
  url="$(_lazygit_url "$version")" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/lazygit"; then
    info "Update available for lazygit"
    _lazygit_install_from_release || return 1
  else
    success "lazygit is already up to date"
  fi
  _lazygit_deploy_config
}

module_status() {
  if [[ -x "${DOT_BIN}/lazygit" ]]; then
    local version stamp
    # --version prints a comma-separated field list that ends with "git version=",
    # so pick the first bare `version=` field rather than the last match.
    version="$("${DOT_BIN}/lazygit" --version 2>/dev/null \
      | tr ',' '\n' | awk -F= '$1 ~ /^ *version$/ { print $2; exit }')"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "lazygit: ${version:-unknown} (${DOT_BIN}/lazygit)"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  elif command -v lazygit &>/dev/null; then
    warn "lazygit found at $(command -v lazygit) but is not managed by dot"
  else
    warn "lazygit is not installed"
  fi

  local dst
  dst="$(_lazygit_config_dir)/config.yml"
  if [[ -L "$dst" ]]; then
    info "Config: ${dst} → $(readlink "$dst")"
  elif [[ -f "$dst" ]]; then
    warn "Config: ${dst} exists but is not managed by dot"
  else
    warn "Config: not linked (run 'dot config lazygit')"
  fi
}
