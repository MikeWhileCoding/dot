# aliases.zsh — shell aliases
# Managed by dot CLI — edit in dotfiles repo, not in-place

# Laravel Sail — run from any project directory
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'

# devsetup — create a tmux session with lazygit, nvim, claude, and 2 terminals
devsetup() {
  local dir="${1:-.}"
  local session="dev-$(basename "$dir")"

  # Reuse existing session if it exists
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux attach-session -t "$session"
    return
  fi

  # Create new session with lazygit in first window
  tmux new-session -d -s "$session" -c "$dir" -x 200 -y 50 "lazygit"

  # Add windows for each tool
  tmux new-window -t "$session" -n "nvim" -c "$dir" "nvim"
  tmux new-window -t "$session" -n "claude" -c "$dir" "claude"
  tmux new-window -t "$session" -n "term1" -c "$dir"
  tmux new-window -t "$session" -n "term2" -c "$dir"

  # Attach to the session
  tmux attach-session -t "$session"
}
