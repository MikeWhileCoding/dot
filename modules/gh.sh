#!/usr/bin/env zsh
# modules/gh.sh — GitHub CLI from GitHub releases

MODULE_NAME="gh"
MODULE_DESC="gh — GitHub CLI"

_gh_repo="cli/cli"

_gh_asset() {
  local version="${1#v}"
  case "${OS}-${ARCH}" in
    macos-arm64)   echo "gh_${version}_macOS_arm64.zip"       ;;
    macos-x86_64)  echo "gh_${version}_macOS_amd64.zip"       ;;
    linux-x86_64)  echo "gh_${version}_linux_amd64.tar.gz"    ;;
    linux-arm64)   echo "gh_${version}_linux_arm64.tar.gz"    ;;
    *) error "Unsupported platform: ${OS}-${ARCH}"; return 1  ;;
  esac
}

_gh_url() {
  local version="$1" asset
  asset="$(_gh_asset "$version")" || return 1
  echo "https://github.com/${_gh_repo}/releases/download/${version}/${asset}"
}

_gh_install_from_release() {
  local version url asset tmpdir
  version="$(github_latest_version "$_gh_repo")" || return 1
  url="$(_gh_url "$version")" || return 1
  asset="$(_gh_asset "$version")"
  tmpdir="$(mktemp -d)"

  info "Downloading gh ${version}..."
  fetch "$url" "${tmpdir}/gh-archive" || { error "Download failed"; rm -rf "$tmpdir"; return 1; }

  info "Extracting..."
  mkdir -p "${tmpdir}/out"
  if [[ "$url" == *.zip ]]; then
    unzip -q "${tmpdir}/gh-archive" -d "${tmpdir}/out"
  else
    tar -xzf "${tmpdir}/gh-archive" -C "${tmpdir}/out" --strip-components=1
  fi

  # zip archives keep the top-level directory; find the bin inside it
  local bin_src
  if [[ "$url" == *.zip ]]; then
    bin_src="${tmpdir}/out/${asset%.zip}/bin/gh"
  else
    bin_src="${tmpdir}/out/bin/gh"
  fi

  cp "$bin_src" "${DOT_BIN}/gh"
  chmod +x "${DOT_BIN}/gh"

  local etag
  etag="$(remote_etag "$url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  rm -rf "$tmpdir"
  success "gh ${version} installed to ${DOT_BIN}/gh"
}

module_install() {
  if [[ -x "${DOT_BIN}/gh" ]]; then
    warn "gh is already installed (use 'dot update gh' to update)"
    return 0
  fi
  _gh_install_from_release
}

module_update() {
  local version url
  version="$(github_latest_version "$_gh_repo")" || return 1
  url="$(_gh_url "$version")" || return 1

  if needs_update "$MODULE_NAME" "$url" "${DOT_BIN}/gh"; then
    info "Update available for gh"
    _gh_install_from_release
  else
    success "gh is already up to date"
  fi
}

module_status() {
  if [[ -x "${DOT_BIN}/gh" ]]; then
    local version stamp
    version="$("${DOT_BIN}/gh" --version 2>/dev/null | head -1)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "gh: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "gh is not installed"
  fi
}
