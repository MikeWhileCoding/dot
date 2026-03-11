#!/usr/bin/env zsh
# modules/tmux.sh — tmux terminal multiplexer + managed config

MODULE_NAME="tmux"
MODULE_DESC="tmux — terminal multiplexer with persistent sessions"

_tmux_repo="tmux/tmux"

_tmux_nproc() {
  nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2
}

_tmux_ensure_libevent() {
  # Skip if libevent is already findable by the compiler
  if pkg-config --exists libevent 2>/dev/null; then
    info "libevent found via pkg-config"
    return 0
  fi
  # Check common header locations
  if [[ -f /usr/include/event2/event.h ]] || [[ -f /usr/local/include/event2/event.h ]] \
     || [[ -f "${DOT_PREFIX}/include/event2/event.h" ]]; then
    info "libevent headers found"
    return 0
  fi

  local tmpdir="$1"
  local libevent_version="2.1.12"
  local libevent_url="https://github.com/libevent/libevent/releases/download/release-${libevent_version}-stable/libevent-${libevent_version}-stable.tar.gz"

  info "Building libevent ${libevent_version} from source..."
  fetch "$libevent_url" "${tmpdir}/libevent.tar.gz" || { error "Failed to download libevent"; return 1; }
  mkdir -p "${tmpdir}/libevent"
  tar -xzf "${tmpdir}/libevent.tar.gz" -C "${tmpdir}/libevent" --strip-components=1

  (
    cd "${tmpdir}/libevent" || return 1
    ./configure --prefix="${DOT_PREFIX}" --disable-shared --enable-static --disable-openssl 2>&1 | tail -1
    make -j"$(_tmux_nproc)" 2>&1 | tail -1
    make install 2>&1 | tail -1
  ) || { error "libevent build failed"; return 1; }

  success "libevent installed to ${DOT_PREFIX}"
}

_tmux_ensure_ncurses() {
  # Skip if ncurses is already findable
  if pkg-config --exists ncurses 2>/dev/null || pkg-config --exists ncursesw 2>/dev/null; then
    info "ncurses found via pkg-config"
    return 0
  fi
  if [[ -f /usr/include/ncurses.h ]] || [[ -f /usr/local/include/ncurses.h ]] \
     || [[ -f "${DOT_PREFIX}/include/ncurses.h" ]]; then
    info "ncurses headers found"
    return 0
  fi

  local tmpdir="$1"
  local ncurses_version="6.5"
  local ncurses_url="https://ftp.gnu.org/gnu/ncurses/ncurses-${ncurses_version}.tar.gz"

  info "Building ncurses ${ncurses_version} from source..."
  fetch "$ncurses_url" "${tmpdir}/ncurses.tar.gz" || { error "Failed to download ncurses"; return 1; }
  mkdir -p "${tmpdir}/ncurses"
  tar -xzf "${tmpdir}/ncurses.tar.gz" -C "${tmpdir}/ncurses" --strip-components=1

  (
    cd "${tmpdir}/ncurses" || return 1
    ./configure --prefix="${DOT_PREFIX}" --with-shared --with-termlib --enable-widec 2>&1 | tail -1
    make -j"$(_tmux_nproc)" 2>&1 | tail -1
    make install 2>&1 | tail -1
  ) || { error "ncurses build failed"; return 1; }

  success "ncurses installed to ${DOT_PREFIX}"
}

_tmux_build_from_source() {
  local version="$1" tmpdir
  tmpdir="$(mktemp -d)"

  # Ensure dependencies are available, building from source if needed
  _tmux_ensure_libevent "$tmpdir" || { rm -rf "$tmpdir"; return 1; }
  _tmux_ensure_ncurses "$tmpdir"  || { rm -rf "$tmpdir"; return 1; }

  local tarball="https://github.com/${_tmux_repo}/releases/download/${version}/tmux-${version}.tar.gz"
  info "Downloading tmux ${version} source..."
  fetch "$tarball" "${tmpdir}/tmux.tar.gz" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Building tmux from source (no admin required)..."
  mkdir -p "${tmpdir}/src"
  tar -xzf "${tmpdir}/tmux.tar.gz" -C "${tmpdir}/src" --strip-components=1

  (
    cd "${tmpdir}/src" || return 1
    PKG_CONFIG_PATH="${DOT_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
    CFLAGS="-I${DOT_PREFIX}/include -I${DOT_PREFIX}/include/ncursesw ${CFLAGS:-}" \
    LDFLAGS="-L${DOT_PREFIX}/lib ${LDFLAGS:-}" \
      ./configure --prefix="${DOT_PREFIX}" 2>&1 | tail -1
    make -j"$(_tmux_nproc)" 2>&1 | tail -1
  ) || { error "Build failed — ensure a C compiler is available"; rm -rf "$tmpdir"; return 1; }

  cp "${tmpdir}/src/tmux" "${DOT_BIN}/tmux"
  chmod +x "${DOT_BIN}/tmux"

  rm -rf "$tmpdir"
}

_tmux_install_binary() {
  if [[ -x "${DOT_BIN}/tmux" ]]; then
    info "tmux already installed at ${DOT_BIN}/tmux"
    return 0
  fi

  # If tmux is already on the system, just use it
  if command -v tmux &>/dev/null; then
    info "tmux binary already available at $(command -v tmux)"
    return 0
  fi

  local version
  version="$(github_latest_version "$_tmux_repo")" || return 1

  if [[ "$OS" == "macos" ]]; then
    # Build from source — no Homebrew/admin required
    _tmux_build_from_source "$version"
  elif [[ "$OS" == "linux" ]]; then
    # Try package manager first (faster), fall back to source build
    if command -v apt-get &>/dev/null; then
      sudo apt-get update && sudo apt-get install -y tmux
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y tmux
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm tmux
    elif command -v apk &>/dev/null; then
      sudo apk add tmux
    else
      info "No package manager found — building from source"
      _tmux_build_from_source "$version"
    fi
  else
    error "Unsupported OS: ${OS}"
    return 1
  fi

  if [[ -x "${DOT_BIN}/tmux" ]] || command -v tmux &>/dev/null; then
    success "tmux installed"
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
  if tmux list-sessions &>/dev/null; then
    tmux source-file "$config_dst" 2>/dev/null && info "Reloaded tmux config"
  fi
}

_tmux_bin() {
  if [[ -x "${DOT_BIN}/tmux" ]]; then
    echo "${DOT_BIN}/tmux"
  elif command -v tmux &>/dev/null; then
    command -v tmux
  fi
}

module_install() {
  _tmux_install_binary || return 1
  _tmux_deploy_config

  local tmux_path version
  tmux_path="$(_tmux_bin)"
  version="$("$tmux_path" -V 2>/dev/null | awk '{print $2}')"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "installed-${version}"

  success "tmux module ready"
}

module_update() {
  local tmux_path
  tmux_path="$(_tmux_bin)"
  if [[ -z "$tmux_path" ]]; then
    warn "tmux binary not found — run 'dot install tmux' first"
    return 1
  fi

  _tmux_deploy_config

  # If we built from source, check for a newer version
  if [[ "$tmux_path" == "${DOT_BIN}/tmux" ]]; then
    local current latest
    current="$("$tmux_path" -V 2>/dev/null | awk '{print $2}')"
    latest="$(github_latest_version "$_tmux_repo")" || return 1
    if [[ "$current" != "$latest" ]]; then
      info "Updating tmux ${current} → ${latest}"
      _tmux_build_from_source "$latest"
    else
      info "tmux ${current} is already the latest"
    fi
  fi

  local version
  version="$("$(_tmux_bin)" -V 2>/dev/null | awk '{print $2}')"
  [[ -n "$version" ]] && write_stamp "$MODULE_NAME" "installed-${version}"

  success "tmux config updated"
}

module_status() {
  local tmux_path
  tmux_path="$(_tmux_bin)"
  if [[ -n "$tmux_path" ]]; then
    local version stamp
    version="$("$tmux_path" -V 2>/dev/null)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "tmux: ${version} (${tmux_path})"
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
