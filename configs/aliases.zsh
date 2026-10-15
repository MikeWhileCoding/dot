# aliases.zsh — shell aliases
# Managed by dot CLI — edit in dotfiles repo, not in-place

# Laravel Sail — run from any project directory
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'

# devsetup — create a tmux session with lazygit, nvim, claude, and 2 terminals.
# The session is named after the project (git root, else the given folder);
# tmux shows that name as the terminal title.
devsetup() {
  local dir="${1:-.}"
  dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "${dir:A}")"
  local session="${${dir:t}//[.:]/_}"  # tmux forbids . and : in session names

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

# oddn — `docker compose down` every running orderdesk project
# (~/coding/orderdesk and ~/coding/projecten-orderdesk/*), found via compose labels.
oddn() {
  local project dir
  docker ps --format '{{.Label "com.docker.compose.project"}} {{.Label "com.docker.compose.project.working_dir"}}' \
    | sort -u \
    | while read -r project dir; do
        [[ "$dir" == "$HOME/coding/orderdesk" || "$dir" == "$HOME/coding/projecten-orderdesk/"* ]] || continue
        echo "==> $project ($dir)"
        docker compose -p "$project" down
      done
}

# lazydb — vague theme outside Neovim (lazydb.nvim already follows the
# colorscheme). Regenerate configs/lazydb/vague.json from Neovim with
# `require("lazydb.theme").resolve()` if the palette changes.
alias lazydb="lazydb --theme-file ${${(%):-%x}:A:h}/lazydb/vague.json"
