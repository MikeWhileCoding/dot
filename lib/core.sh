#!/usr/bin/env zsh
# core.sh — shared helpers for dot CLI

# ── Paths ──────────────────────────────────────────────────────────────
DOT_PREFIX="${HOME}/.local"
DOT_BIN="${DOT_PREFIX}/bin"
DOT_OPT="${DOT_PREFIX}/opt"
DOT_DATA="${DOT_PREFIX}/share/dot"

# ── Colors ─────────────────────────────────────────────────────────────
_c_reset=$'\033[0m'
_c_red=$'\033[0;31m'
_c_green=$'\033[0;32m'
_c_yellow=$'\033[0;33m'
_c_blue=$'\033[0;34m'
_c_bold=$'\033[1m'

info()    { printf "%s[info]%s  %s\n"    "$_c_blue"   "$_c_reset" "$*" }
success() { printf "%s[ok]%s    %s\n"    "$_c_green"  "$_c_reset" "$*" }
warn()    { printf "%s[warn]%s  %s\n"    "$_c_yellow" "$_c_reset" "$*" }
error()   { printf "%s[error]%s %s\n"    "$_c_red"    "$_c_reset" "$*" >&2 }
header()  { printf "\n%s%s══ %s ══%s\n\n" "$_c_bold" "$_c_blue" "$*" "$_c_reset" }

# ── OS / Arch detection ───────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) OS="macos"  ;;
  Linux)  OS="linux"  ;;
  *)      OS="unknown" ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64"   ;;
  x86_64|amd64)  ARCH="x86_64" ;;
  *)              ARCH="unknown" ;;
esac

# ── Helpers ────────────────────────────────────────────────────────────

fetch() {
  # fetch <url> <dest>
  local url="$1" dest="$2"
  curl -fSL --progress-bar -o "$dest" "$url"
}

remote_etag() {
  # remote_etag <url>  — prints the ETag header value
  curl -fsSL -I "$1" 2>/dev/null \
    | grep -i '^etag:' \
    | sed 's/^[Ee][Tt][Aa][Gg]: *//; s/\r$//'
}

write_stamp() {
  # write_stamp <module> <etag>
  local module="$1" etag="$2"
  mkdir -p "$DOT_DATA"
  printf '%s\n' "$etag" > "${DOT_DATA}/${module}.etag"
}

read_stamp() {
  # read_stamp <module>  — prints stored etag or empty string
  local stamp="${DOT_DATA}/${1}.etag"
  [[ -f "$stamp" ]] && cat "$stamp" || printf ''
}

needs_update() {
  # needs_update <module> <url> <bin_path>
  # returns 0 if install/update is needed, 1 otherwise
  local module="$1" url="$2" bin_path="$3"

  # not installed at all → need install
  [[ ! -x "$bin_path" ]] && return 0

  local remote_tag local_tag
  remote_tag="$(remote_etag "$url")"
  local_tag="$(read_stamp "$module")"

  # no remote etag available → assume update needed
  [[ -z "$remote_tag" ]] && return 0

  # etags differ → update needed
  [[ "$remote_tag" != "$local_tag" ]] && return 0

  return 1
}

github_latest_version() {
  # github_latest_version <owner/repo>  — prints the latest release tag
  local version
  version="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
    "https://github.com/${1}/releases/latest" \
    | sed 's|.*/||')"
  if [[ -z "$version" ]]; then
    error "Failed to resolve latest version for ${1}"
    return 1
  fi
  echo "$version"
}

cpu_count() {
  nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2
}

have_root() {
  # have_root — true if we can install system packages
  [[ "$(id -u)" == "0" ]] && return 0
  command -v sudo &>/dev/null && return 0
  return 1
}

as_root() {
  # as_root <cmd...> — run a command with root privileges if needed
  if [[ "$(id -u)" == "0" ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

confirm() {
  # confirm <question> — ask y/N on a TTY; false when non-interactive
  local answer
  [[ -t 0 ]] || return 1
  printf "%s[?]%s     %s [y/N] " "$_c_yellow" "$_c_reset" "$*"
  read -r answer || return 1
  [[ "$answer" == [yY]* ]]
}

pkg_manager() {
  # pkg_manager — prints the first supported package manager found
  local m
  for m in apt-get dnf pacman apk zypper brew; do
    if command -v "$m" &>/dev/null; then
      echo "$m"
      return 0
    fi
  done
  return 1
}

pkg_install_cmd() {
  # pkg_install_cmd <pkg>... — prints the install command for this system.
  # The pseudo-package "build-tools" maps to make + a C compiler.
  local mgr pkgs=() p sudo_prefix=""
  mgr="$(pkg_manager)" || return 1

  for p in "$@"; do
    case "${mgr}:${p}" in
      apt-get:build-tools) pkgs+=(build-essential) ;;
      dnf:build-tools)     pkgs+=(gcc make)        ;;
      pacman:build-tools)  pkgs+=(base-devel)      ;;
      apk:build-tools)     pkgs+=(build-base)      ;;
      zypper:build-tools)  pkgs+=(gcc make)        ;;
      brew:build-tools)    continue                ;;  # comes from xcode-select
      *)                   pkgs+=("$p")            ;;
    esac
  done
  (( ${#pkgs[@]} )) || return 1

  [[ "$mgr" != "brew" && "$(id -u)" != "0" ]] && sudo_prefix="sudo "

  case "$mgr" in
    apt-get) echo "${sudo_prefix}apt-get update && ${sudo_prefix}apt-get install -y ${pkgs[*]}" ;;
    dnf)     echo "${sudo_prefix}dnf install -y ${pkgs[*]}"        ;;
    pacman)  echo "${sudo_prefix}pacman -S --noconfirm ${pkgs[*]}" ;;
    apk)     echo "${sudo_prefix}apk add ${pkgs[*]}"               ;;
    zypper)  echo "${sudo_prefix}zypper install -y ${pkgs[*]}"     ;;
    brew)    echo "brew install ${pkgs[*]}"                        ;;
  esac
}

have_build_tools() {
  # have_build_tools — true when make and a C compiler are both present
  command -v make &>/dev/null || return 1
  command -v cc &>/dev/null || command -v gcc &>/dev/null || command -v clang &>/dev/null
}

ensure_build_tools() {
  # ensure_build_tools [<reason>] — verify make + gcc, offering to install them.
  # Returns 0 when the toolchain is available, 1 otherwise (callers decide
  # whether that is fatal).
  local reason="${1:-}" missing=() cmd

  command -v make &>/dev/null || missing+=(make)
  if ! command -v cc &>/dev/null && ! command -v gcc &>/dev/null && ! command -v clang &>/dev/null; then
    missing+=(gcc)
  fi
  (( ${#missing[@]} )) || return 0

  warn "Missing build tools: ${missing[*]}"
  [[ -n "$reason" ]] && info "Needed for: ${reason}"

  if [[ "$OS" == "macos" ]] && ! command -v brew &>/dev/null; then
    info "Install them with: xcode-select --install"
    if confirm "Run 'xcode-select --install' now?"; then
      xcode-select --install 2>&1 | tail -1 || true
      info "Re-run this command once the Command Line Tools finish installing"
    fi
    return 1
  fi

  if ! cmd="$(pkg_install_cmd build-tools)"; then
    error "No supported package manager found — install ${missing[*]} manually"
    return 1
  fi

  info "Install them with: ${cmd}"
  if confirm "Run this now?"; then
    if eval "$cmd"; then
      success "Build tools installed"
      return 0
    fi
    error "Build tool installation failed"
    return 1
  fi

  warn "Skipping — install ${missing[*]} before building native code"
  return 1
}

ensure_ncurses() {
  # ensure_ncurses <tmpdir> — make ncurses headers available, building if needed
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
    make -j"$(cpu_count)" 2>&1 | tail -1
    make install 2>&1 | tail -1
  ) || { error "ncurses build failed"; return 1; }

  success "ncurses installed to ${DOT_PREFIX}"
}

rc_is_managed() {
  # rc_is_managed <rc-file> — true when the rc file is a symlink into the dot repo
  local rc="$1"
  [[ -L "$rc" ]] || return 1
  [[ -n "${DOT_REPO:-}" && "${rc:A}" == "${DOT_REPO}"/* ]]
}

rc_append_once() {
  # rc_append_once <rc-file> <needle> <comment> <line>
  # Appends <line> unless <needle> is already present. Never writes into a
  # dot-managed rc — that file is tracked in git and already wires things up.
  local rc="$1" needle="$2" comment="$3" line="$4"
  [[ -f "$rc" ]] || return 0
  rc_is_managed "$rc" && return 0
  grep -qF "$needle" "$rc" || printf '\n# %s\n%s\n' "$comment" "$line" >> "$rc"
}

ensure_path_entry() {
  local entry='export PATH="${HOME}/.local/bin:${PATH}"'
  local rc
  for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
    rc_append_once "$rc" '.local/bin' 'dot CLI' "$entry"
  done
}

# ── Ensure directories exist ──────────────────────────────────────────
mkdir -p "$DOT_BIN" "$DOT_OPT" "$DOT_DATA"
