# fzf shell integration for zsh
# Managed by dot CLI — edit in dotfiles repo, not in-place

# ── Key bindings ──────────────────────────────────────────────────────
# Ctrl+R  — interactive history search
# Ctrl+T  — fuzzy file finder, pastes path into current command
# Alt+C   — fuzzy directory finder, cd into selection

# Use cached fzf builtins (generated at install time) or fall back to manual bindings
if [[ -f "${HOME}/.config/fzf/fzf-builtins.zsh" ]]; then
  source "${HOME}/.config/fzf/fzf-builtins.zsh"
elif command -v fzf &>/dev/null; then
  # Fallback: manual key binding setup for older fzf versions

  # Ctrl+R — history search
  __fzf_history() {
    local selected
    selected=$(fc -rln 1 | fzf --height=40% --reverse --tac +s -q "${LBUFFER}")
    if [[ -n "$selected" ]]; then
      LBUFFER="$selected"
    fi
    zle redisplay
  }
  zle -N __fzf_history
  bindkey '^R' __fzf_history

  # Ctrl+T — file finder
  __fzf_file() {
    local selected
    selected=$(find . -path '*/\.*' -prune -o -type f -print -o -type l -print 2>/dev/null \
      | sed 's|^\./||' \
      | fzf --height=40% --reverse -m)
    if [[ -n "$selected" ]]; then
      LBUFFER="${LBUFFER}${selected}"
    fi
    zle redisplay
  }
  zle -N __fzf_file
  bindkey '^T' __fzf_file

  # Alt+C — directory changer
  __fzf_cd() {
    local selected
    selected=$(find . -path '*/\.*' -prune -o -type d -print 2>/dev/null \
      | sed 's|^\./||' \
      | fzf --height=40% --reverse +m)
    if [[ -n "$selected" ]]; then
      cd "$selected" || return
      zle accept-line
    fi
    zle redisplay
  }
  zle -N __fzf_cd
  bindkey '\ec' __fzf_cd
fi

# ── Default options ───────────────────────────────────────────────────
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline'

# Use ripgrep as default source if available (respects .gitignore)
if command -v rg &>/dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
