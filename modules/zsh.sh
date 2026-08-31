#!/usr/bin/env zsh
# modules/zsh.sh — zsh itself: the shell dot runs on

MODULE_NAME="zsh"
MODULE_DESC="zsh — the shell dot runs on, plus oh-my-zsh and ~/.zshrc"

_zsh_repo="zsh-users/zsh"
_zsh_fallback_version="5.9"
_zsh_omz_repo="https://github.com/ohmyzsh/ohmyzsh.git"

_zsh_bin() {
  if [[ -x "${DOT_BIN}/zsh" ]]; then
    echo "${DOT_BIN}/zsh"
  elif command -v zsh &>/dev/null; then
    command -v zsh
  fi
}

_zsh_latest_version() {
  # zsh release tags look like "zsh-5.9"
  local tag
  tag="$(github_latest_version "$_zsh_repo" 2>/dev/null)" || tag=""
  tag="${tag#zsh-}"
  [[ -z "$tag" ]] && tag="$_zsh_fallback_version"
  echo "$tag"
}

_zsh_build_from_source() {
  local version="$1" tmpdir url
  tmpdir="$(mktemp -d)"

  ensure_build_tools "building zsh from source" || { rm -rf "$tmpdir"; return 1; }
  ensure_ncurses "$tmpdir" || { rm -rf "$tmpdir"; return 1; }

  info "Downloading zsh ${version} source..."
  url="https://www.zsh.org/pub/zsh-${version}.tar.xz"
  if ! fetch "$url" "${tmpdir}/zsh.tar" 2>/dev/null; then
    url="https://www.zsh.org/pub/zsh-${version}.tar.gz"
    fetch "$url" "${tmpdir}/zsh.tar" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }
  fi

  info "Building zsh from source (no admin required)..."
  mkdir -p "${tmpdir}/src"
  # -xf auto-detects .xz / .gz on both GNU and BSD tar
  tar -xf "${tmpdir}/zsh.tar" -C "${tmpdir}/src" --strip-components=1 \
    || { error "Failed to extract zsh source"; rm -rf "$tmpdir"; return 1; }

  (
    cd "${tmpdir}/src" || return 1
    CPPFLAGS="-I${DOT_PREFIX}/include -I${DOT_PREFIX}/include/ncursesw ${CPPFLAGS:-}" \
    LDFLAGS="-L${DOT_PREFIX}/lib ${LDFLAGS:-}" \
      ./configure --prefix="${DOT_PREFIX}" --enable-multibyte 2>&1 | tail -1
    make -j"$(cpu_count)" 2>&1 | tail -1
    make install 2>&1 | tail -1
  ) || { error "zsh build failed"; rm -rf "$tmpdir"; return 1; }

  rm -rf "$tmpdir"

  if [[ ! -x "${DOT_BIN}/zsh" ]]; then
    error "zsh build finished but ${DOT_BIN}/zsh is missing"
    return 1
  fi
  success "zsh ${version} built into ${DOT_PREFIX}"
}

_zsh_install_binary() {
  if [[ -x "${DOT_BIN}/zsh" ]]; then
    info "zsh already installed at ${DOT_BIN}/zsh"
    return 0
  fi
  if command -v zsh &>/dev/null; then
    info "zsh already available at $(command -v zsh) ($(zsh --version 2>/dev/null))"
    return 0
  fi

  # Package manager first (fast), source build as the sudo-free fallback
  local cmd
  if cmd="$(pkg_install_cmd zsh)" && { [[ "$OS" == "macos" ]] || have_root; }; then
    info "zsh can be installed with: ${cmd}"
    if confirm "Run this now?"; then
      if eval "$cmd" && command -v zsh &>/dev/null; then
        success "zsh installed via package manager"
        return 0
      fi
      warn "Package install failed — falling back to a source build"
    fi
  fi

  _zsh_build_from_source "$(_zsh_latest_version)"
}

_zsh_omz_dir() {
  echo "${DOT_OPT}/oh-my-zsh"
}

# Plugin list lives in configs/zshrc — read it back for status output
_zsh_plugins() {
  sed -n '/^plugins=(/,/^)/p' "${DOT_REPO}/configs/zshrc" \
    | sed '1d;$d' | tr -d ' ' | grep -v '^$' | tr '\n' ' '
}

_zsh_install_omz() {
  local omz_dir
  omz_dir="$(_zsh_omz_dir)"

  if [[ -d "${omz_dir}/.git" ]]; then
    info "oh-my-zsh already installed at ${omz_dir}"
    return 0
  fi

  if ! command -v git &>/dev/null; then
    error "git is required to install oh-my-zsh — run 'dot init'"
    return 1
  fi

  info "Cloning oh-my-zsh into ${omz_dir}..."
  rm -rf "$omz_dir"
  git clone --depth=1 --quiet "$_zsh_omz_repo" "$omz_dir" \
    || { error "oh-my-zsh clone failed"; return 1; }

  success "oh-my-zsh installed (plugins: $(_zsh_plugins))"
}

_zsh_update_omz() {
  local omz_dir
  omz_dir="$(_zsh_omz_dir)"

  if [[ ! -d "${omz_dir}/.git" ]]; then
    _zsh_install_omz
    return $?
  fi

  info "Updating oh-my-zsh..."
  git -C "$omz_dir" pull --ff-only --quiet 2>/dev/null \
    || warn "oh-my-zsh update failed — leaving the current checkout in place"
  return 0
}

# Symlinks configs/zshrc → ~/.zshrc, which is what carries the plugin list
_zsh_link_zshrc() {
  local src="${DOT_REPO}/configs/zshrc"
  local dst="${HOME}/.zshrc"

  if [[ ! -f "$src" ]]; then
    warn "No zshrc found at ${src} — skipping"
    return 0
  fi

  if [[ -L "$dst" && "${dst:A}" == "$src" ]]; then
    info "~/.zshrc already linked"
    return 0
  fi

  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "~/.zshrc exists and is not managed by dot — backing up to ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi

  ln -sf "$src" "$dst"
  success "Linked ~/.zshrc → ${src}"
}

_zsh_suggest_default_shell() {
  local zsh_path current_shell
  zsh_path="$(_zsh_bin)"
  [[ -z "$zsh_path" ]] && return 0

  current_shell="${SHELL:-}"
  if [[ "${current_shell:t}" == "zsh" ]]; then
    info "zsh is already your login shell"
    return 0
  fi

  warn "Your login shell is ${current_shell:-unknown}, not zsh"
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    info "First register it: echo '${zsh_path}' | sudo tee -a /etc/shells"
  fi
  info "Make it default:   chsh -s ${zsh_path}"
}

module_config() {
  _zsh_link_zshrc
  ensure_path_entry
  if [[ ! -d "$(_zsh_omz_dir)/.git" ]]; then
    warn "oh-my-zsh is not installed — run 'dot install zsh'"
  fi
  _zsh_suggest_default_shell
}

module_install() {
  _zsh_install_binary || return 1
  _zsh_install_omz    || return 1
  _zsh_link_zshrc
  ensure_path_entry

  local zsh_path version
  zsh_path="$(_zsh_bin)"
  version="$("$zsh_path" --version 2>/dev/null | awk '{print $2}')"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "installed-${version}"

  _zsh_suggest_default_shell
  success "zsh module ready"
}

module_update() {
  local zsh_path
  zsh_path="$(_zsh_bin)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh not found — run 'dot install zsh' first"
    return 1
  fi

  _zsh_update_omz
  _zsh_link_zshrc

  # Only manage upgrades for source builds we own; system zsh belongs to the OS
  if [[ "$zsh_path" == "${DOT_BIN}/zsh" ]]; then
    local current latest
    current="$("$zsh_path" --version 2>/dev/null | awk '{print $2}')"
    latest="$(_zsh_latest_version)"
    if [[ "$current" != "$latest" ]]; then
      info "Updating zsh ${current} → ${latest}"
      _zsh_build_from_source "$latest" || return 1
      write_stamp "$MODULE_NAME" "installed-${latest}"
    else
      info "zsh ${current} is already the latest"
    fi
  else
    info "zsh at ${zsh_path} is managed by the system — nothing to update"
  fi

  success "zsh up to date"
}

module_status() {
  local zsh_path
  zsh_path="$(_zsh_bin)"
  if [[ -n "$zsh_path" ]]; then
    local stamp
    info "zsh: $("$zsh_path" --version 2>/dev/null) (${zsh_path})"
    stamp="$(read_stamp "$MODULE_NAME")"
    [[ -n "$stamp" ]] && info "Stamp: ${stamp}"
    if [[ "${SHELL:t}" == "zsh" ]]; then
      info "Login shell: ${SHELL}"
    else
      warn "Login shell: ${SHELL:-unknown} (run 'dot init' for how to switch)"
    fi

    local omz_dir
    omz_dir="$(_zsh_omz_dir)"
    if [[ -d "${omz_dir}/.git" ]]; then
      info "oh-my-zsh: $(git -C "$omz_dir" rev-parse --short HEAD 2>/dev/null) (${omz_dir})"
      info "Plugins: $(_zsh_plugins)"
    else
      warn "oh-my-zsh: not installed"
    fi

    if [[ -L "${HOME}/.zshrc" ]]; then
      info "Config: ${HOME}/.zshrc → $(readlink "${HOME}/.zshrc")"
    elif [[ -f "${HOME}/.zshrc" ]]; then
      warn "Config: ${HOME}/.zshrc exists but is not managed by dot"
    fi
  else
    warn "zsh is not installed — run ./bootstrap.sh"
  fi
}
