-- project/runner.lua — decides *where* project tooling runs.
--
-- Most projects here are dockerised: pint, phpstan, artisan and biome live
-- inside a container, not on the host. Drop a `.nvim-tools.json` next to
-- `composer.json` / `package.json` and every integration in this config
-- (conform, nvim-lint, nvim-dap, laravel.nvim) runs its commands in the right
-- place and translates paths between host and container.
--
--   {
--     "runner": "compose",              // local | docker | compose | sail | custom
--     "service": "app",                 // compose / sail service name
--     "container": "myapp-php-1",       // `docker exec` target
--     "workdir": "/var/www/html",       // project root *inside* the container
--     "user": "www-data",
--     "compose_file": "docker-compose.dev.yml",
--     "prefix": ["ssh", "box", "--"],   // runner = "custom"
--     "xdebug": { "port": 9003 },
--     "tools": {
--       "phpstan": { "args": ["--memory-limit=2G"] },
--       "blade-formatter": { "runner": "local" },
--       "biome": { "runner": "compose", "service": "node", "workdir": "/app" }
--     }
--   }
--
-- `.nvim-tools.local.json` is merged on top of `.nvim-tools.json`, so a team can
-- commit the shared setup while each machine overrides what it needs. Both are
-- worth adding to the project's .gitignore / .git/info/exclude as you prefer.

local M = {}

local ROOT_MARKERS  = { "composer.json", "artisan", "package.json", ".git" }
local CONFIG_FILES  = { ".nvim-tools.json", ".nvim-tools.local.json" }

-- Keys that describe an execution environment. They can be set at the top
-- level of the file and overridden per tool.
local ENV_KEYS = { "runner", "container", "service", "workdir", "user", "compose_file", "prefix", "sail" }

-- Sensible per-runner defaults, applied under whatever the project file says.
local RUNNER_DEFAULTS = {
  ["local"] = {},
  docker    = { workdir = "/var/www/html" },
  compose   = { service = "app", workdir = "/var/www/html" },
  sail      = { service = "laravel.test", workdir = "/var/www/html", sail = "vendor/bin/sail" },
  custom    = {},
}

-- Known tools and how they are invoked inside the chosen environment.
local TOOL_DEFAULTS = {
  pint                = { cmd = { "vendor/bin/pint" } },
  phpstan             = { cmd = { "vendor/bin/phpstan" } },
  ["php-cs-fixer"]    = { cmd = { "vendor/bin/php-cs-fixer" } },
  phpunit             = { cmd = { "vendor/bin/phpunit" } },
  pest                = { cmd = { "vendor/bin/pest" } },
  php                 = { cmd = { "php" } },
  artisan             = { cmd = { "php", "artisan" } },
  composer            = { cmd = { "composer" } },
  npm                 = { cmd = { "npm" } },
  yarn                = { cmd = { "yarn" } },
  -- Node tool, normally installed on the host even for dockerised projects.
  ["blade-formatter"] = { runner = "local", cmd = { "blade-formatter" } },
  -- JS/TS: whichever container holds node_modules. Override `runner`/`service`
  -- per tool when the front end lives in a different container than PHP.
  biome               = { cmd = { "node_modules/.bin/biome" } },
  prettier            = { cmd = { "node_modules/.bin/prettier" } },
  eslint              = { cmd = { "node_modules/.bin/eslint" } },
}

local cache    = {}  -- root -> resolved config
local warned   = {}  -- message -> true (notify once per session)

local function warn_once(msg)
  if warned[msg] then return end
  warned[msg] = true
  vim.notify("[tools] " .. msg, vim.log.levels.WARN)
end

---Merge `override` into `base`; list-like values replace instead of merging.
local function merge(base, override)
  if type(override) ~= "table" then return base end
  for k, v in pairs(override) do
    if type(v) == "table" and type(base[k]) == "table" and not vim.islist(v) then
      base[k] = merge(base[k], v)
    else
      base[k] = vim.deepcopy(v)
    end
  end
  return base
end

local function read_json(path)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local content = fd:read("*a")
  fd:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    warn_once(("%s is not valid JSON — ignoring it"):format(path))
    return nil
  end
  return decoded
end

---Project root for a buffer (falls back to the cwd for unnamed buffers).
---@param bufnr integer|nil
---@return string
function M.root(bufnr)
  bufnr = bufnr or 0
  local ok, root = pcall(vim.fs.root, bufnr, ROOT_MARKERS)
  if ok and root then return vim.fs.normalize(root) end
  return vim.fs.normalize(vim.fn.getcwd())
end

---Resolved project config (cached per root).
---@param bufnr integer|nil
---@return table
function M.config(bufnr)
  local root = M.root(bufnr)
  if cache[root] then return cache[root] end

  local cfg = { runner = "local", tools = {} }
  for _, name in ipairs(CONFIG_FILES) do
    local data = read_json(root .. "/" .. name)
    if data then cfg = merge(cfg, data) end
  end
  cfg.root   = root
  cfg.runner = cfg.runner or "local"
  cfg.tools  = cfg.tools or {}

  cache[root] = cfg
  return cfg
end

function M.clear_cache()
  cache  = {}
  warned = {}
end

---Environment (runner + container coordinates) for one tool.
local function env_for(cfg, tool)
  local runner = tool.runner or cfg.runner or "local"
  local env    = vim.deepcopy(RUNNER_DEFAULTS[runner] or {})
  for _, key in ipairs(ENV_KEYS) do
    if cfg[key] ~= nil then env[key] = cfg[key] end
    if tool[key] ~= nil then env[key] = tool[key] end
  end
  env.runner = runner
  return env
end

---Argv prefix that puts a command inside the project's environment.
---@return string[]|nil argv, string|nil err
local function prefix_for(env)
  local runner = env.runner

  if runner == "local" then
    return {}
  end

  if runner == "custom" then
    if not env.prefix or #env.prefix == 0 then
      return nil, 'runner "custom" needs a "prefix" array'
    end
    return vim.deepcopy(env.prefix)
  end

  if runner == "docker" then
    if not env.container then
      return nil, 'runner "docker" needs a "container"'
    end
    local argv = { "docker", "exec", "-i" }
    if env.user then vim.list_extend(argv, { "-u", env.user }) end
    if env.workdir then vim.list_extend(argv, { "-w", env.workdir }) end
    table.insert(argv, env.container)
    return argv
  end

  if runner == "compose" then
    local argv = { "docker", "compose" }
    if env.compose_file then vim.list_extend(argv, { "-f", env.compose_file }) end
    vim.list_extend(argv, { "exec", "-T" })
    if env.user then vim.list_extend(argv, { "-u", env.user }) end
    if env.workdir then vim.list_extend(argv, { "-w", env.workdir }) end
    table.insert(argv, env.service or "app")
    return argv
  end

  if runner == "sail" then
    -- `sail run <cmd> …` proxies any command into the app container as the
    -- sail user; it adds `-T` itself when stdin is not a tty, which is always
    -- the case for jobs started from Neovim.
    return { env.sail or "vendor/bin/sail", "run" }
  end

  return nil, ("unknown runner %q"):format(tostring(runner))
end

---Everything needed to run `name` for this buffer.
---@param name string tool key (pint, phpstan, artisan, …)
---@param bufnr integer|nil
---@return table|nil spec { argv, cwd, root, env, opts }
function M.command(name, bufnr)
  local cfg  = M.config(bufnr)
  local tool = merge(vim.deepcopy(TOOL_DEFAULTS[name] or { cmd = { name } }), cfg.tools[name] or {})
  if tool.enabled == false then return nil end

  local env = env_for(cfg, tool)
  local prefix, err = prefix_for(env)
  if not prefix then
    warn_once(("%s: %s (see %s/.nvim-tools.json)"):format(name, err, cfg.root))
    return nil
  end

  local argv = vim.list_extend(prefix, vim.deepcopy(tool.cmd or { name }))

  return {
    argv = argv,   -- prefix + executable; callers append their own arguments
    cwd  = cfg.root,
    root = cfg.root,
    env  = env,
    opts = tool,   -- opts.args holds the user's extra arguments for this tool
  }
end

---Is the tool actually runnable? For the local runner that means the binary
---exists; for container runners we trust the project config.
---@param name string
---@param bufnr integer|nil
---@return boolean
function M.available(name, bufnr)
  local spec = M.command(name, bufnr)
  if not spec then return false end
  if spec.env.runner ~= "local" then return true end

  local exe = spec.argv[1]
  if vim.fn.executable(exe) == 1 then return true end
  return vim.fn.executable(spec.root .. "/" .. exe) == 1
end

---Translate a host path to its path inside the environment.
function M.to_remote(path, env, root)
  if not env or env.runner == "local" or not env.workdir then return path end
  path = vim.fs.normalize(path)
  root = vim.fs.normalize(root)
  if path:sub(1, #root + 1) == root .. "/" then
    return env.workdir .. path:sub(#root + 1)
  end
  return path
end

---Translate a path reported by a tool back to the host.
function M.to_local(path, env, root)
  if not env or env.runner == "local" or not env.workdir then return path end
  path    = vim.fs.normalize(path)
  root    = vim.fs.normalize(root)
  local w = vim.fs.normalize(env.workdir)
  if path:sub(1, #w + 1) == w .. "/" then
    return root .. path:sub(#w + 1)
  end
  if not vim.startswith(path, "/") then
    return root .. "/" .. path
  end
  return path
end

---Xdebug settings for the project.
function M.xdebug(bufnr)
  local cfg  = M.config(bufnr)
  local env  = env_for(cfg, {})
  local xd   = cfg.xdebug or {}
  local maps = xd.pathMappings
  if not maps and env.runner ~= "local" and env.workdir then
    maps = { [env.workdir] = cfg.root }
  end
  return {
    port         = xd.port or 9003,
    pathMappings = maps or {},
    root         = cfg.root,
  }
end

-- ── User commands ─────────────────────────────────────────────────────

local EXAMPLE = [[{
  "runner": "compose",
  "service": "app",
  "workdir": "/var/www/html",
  "tools": {
    "phpstan": { "args": ["--memory-limit=1G"] },
    "blade-formatter": { "runner": "local" }
  }
}
]]

local function info_lines(bufnr)
  local cfg   = M.config(bufnr)
  local lines = {
    "Project root : " .. cfg.root,
    "Runner       : " .. (cfg.runner or "local"),
  }

  local found = {}
  for _, name in ipairs(CONFIG_FILES) do
    if vim.uv.fs_stat(cfg.root .. "/" .. name) then table.insert(found, name) end
  end
  table.insert(lines, "Config file  : " .. (#found > 0 and table.concat(found, ", ") or "none (defaults)"))
  table.insert(lines, "")

  local names = vim.tbl_keys(TOOL_DEFAULTS)
  vim.list_extend(names, vim.tbl_keys(cfg.tools))
  names = vim.fn.uniq(vim.fn.sort(names))

  for _, name in ipairs(names) do
    local spec = M.command(name, bufnr)
    if not spec then
      table.insert(lines, ("%-16s disabled"):format(name))
    else
      local mark = M.available(name, bufnr) and " " or "!"
      table.insert(lines, ("%s %-14s %s"):format(mark, name, table.concat(spec.argv, " ")))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "(! = not found on this machine)")
  return lines
end

function M.setup()
  vim.api.nvim_create_user_command("ProjectTools", function()
    vim.notify(table.concat(info_lines(0), "\n"), vim.log.levels.INFO)
  end, { desc = "Show how project tooling is invoked here" })

  vim.api.nvim_create_user_command("ProjectToolsReload", function()
    M.clear_cache()
    vim.notify("[tools] project tooling config reloaded", vim.log.levels.INFO)
  end, { desc = "Re-read .nvim-tools.json" })

  vim.api.nvim_create_user_command("ProjectToolsInit", function()
    local path = M.root(0) .. "/.nvim-tools.json"
    if vim.uv.fs_stat(path) then
      vim.notify("[tools] " .. path .. " already exists", vim.log.levels.WARN)
    else
      local fd = assert(io.open(path, "w"))
      fd:write(EXAMPLE)
      fd:close()
      M.clear_cache()
    end
    vim.cmd.edit(vim.fn.fnameescape(path))
  end, { desc = "Create/open .nvim-tools.json for this project" })

  -- Editing the file takes effect immediately.
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern  = { ".nvim-tools.json", ".nvim-tools.local.json" },
    callback = function() M.clear_cache() end,
    desc     = "Reload project tooling config",
  })
end

return M
