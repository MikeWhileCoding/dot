#!/usr/bin/env zsh
# profiles/server.sh — lean server baseline

PROFILE_NAME="server"
PROFILE_DESC="Lean server baseline"

PROFILE_MODULES=(
  neovim
  tmux
  fzf
  ripgrep
  delta
)

profile_post_install() {
  ensure_path_entry
  success "Server profile ready"
}
