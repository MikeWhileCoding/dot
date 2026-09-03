-- ai/init.lua — one switch for the AI assistants.
--
-- Copilot's ghost-text "autofill" and the (optional) Claude Code integration
-- are both driven from here, so a single keymap turns them on or off and the
-- choice survives a restart.
--
-- State lives in stdpath("state")/dot-ai.json rather than in the repo, so
-- flipping a toggle never dirties a tracked file. Three switches:
--
--   copilot   Copilot attaches to buffers at all (off = no requests, ever)
--   autofill  suggestions appear as you type (off = only when you ask, <M-l>)
--   claude    load coder/claudecode.nvim; defaults to on when the `claude`
--             CLI is installed
--
-- Both plugins are gated by a lazy.nvim `cond`, which is only evaluated at
-- startup, so switching one back on takes effect at the next launch; turning
-- one off is immediate.
--
-- Set DOT_AI=0 in the environment to force everything off for one session
-- without touching the saved state.
local M = {}

local STATE_FILE = vim.fs.joinpath(vim.fn.stdpath("state"), "dot-ai.json")

M.KEYS = { "copilot", "autofill", "claude" }

---Value used for a key that has never been toggled.
local function fallback(key)
  -- Claude Code only makes sense once the CLI it drives exists.
  if key == "claude" then return vim.fn.executable("claude") == 1 end
  return true
end

local state ---@type table<string, boolean>|nil

local function load()
  if state then return state end
  state = {}
  local fd = io.open(STATE_FILE, "r")
  if fd then
    local raw = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, raw)
    if ok and type(decoded) == "table" then state = decoded end
  end
  return state
end

local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(STATE_FILE, ":h"), "p")
  local fd = io.open(STATE_FILE, "w")
  if not fd then
    vim.notify("AI: cannot write " .. STATE_FILE, vim.log.levels.WARN)
    return
  end
  fd:write(vim.json.encode(load()) .. "\n")
  fd:close()
end

---`DOT_AI=0` (or `off`/`false`) is a session-only kill switch.
local function killed()
  local v = vim.env.DOT_AI
  return v == "0" or v == "off" or v == "false"
end

---@param key string one of M.KEYS
---@return boolean
function M.get(key)
  if killed() then return false end
  local v = load()[key]
  if type(v) == "boolean" then return v end
  return fallback(key)
end

---Is Copilot actually going to fill anything in by itself?
---@return boolean
function M.active()
  return M.get("copilot") and M.get("autofill")
end

-- ── Pushing state into the plugins ────────────────────────────────────

-- copilot.lua reads `vim.b.copilot_suggestion_auto_trigger` per buffer and
-- only falls back to the global config when it is unset. We set it on every
-- buffer instead of relying on that fallback, because a per-buffer override
-- (<leader>ib) has to survive the global toggle flipping underneath it.
local function apply_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local on = vim.b[buf].dot_ai_autofill
  if on == nil then on = M.active() end
  vim.b[buf].copilot_suggestion_auto_trigger = on
end

---Push the autofill state onto every open buffer.
function M.apply_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do apply_buf(buf) end
  if not M.active() then
    -- A long debounce can still paint a suggestion after the toggle.
    local ok, suggestion = pcall(require, "copilot.suggestion")
    if ok then pcall(suggestion.dismiss) end
  end
end

---Re-apply the saved state to copilot.lua.
---@return boolean applied false when copilot.lua is not loaded
function M.apply()
  local ok, command = pcall(require, "copilot.command")
  if not ok then return false end

  -- Keep the plugin's own config honest so `:Copilot status` agrees with us.
  local ok_cfg, cfg = pcall(require, "copilot.config")
  if ok_cfg and type(cfg.suggestion) == "table" then
    cfg.suggestion.auto_trigger = M.active()
  end

  -- Only stop or start the language server when the on/off state actually
  -- moved — flipping autofill must not cost a client restart.
  local ok_client, client = pcall(require, "copilot.client")
  local running = ok_client and not client.is_disabled()
  if M.get("copilot") and not running then
    pcall(command.enable)
  elseif not M.get("copilot") and running then
    pcall(command.disable)
  end

  M.apply_buffers()
  return true
end

-- ── Toggles ───────────────────────────────────────────────────────────

---@param key string
---@param value boolean
---@return boolean
function M.set(key, value)
  load()[key] = value and true or false
  save()

  local applied = M.apply()
  local on = M.get(key)
  local note = ("AI: %s %s"):format(key, on and "on" or "off")
  if key == "claude" or (key == "copilot" and on and not applied) then
    note = note .. " — restart Neovim to apply"
  end
  vim.notify(note, vim.log.levels.INFO, { title = "AI" })
  return on
end

---@param key string
---@return boolean
function M.toggle(key)
  return M.set(key, not M.get(key))
end

---Autofill for this buffer only. Cycles off -> on -> follow the global
---setting, so there is always a way back out of the override.
---@return boolean|nil override
function M.toggle_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local override = vim.b[buf].dot_ai_autofill
  if override == nil then
    vim.b[buf].dot_ai_autofill = not M.active()
  elseif override == M.active() then
    vim.b[buf].dot_ai_autofill = nil
  else
    vim.b[buf].dot_ai_autofill = not override
  end
  apply_buf(buf)

  override = vim.b[buf].dot_ai_autofill
  local what = override == nil and "follows the global setting"
    or (override and "forced on" or "forced off")
  vim.notify("AI: autofill in this buffer " .. what, vim.log.levels.INFO, { title = "AI" })
  return override
end

-- ── Reporting ─────────────────────────────────────────────────────────

---@return boolean|nil connected nil when claudecode.nvim has not loaded
local function claude_connected()
  local claudecode = package.loaded["claudecode"]
  if not claudecode then return nil end
  local ok, connected = pcall(claudecode.is_claude_connected)
  if not ok then return nil end
  return connected and true or false
end

---Short lualine component: the icon on its own means "autofilling right now".
---@return string
function M.statusline()
  local icon = vim.g.dot_ai_icon or "󰚩"
  local text
  if not M.get("copilot") then
    text = icon .. " off"
  else
    local override = vim.b.dot_ai_autofill
    if override == false then
      text = icon .. " buf off"
    elseif not M.get("autofill") and override ~= true then
      text = icon .. " manual"
    else
      text = icon
    end
  end
  if claude_connected() then text = text .. " 󰭹" end
  return text
end

function M.status()
  local override = vim.b.dot_ai_autofill
  local buffer = "follows global"
  if override ~= nil then buffer = override and "forced on" or "forced off" end

  local claude = M.get("claude") and "enabled" or "disabled"
  if M.get("claude") then
    local connected = claude_connected()
    if connected == nil then
      claude = claude .. " (not loaded yet)"
    else
      claude = claude .. (connected and " (claude connected)" or " (no claude session)")
    end
  end

  local lines = {
    "Copilot     : " .. (M.get("copilot") and "on" or "off"),
    "Autofill    : " .. (M.get("autofill") and "on" or "off — ask with <M-l>"),
    "This buffer : " .. buffer,
    "Claude Code : " .. claude,
    "State       : " .. STATE_FILE,
  }
  if killed() then
    table.insert(lines, 1, "DOT_AI=" .. tostring(vim.env.DOT_AI) .. " — everything forced off this session")
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "AI" })
end

-- ── Wiring ────────────────────────────────────────────────────────────

local ACTIONS = {
  status   = function() M.status() end,
  on       = function() M.set("copilot", true) end,
  off      = function() M.set("copilot", false) end,
  toggle   = function() M.toggle("copilot") end,
  autofill = function() M.toggle("autofill") end,
  buffer   = function() M.toggle_buffer() end,
  claude   = function() M.toggle("claude") end,
}

function M.setup()
  vim.api.nvim_create_user_command("AI", function(opts)
    local name = opts.args ~= "" and opts.args or "status"
    local action = ACTIONS[name]
    if not action then
      vim.notify("AI: unknown subcommand '" .. name .. "'", vim.log.levels.ERROR)
      return
    end
    action()
  end, {
    nargs    = "?",
    desc     = "Copilot / Claude Code toggles",
    complete = function(lead)
      local names = vim.tbl_keys(ACTIONS)
      table.sort(names)
      return vim.tbl_filter(function(name) return vim.startswith(name, lead) end, names)
    end,
  })

  -- New buffers need the auto-trigger flag before copilot.lua looks at it.
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
    group    = vim.api.nvim_create_augroup("dot_ai", { clear = true }),
    callback = function(ev) apply_buf(ev.buf) end,
    desc     = "Apply the saved AI autofill state to new buffers",
  })

  local map = vim.keymap.set
  map("n", "<leader>it", function() M.toggle("copilot") end,  { desc = "AI: toggle Copilot" })
  map("n", "<leader>ia", function() M.toggle("autofill") end, { desc = "AI: toggle autofill (ghost text)" })
  map("n", "<leader>ib", function() M.toggle_buffer() end,    { desc = "AI: toggle autofill (this buffer)" })
  map("n", "<leader>is", function() M.status() end,           { desc = "AI: status" })
end

return M
