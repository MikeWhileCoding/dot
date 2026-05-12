#!/usr/bin/env zsh
# modules/aliases.sh — shell aliases (sail, etc.)

MODULE_NAME="aliases"
MODULE_DESC="aliases — common shell aliases managed by dot"

_aliases_setup() {
  local src="${DOT_REPO}/configs/aliases.zsh"
  local target="${HOME}/.config/dot/aliases.zsh"

  mkdir -p "${HOME}/.config/dot"
  ln -sf "$src" "$target"

  local source_line='[[ -f "${HOME}/.config/dot/aliases.zsh" ]] && source "${HOME}/.config/dot/aliases.zsh"'
  if [[ -f "${HOME}/.zshrc" ]]; then
    grep -qF 'dot/aliases.zsh' "${HOME}/.zshrc" || printf '\n# dot aliases\n%s\n' "$source_line" >> "${HOME}/.zshrc"
  fi
}

module_config() {
  _aliases_setup
}

module_install() {
  _aliases_setup
  success "aliases installed — restart your shell or run: source ~/.zshrc"
}

module_update() {
  _aliases_setup
  success "aliases up to date"
}

module_status() {
  local target="${HOME}/.config/dot/aliases.zsh"
  if [[ -L "$target" ]]; then
    success "aliases: symlink active → $target"
  else
    warn "aliases: not installed"
  fi
}
