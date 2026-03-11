#!/usr/bin/env zsh
# profiles/desktop.sh — full workstation setup

PROFILE_NAME="desktop"
PROFILE_DESC="Full workstation environment"

PROFILE_MODULES=(
  neovim
  # tmux
  # fzf
  # ripgrep
  # starship
  # zoxide
)

profile_post_install() {
  ensure_path_entry
  success "Desktop profile ready"
}
