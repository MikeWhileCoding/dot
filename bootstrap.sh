#!/bin/sh
# bootstrap.sh — POSIX sh entry point for machines without zsh.
#
# `dot` itself is a zsh script, so it cannot run before zsh exists. This script
# installs zsh (package manager first, source build as the sudo-free fallback)
# and then hands off to `dot init`.
#
#   ./bootstrap.sh            # install zsh if needed, then run `dot init`
#   ./bootstrap.sh --yes      # never prompt; assume yes
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PREFIX="${HOME}/.local"
ZSH_FALLBACK_VERSION="5.9"
ASSUME_YES=0
case "${1:-}" in
  --yes|-y) ASSUME_YES=1 ;;
esac

# ── Logging (mirrors lib/core.sh) ─────────────────────────────────────
info()    { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
success() { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
warn()    { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
err()     { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; }

confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  [ -t 0 ] || return 1
  printf '\033[0;33m[?]\033[0m     %s [y/N] ' "$*"
  read -r answer || return 1
  case "$answer" in [yY]*) return 0 ;; *) return 1 ;; esac
}

have() { command -v "$1" >/dev/null 2>&1; }

sudo_prefix() {
  # prints "sudo " when privilege escalation is needed and available
  if [ "$(id -u)" != "0" ] && have sudo; then
    printf 'sudo '
  fi
  return 0
}

# ── Package-manager install ───────────────────────────────────────────
pkg_install_zsh_cmd() {
  sp=$(sudo_prefix)
  if   have apt-get; then printf '%sapt-get update && %sapt-get install -y zsh' "$sp" "$sp"
  elif have dnf;     then printf '%sdnf install -y zsh' "$sp"
  elif have pacman;  then printf '%spacman -S --noconfirm zsh' "$sp"
  elif have apk;     then printf '%sapk add zsh' "$sp"
  elif have zypper;  then printf '%szypper install -y zsh' "$sp"
  elif have brew;    then printf 'brew install zsh'
  else return 1
  fi
}

# ── Source build (no sudo) ────────────────────────────────────────────
build_zsh_from_source() {
  if ! have make || { ! have cc && ! have gcc && ! have clang; }; then
    err "Building zsh from source needs make and a C compiler (gcc/clang)"
    err "Install them first, or install zsh with your package manager"
    return 1
  fi

  version="$ZSH_FALLBACK_VERSION"
  tmpdir=$(mktemp -d)

  info "Downloading zsh ${version} source..."
  if ! curl -fSL --progress-bar -o "${tmpdir}/zsh.tar" "https://www.zsh.org/pub/zsh-${version}.tar.xz" 2>/dev/null; then
    curl -fSL --progress-bar -o "${tmpdir}/zsh.tar" "https://www.zsh.org/pub/zsh-${version}.tar.gz" \
      || { err "Download failed"; rm -rf "$tmpdir"; return 1; }
  fi

  info "Building zsh (this takes a few minutes)..."
  mkdir -p "${tmpdir}/src"
  tar -xf "${tmpdir}/zsh.tar" -C "${tmpdir}/src" --strip-components=1 \
    || { err "Failed to extract zsh source"; rm -rf "$tmpdir"; return 1; }

  jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
  (
    cd "${tmpdir}/src" || exit 1
    ./configure --prefix="$PREFIX" --enable-multibyte >/dev/null
    make -j"$jobs" >/dev/null
    make install >/dev/null
  ) || { err "zsh build failed"; rm -rf "$tmpdir"; return 1; }

  rm -rf "$tmpdir"
  [ -x "${PREFIX}/bin/zsh" ] || { err "Build finished but ${PREFIX}/bin/zsh is missing"; return 1; }
  success "zsh ${version} built into ${PREFIX}"
}

install_zsh() {
  if cmd=$(pkg_install_zsh_cmd); then
    info "zsh can be installed with: ${cmd}"
    if confirm "Run this now?"; then
      if sh -c "$cmd" && have zsh; then
        success "zsh installed via package manager"
        return 0
      fi
      warn "Package install failed — falling back to a source build"
    else
      info "Skipping package manager"
    fi
  else
    info "No supported package manager found"
  fi

  if confirm "Build zsh from source into ${PREFIX} (no sudo needed)?"; then
    build_zsh_from_source
  else
    err "zsh is required to run dot — install it and re-run ./bootstrap.sh"
    return 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────
printf '\n\033[1m\033[0;34m══ dot bootstrap ══\033[0m\n\n'

if have zsh; then
  success "zsh found: $(command -v zsh)"
else
  warn "zsh is not installed — dot is written in zsh and needs it to run"
  install_zsh || exit 1
fi

ZSH_BIN=$(command -v zsh || echo "${PREFIX}/bin/zsh")
[ -x "$ZSH_BIN" ] || { err "zsh still not available at ${ZSH_BIN}"; exit 1; }

info "Handing off to: dot init"
exec "$ZSH_BIN" "${REPO_DIR}/dot" init
