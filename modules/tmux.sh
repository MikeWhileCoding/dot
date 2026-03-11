#!/usr/bin/env zsh
# modules/tmux.sh — tmux terminal multiplexer + managed config

MODULE_NAME="tmux"
MODULE_DESC="tmux — terminal multiplexer with persistent sessions"

_tmux_install_binary() {
  # tmux doesn't ship pre-built binaries; use the system package manager
  if command -v tmux &>/dev/null; then
    info "tmux binary already available at $(command -v tmux)"
    return 0
  fi

  info "Installing tmux via package manager..."
  if [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      brew install tmux
    else
      error "Homebrew not found — install tmux manually or install Homebrew first"
      return 1
    fi
  elif [[ "$OS" == "linux" ]]; then
    if command -v apt-get &>/dev/null; then
      sudo apt-get update && sudo apt-get install -y tmux
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y tmux
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm tmux
    elif command -v apk &>/dev/null; then
      sudo apk add tmux
    else
      error "No supported package manager found — install tmux manually"
      return 1
    fi
  else
    error "Unsupported OS: ${OS}"
    return 1
  fi

  if command -v tmux &>/dev/null; then
    success "tmux installed via package manager"
  else
    error "tmux installation failed"
    return 1
  fi
}

_tmux_deploy_config() {
  local config_src="${DOT_REPO}/configs/tmux.conf"
  local config_dst="${HOME}/.tmux.conf"

  if [[ ! -f "$config_src" ]]; then
    warn "No tmux.conf found in configs — skipping config deployment"
    return 0
  fi

  ln -sf "$config_src" "$config_dst"
  info "Linked tmux.conf → ${config_dst}"

  # Reload config if tmux is running
  if tmux list-sessions &>/dev/null 2>&1; then
    tmux source-file "$config_dst" 2>/dev/null && info "Reloaded tmux config"
  fi
}

module_install() {
  _tmux_install_binary || return 1
  _tmux_deploy_config

  # Write a stamp so status works
  local version
  version="$(tmux -V 2>/dev/null | awk '{print $2}')"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "installed-${version}"

  success "tmux module ready"
}

module_update() {
  # For package-managed tmux, just redeploy the config
  if ! command -v tmux &>/dev/null; then
    warn "tmux binary not found — run 'dot install tmux' first"
    return 1
  fi

  _tmux_deploy_config

  local version
  version="$(tmux -V 2>/dev/null | awk '{print $2}')"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "installed-${version}"

  success "tmux config updated (upgrade the binary via your package manager)"
}

module_status() {
  if command -v tmux &>/dev/null; then
    local version stamp
    version="$(tmux -V 2>/dev/null)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "tmux: ${version}"
    [[ -n "$stamp" ]] && info "Stamp: ${stamp}"
    if [[ -L "${HOME}/.tmux.conf" ]]; then
      info "Config: ${HOME}/.tmux.conf → $(readlink "${HOME}/.tmux.conf")"
    elif [[ -f "${HOME}/.tmux.conf" ]]; then
      warn "Config: ${HOME}/.tmux.conf exists but is not managed by dot"
    fi
  else
    warn "tmux is not installed"
  fi
}
