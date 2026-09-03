-- ai.lua — Copilot autofill (ghost text) and the optional Claude Code bridge.
--
-- Both are gated by `lua/ai/init.lua`, which owns the persisted on/off state.
-- Keymaps live under <leader>i ("ai"); see lua/config/keymaps.lua for the map.
local ai = require("ai")

---Newest node under ~/.nvm, since a GUI-launched Neovim never sources nvm.
local function nvm_node()
  local matches = vim.fn.glob(vim.fn.expand("~/.nvm/versions/node") .. "/*/bin/node", true, true)
  local best, best_key
  for _, path in ipairs(matches) do
    local major, minor, patch = path:match("/v(%d+)%.(%d+)%.(%d+)/bin/node$")
    if major then
      local key = tonumber(major) * 1e6 + tonumber(minor) * 1e3 + tonumber(patch)
      if not best_key or key > best_key then best, best_key = path, key end
    end
  end
  return best
end

---Where copilot.lua should find node. Returns nil when there is none, which
---makes us fall back to the standalone language-server binary instead.
local function node_command()
  local candidates = { vim.fn.exepath("node"), vim.fn.expand("~/.local/bin/node"), nvm_node() }
  for _, path in ipairs(candidates) do
    if path and path ~= "" and vim.fn.executable(path) == 1 then return path end
  end
  return nil
end

-- Files whose contents should never leave the machine, whatever the filetype
-- happens to be.
local SECRET_PATTERNS = {
  "%.env$", "%.env%.", "%.envrc$",
  "%.pem$", "%.key$", "%.p12$", "%.pfx$",
  "/id_rsa", "/id_ed25519", "/id_ecdsa",
  "credentials", "secrets?%.", "%.netrc$", "%.htpasswd$",
}

local function looks_secret(bufname)
  local name = bufname:lower()
  for _, pattern in ipairs(SECRET_PATTERNS) do
    if name:match(pattern) then return true end
  end
  return false
end

return {
  -- ── Copilot: inline suggestions ("autofill") ─────────────────────────
  {
    "zbirenbaum/copilot.lua",
    cond  = function() return ai.get("copilot") end,
    cmd   = "Copilot",
    event = "InsertEnter",
    keys  = {
      { "<leader>ip", "<cmd>Copilot panel<cr>",  desc = "AI: Copilot panel" },
      { "<leader>iA", "<cmd>Copilot auth<cr>",   desc = "AI: Copilot sign in" },
      { "<leader>iS", "<cmd>Copilot status<cr>", desc = "AI: Copilot status (plugin)" },
    },
    config = function()
      local node = node_command()

      require("copilot").setup({
        -- No node anywhere? Use the standalone server binary rather than
        -- failing at startup — `dot install nvm` fixes it properly.
        server               = { type = node and "nodejs" or "binary" },
        copilot_node_command = node or "node",

        suggestion = {
          enabled                = true,
          -- The saved state is the source of truth; ai.apply() keeps every
          -- buffer's copilot_suggestion_auto_trigger in step with it.
          auto_trigger           = ai.active(),
          hide_during_completion = true, -- don't fight the nvim-cmp menu
          debounce               = 75,
          keymap = {
            accept      = "<M-l>",
            accept_word = "<M-w>",
            accept_line = "<M-j>",
            next        = "<M-]>",
            prev        = "<M-[>",
            dismiss     = "<C-]>",
          },
        },

        panel = {
          enabled      = true,
          auto_refresh = true,
          layout       = { position = "bottom", ratio = 0.4 },
        },

        filetypes = {
          ["*"]           = true,
          ["."]           = false,
          gitcommit       = false,
          gitrebase       = false,
          hgcommit        = false,
          svn             = false,
          cvs             = false,
          help            = false,
          oil             = false,
          TelescopePrompt = false,
          DressingInput   = false,
          ["dap-repl"]    = false,
        },

        should_attach = function(bufnr, bufname)
          if not vim.bo[bufnr].buflisted then return false end
          if vim.bo[bufnr].buftype ~= "" then return false end
          if vim.bo[bufnr].modifiable == false then return false end
          if looks_secret(bufname) then return false end
          return true
        end,
      })

      -- copilot.setup() already started the client; buffers opened before now
      -- still need the saved autofill state stamped on them.
      ai.apply_buffers()
    end,
  },

  -- ── Claude Code: the CLI, driven from the editor ─────────────────────
  -- Optional: `:AI claude` flips it, and it is on by default only when the
  -- `claude` CLI is installed (`dot install claude`).
  {
    "coder/claudecode.nvim",
    cond = function() return ai.get("claude") end,
    cmd  = {
      "ClaudeCode", "ClaudeCodeOpen", "ClaudeCodeClose", "ClaudeCodeFocus",
      "ClaudeCodeStart", "ClaudeCodeStop", "ClaudeCodeStatus",
      "ClaudeCodeSend", "ClaudeCodeAdd", "ClaudeCodeTreeAdd",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeSelectModel",
    },
    keys = {
      { "<leader>ic", "<cmd>ClaudeCode<cr>",           desc = "AI: Claude Code toggle" },
      { "<leader>if", "<cmd>ClaudeCodeFocus<cr>",      desc = "AI: Claude Code focus" },
      { "<leader>im", "<cmd>ClaudeCodeSelectModel<cr>",  desc = "AI: Claude Code model" },
      { "<leader>ix", "<cmd>ClaudeCodeAdd %<cr>",      desc = "AI: send buffer to Claude" },
      { "<leader>ix", "<cmd>ClaudeCodeSend<cr>",       desc = "AI: send selection to Claude", mode = "v" },
      { "<leader>iy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "AI: accept Claude diff" },
      { "<leader>in", "<cmd>ClaudeCodeDiffDeny<cr>",   desc = "AI: reject Claude diff" },
    },
    opts = function()
      -- Prefer the binary `dot install claude` put in ~/.local/bin over
      -- whatever an inherited PATH happens to resolve to.
      local claude = vim.fn.exepath("claude")
      if claude == "" then claude = vim.fn.expand("~/.local/bin/claude") end

      return {
        terminal_cmd = vim.fn.executable(claude) == 1 and claude or nil,
        diff_opts    = { layout = "vertical", open_in_new_tab = false },
      }
    end,
  },
}
