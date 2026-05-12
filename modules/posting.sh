#!/usr/bin/env zsh
# modules/posting.sh — Posting TUI HTTP client via uv tool

MODULE_NAME="posting"
MODULE_DESC="posting — modern TUI HTTP client"

_posting_pypi_url="https://pypi.org/pypi/posting/json"

_posting_require_uv() {
  if ! command -v uv &>/dev/null; then
    error "uv is required — install it first: dot install uv"
    return 1
  fi
}

_posting_set_config_key() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}:" "$file" 2>/dev/null; then
    sed -i.bak "s/^${key}:.*/${key}: ${value}/" "$file" && rm -f "${file}.bak"
    info "Updated posting config: ${key}: ${value}"
  else
    printf '%s: %s\n' "$key" "$value" >> "$file"
    info "Added posting config: ${key}: ${value}"
  fi
}

_posting_link_config() {
  local posting_bin
  posting_bin="$(command -v posting 2>/dev/null)" || posting_bin="${DOT_BIN}/posting"
  if [[ ! -x "$posting_bin" ]]; then
    warn "posting is not installed — skipping config"
    return 0
  fi

  local theme_src="${DOT_REPO}/configs/posting/themes/vague.yaml"
  local theme_dir config_file

  theme_dir="$("$posting_bin" locate themes 2>/dev/null | tail -1)"
  if [[ -z "$theme_dir" ]]; then
    error "Could not determine posting themes directory"
    return 1
  fi
  mkdir -p "$theme_dir"
  ln -sf "$theme_src" "${theme_dir}/vague.yaml"
  info "Linked vague theme to ${theme_dir}/vague.yaml"

  config_file="$("$posting_bin" locate config 2>/dev/null | tail -1)"
  if [[ -z "$config_file" ]]; then
    warn "Could not determine posting config file path"
    return 0
  fi
  mkdir -p "${config_file:h}"

  _posting_set_config_key "$config_file" "theme"  "vague"
  _posting_set_config_key "$config_file" "editor" "nvim"
}

_posting_install_from_pypi() {
  _posting_require_uv || return 1

  info "Installing posting via uv tool..."
  uv tool install posting || { error "uv tool install failed"; return 1; }

  local etag
  etag="$(remote_etag "$_posting_pypi_url")"
  [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

  _posting_link_config

  local version
  version="$("${DOT_BIN}/posting" --version 2>/dev/null)"
  success "posting ${version} installed to ${DOT_BIN}/posting"
}

module_install() {
  if [[ -x "${DOT_BIN}/posting" ]]; then
    warn "posting is already installed (use 'dot update posting' to update)"
    return 0
  fi
  _posting_install_from_pypi
}

module_config() {
  _posting_link_config
}

module_update() {
  _posting_require_uv || return 1

  if needs_update "$MODULE_NAME" "$_posting_pypi_url" "${DOT_BIN}/posting"; then
    info "Update available for posting"
    info "Upgrading posting via uv tool..."
    uv tool upgrade posting || { error "uv tool upgrade failed"; return 1; }

    local etag
    etag="$(remote_etag "$_posting_pypi_url")"
    [[ -n "$etag" ]] && write_stamp "$MODULE_NAME" "$etag"

    local version
    version="$("${DOT_BIN}/posting" --version 2>/dev/null)"
    success "posting ${version} updated"
  else
    success "posting is already up to date"
  fi
  _posting_link_config
}

module_status() {
  if [[ -x "${DOT_BIN}/posting" ]]; then
    local version stamp
    version="$("${DOT_BIN}/posting" --version 2>/dev/null)"
    stamp="$(read_stamp "$MODULE_NAME")"
    info "posting: ${version}"
    [[ -n "$stamp" ]] && info "ETag stamp: ${stamp}"
  else
    warn "posting is not installed"
  fi
}
