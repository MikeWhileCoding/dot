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

ensure_path_entry() {
  local entry='export PATH="${HOME}/.local/bin:${PATH}"'
  for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
    if [[ -f "$rc" ]]; then
      grep -qF '.local/bin' "$rc" || printf '\n# dot CLI\n%s\n' "$entry" >> "$rc"
    fi
  done
}

# ── Ensure directories exist ──────────────────────────────────────────
mkdir -p "$DOT_BIN" "$DOT_OPT" "$DOT_DATA"
