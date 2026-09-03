#!/usr/bin/env zsh
# project.sh — `dot project`: tell the editor where a project's tools run.
#
# Writes the `.nvim-tools.json` that configs/nvim/lua/project/runner.lua reads,
# so pint, phpstan, artisan and biome are executed in the right container with
# the right paths. Detection beats documentation: this looks at the project
# for Sail, at Docker for a container that has the project bind-mounted, and
# at the compose file, before falling back to running things locally.

PROJECT_CONFIG_FILE=".nvim-tools.json"
PROJECT_LOCAL_FILE=".nvim-tools.local.json"

# ── Locating things ────────────────────────────────────────────────────

project_root() {
  # project_root [<dir>] — nearest composer.json/package.json, else git root
  local dir="${1:-$PWD}"
  local probe="$dir"
  while [[ "$probe" != "/" && -n "$probe" ]]; do
    if [[ -f "${probe}/composer.json" || -f "${probe}/package.json" ]]; then
      printf '%s\n' "$probe"
      return 0
    fi
    probe="${probe:h}"
  done
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null && return 0
  printf '%s\n' "$dir"
}

_project_compose_file() {
  local root="$1" name
  for name in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
    [[ -f "${root}/${name}" ]] && { printf '%s\n' "$name"; return 0 }
  done
  return 1
}

_project_compose_services() {
  # Top-level keys under `services:` — good enough without a YAML parser.
  local file="$1"
  sed -n '/^services:/,/^[^[:space:]#]/p' "$file" 2>/dev/null \
    | grep -E '^[[:space:]]{2}[a-zA-Z0-9._-]+:' \
    | sed 's/^[[:space:]]*//; s/:.*//' || true
}

_project_guess_service() {
  # Pick the service most likely to hold PHP, else the first one.
  local file="$1" services service
  services=("${(@f)$(_project_compose_services "$file" || true)}")
  for service in "${services[@]}"; do
    case "$service" in
      php|app|php-fpm|fpm|laravel|laravel.test|web|api|backend) printf '%s\n' "$service"; return 0 ;;
    esac
  done
  [[ -n "${services[1]:-}" ]] && printf '%s\n' "${services[1]}"
}

_project_compose_workdir() {
  # A `- .:/var/www/html` style bind mount tells us where the code lands.
  local file="$1"
  grep -oE '^[[:space:]]*-[[:space:]]*\.{1,2}/?:[^:[:space:]]+' "$file" 2>/dev/null \
    | head -1 \
    | sed 's/.*://' || true
}

# ── Detection ──────────────────────────────────────────────────────────
#
# Fills these globals: PROJECT_RUNNER, PROJECT_SERVICE, PROJECT_CONTAINER,
# PROJECT_WORKDIR, PROJECT_COMPOSE_FILE, PROJECT_DETECTED_BY

_project_detect_docker() {
  # A running container that bind-mounts the project root is the strongest
  # signal we have — it survives renamed containers and odd compose setups.
  local root="$1" id name service source dest line
  command -v docker &>/dev/null || return 1
  docker info &>/dev/null || return 1

  for id in ${(f)"$(docker ps -q 2>/dev/null || true)"}; do
    for line in ${(f)"$(docker inspect -f '{{range .Mounts}}{{.Source}}|{{.Destination}}{{"\n"}}{{end}}' "$id" 2>/dev/null || true)"}; do
      source="${line%%|*}"
      dest="${line#*|}"
      [[ -z "$source" || -z "$dest" ]] && continue
      [[ "$source" != "$root" ]] && continue

      PROJECT_WORKDIR="$dest"
      # Compose-managed? Then the service name is stabler than the container.
      service="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' "$id" 2>/dev/null || true)"
      if [[ -n "$service" && "$service" != "<no value>" ]]; then
        PROJECT_RUNNER="compose"
        PROJECT_SERVICE="$service"
        PROJECT_DETECTED_BY="running container (compose service '${service}')"
      else
        name="$(docker inspect -f '{{.Name}}' "$id" 2>/dev/null || true)"
        PROJECT_RUNNER="docker"
        PROJECT_CONTAINER="${name#/}"
        PROJECT_DETECTED_BY="running container '${PROJECT_CONTAINER}'"
      fi
      return 0
    done
  done
  return 1
}

project_detect() {
  local root="$1"
  PROJECT_RUNNER="local"
  PROJECT_SERVICE=""
  PROJECT_CONTAINER=""
  PROJECT_WORKDIR=""
  PROJECT_COMPOSE_FILE=""
  PROJECT_DETECTED_BY="no container found"

  local compose_file
  compose_file="$(_project_compose_file "$root" || true)"

  # 1. Laravel Sail — unambiguous when it is there.
  if [[ -x "${root}/vendor/bin/sail" ]]; then
    PROJECT_RUNNER="sail"
    PROJECT_WORKDIR="/var/www/html"
    PROJECT_SERVICE="$(grep -E '^APP_SERVICE=' "${root}/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"'' || true)"
    PROJECT_DETECTED_BY="vendor/bin/sail"
    [[ -n "$compose_file" && "$compose_file" != "docker-compose.yml" ]] && PROJECT_COMPOSE_FILE="$compose_file"
    return 0
  fi

  # 2. A running container with this project mounted.
  if _project_detect_docker "$root"; then
    [[ "$PROJECT_RUNNER" == "compose" && -n "$compose_file" && "$compose_file" != "docker-compose.yml" ]] \
      && PROJECT_COMPOSE_FILE="$compose_file"
    return 0
  fi

  # 3. A compose file, even with nothing running right now.
  if [[ -n "$compose_file" ]]; then
    PROJECT_RUNNER="compose"
    PROJECT_SERVICE="$(_project_guess_service "${root}/${compose_file}" || true)"
    PROJECT_WORKDIR="$(_project_compose_workdir "${root}/${compose_file}" || true)"
    [[ "$compose_file" != "docker-compose.yml" ]] && PROJECT_COMPOSE_FILE="$compose_file"
    PROJECT_DETECTED_BY="${compose_file} (nothing running — service guessed)"
    return 0
  fi

  return 0
}

# ── Reading an existing config ────────────────────────────────────────
#
# Only the top-level keys, and only up to "tools" so per-tool overrides are
# never mistaken for project-wide ones. Neovim is the real parser.

_project_json_get() {
  # _project_json_get <file> <key>
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  sed '/"tools"/q' "$file" \
    | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed 's/.*:[[:space:]]*"//; s/"$//' || true
}

_project_json_array() {
  # _project_json_array <file> <key> — prints one element per line
  local file="$1" key="$2" raw
  raw="$(sed '/"tools"/q' "$file" | tr -d '\n' | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\[[^]]*\]" | head -1 || true)"
  [[ -z "$raw" ]] && return 1
  printf '%s\n' "$raw" | grep -oE '"[^"]*"' | sed '1d; s/^"//; s/"$//'
}

# ── Building the command prefix (mirrors lua/project/runner.lua) ──────

project_prefix() {
  # project_prefix <root> — prints the argv that puts a command in the project's
  # environment, one element per line (empty for the local runner).
  local root="$1" file="${root}/${PROJECT_CONFIG_FILE}"
  local runner="local" container="" service="" workdir="" user="" compose_file="" sail=""

  if [[ -f "$file" ]]; then
    runner="$(_project_json_get "$file" runner)"; runner="${runner:-local}"
    container="$(_project_json_get "$file" container)"
    service="$(_project_json_get "$file" service)"
    workdir="$(_project_json_get "$file" workdir)"
    user="$(_project_json_get "$file" user)"
    compose_file="$(_project_json_get "$file" compose_file)"
    sail="$(_project_json_get "$file" sail)"
  fi

  case "$runner" in
    local) return 0 ;;
    custom)
      _project_json_array "$file" prefix || {
        error "runner \"custom\" needs a \"prefix\" array in ${PROJECT_CONFIG_FILE}"
        return 1
      }
      ;;
    docker)
      [[ -n "$container" ]] || { error "runner \"docker\" needs a \"container\""; return 1 }
      printf '%s\n' docker exec -i
      [[ -n "$user" ]]    && printf '%s\n' -u "$user"
      [[ -n "$workdir" ]] && printf '%s\n' -w "$workdir"
      printf '%s\n' "$container"
      ;;
    compose)
      printf '%s\n' docker compose
      [[ -n "$compose_file" ]] && printf '%s\n' -f "$compose_file"
      printf '%s\n' exec -T
      [[ -n "$user" ]]    && printf '%s\n' -u "$user"
      [[ -n "$workdir" ]] && printf '%s\n' -w "$workdir"
      printf '%s\n' "${service:-app}"
      ;;
    sail)
      printf '%s\n' "${sail:-vendor/bin/sail}" run
      ;;
    *)
      error "Unknown runner: ${runner}"
      return 1
      ;;
  esac
  return 0
}

# ── Commands ───────────────────────────────────────────────────────────

_project_write_config() {
  # _project_write_config <path>
  local path="$1" body="  \"runner\": \"${PROJECT_RUNNER}\""

  [[ -n "$PROJECT_CONTAINER"    ]] && body+=",\n  \"container\": \"${PROJECT_CONTAINER}\""
  [[ -n "$PROJECT_SERVICE"      ]] && body+=",\n  \"service\": \"${PROJECT_SERVICE}\""
  [[ -n "$PROJECT_WORKDIR"      ]] && body+=",\n  \"workdir\": \"${PROJECT_WORKDIR}\""
  [[ -n "$PROJECT_COMPOSE_FILE" ]] && body+=",\n  \"compose_file\": \"${PROJECT_COMPOSE_FILE}\""

  printf "{\n${body}\n}\n" > "$path"
}

project_cmd_init() {
  local write_local=0 force=0 arg
  for arg in "$@"; do
    case "$arg" in
      --local) write_local=1 ;;
      --force) force=1      ;;
      *) error "Unknown option: ${arg}"; return 1 ;;
    esac
  done

  local root target name
  root="$(project_root)"
  name="$PROJECT_CONFIG_FILE"
  (( write_local )) && name="$PROJECT_LOCAL_FILE"
  target="${root}/${name}"

  header "dot project init — ${root:t}"
  info "Project root: ${root}"

  if [[ -f "$target" ]] && (( ! force )); then
    warn "${name} already exists:"
    echo
    sed 's/^/    /' "$target"
    echo
    info "  Overwrite with: dot project init --force"
    (( write_local )) || info "  Machine-only override: dot project init --local"
    return 0
  fi

  project_detect "$root"
  info "Detected via: ${PROJECT_DETECTED_BY}"

  if [[ "$PROJECT_RUNNER" == "local" ]]; then
    warn "Nothing containerised found — tools will run on this machine"
    info "  That is the default, so a config file is only needed if that is wrong."
    confirm "Write ${name} anyway?" || return 0
  fi

  _project_write_config "$target"
  success "Wrote ${target}"
  echo
  sed 's/^/    /' "$target"
  echo

  if [[ "$PROJECT_RUNNER" != "local" && -z "$PROJECT_WORKDIR" ]]; then
    warn "No workdir detected — set \"workdir\" to the project path inside the container"
    info "  Without it, paths cannot be translated for phpstan and xdebug."
  fi

  # Keep the machine-local override out of the project's history.
  if (( write_local )) && [[ -d "${root}/.git" ]]; then
    local exclude="${root}/.git/info/exclude"
    if [[ -f "$exclude" ]] && ! grep -qxF "$PROJECT_LOCAL_FILE" "$exclude"; then
      if confirm "Add ${PROJECT_LOCAL_FILE} to .git/info/exclude?"; then
        printf '%s\n' "$PROJECT_LOCAL_FILE" >> "$exclude"
        success "Ignored locally (not committed to .gitignore)"
      fi
    fi
  fi

  info "Verify it end-to-end with: dot project check"
}

project_cmd_show() {
  local root file prefix
  root="$(project_root)"
  header "dot project — ${root:t}"
  info "Project root: ${root}"

  local found=0 name
  for name in "$PROJECT_CONFIG_FILE" "$PROJECT_LOCAL_FILE"; do
    if [[ -f "${root}/${name}" ]]; then
      found=1
      echo
      info "${name}:"
      sed 's/^/    /' "${root}/${name}"
    fi
  done
  if (( ! found )); then
    echo
    warn "No ${PROJECT_CONFIG_FILE} — tools run on this machine"
    info "  Create one with: dot project init"
    return 0
  fi

  prefix=("${(@f)$(project_prefix "$root")}") || return 1
  echo
  info "Commands the editor will run:"
  local tool
  for tool in "vendor/bin/pint" "vendor/bin/phpstan" "php artisan" "node_modules/.bin/biome"; do
    if [[ -n "${prefix[1]:-}" ]]; then
      printf "    %s %s\n" "${prefix[*]}" "$tool"
    else
      printf "    %s\n" "$tool"
    fi
  done
}

project_cmd_check() {
  local root prefix
  root="$(project_root)"
  header "dot project check — ${root:t}"

  prefix=("${(@f)$(project_prefix "$root")}") || return 1
  # An empty first element means the local runner (project_prefix printed nothing).
  local -a run_prefix=()
  [[ -n "${prefix[1]:-}" ]] && run_prefix=("${prefix[@]}")

  if (( ${#run_prefix[@]} )); then
    info "Prefix: ${run_prefix[*]}"
  else
    info "Runner: local (no container)"
  fi
  echo

  local failures=0

  _check_one() {
    # _check_one <label> <cmd...>
    local label="$1"; shift
    local output=""
    if output="$( (cd "$root" && "${run_prefix[@]}" "$@") 2>&1 | head -1 )" && [[ -n "$output" ]]; then
      success "${label}: ${output}"
    else
      warn "${label}: not available"
      [[ -n "$output" ]] && printf "           %s\n" "$output"
      failures=$(( failures + 1 ))
    fi
  }

  _check_one "php     " php -v
  [[ -f "${root}/composer.json" ]] && _check_one "pint    " vendor/bin/pint --version
  [[ -f "${root}/composer.json" ]] && _check_one "phpstan " vendor/bin/phpstan --version
  [[ -f "${root}/package.json"  ]] && [[ -f "${root}/biome.json" || -f "${root}/biome.jsonc" ]] \
    && _check_one "biome   " node_modules/.bin/biome --version

  # The path mapping is what makes diagnostics land on the right lines.
  local workdir
  workdir="$(_project_json_get "${root}/${PROJECT_CONFIG_FILE}" workdir || true)"
  if (( ${#run_prefix[@]} )) && [[ -n "$workdir" ]]; then
    echo
    if (cd "$root" && "${run_prefix[@]}" test -e "${workdir}/composer.json" 2>/dev/null) \
      || (cd "$root" && "${run_prefix[@]}" test -e "${workdir}/package.json" 2>/dev/null); then
      success "workdir : ${workdir} holds this project inside the container"
    else
      error "workdir : ${workdir} does not contain this project"
      info "           Fix \"workdir\" in ${PROJECT_CONFIG_FILE}, or phpstan and xdebug will point at the wrong files."
      failures=$(( failures + 1 ))
    fi
  fi

  echo
  if (( failures == 0 )); then
    success "Everything the editor needs is reachable"
  else
    warn "${failures} item(s) unavailable — install them in the project, or adjust ${PROJECT_CONFIG_FILE}"
  fi
}

cmd_project() {
  case "${1:-show}" in
    init)  shift; project_cmd_init "$@" ;;
    show)  shift; project_cmd_show      ;;
    check) shift; project_cmd_check     ;;
    *)
      error "Unknown subcommand: ${1}"
      info "Usage: dot project [show|init [--local] [--force]|check]"
      return 1
      ;;
  esac
}
