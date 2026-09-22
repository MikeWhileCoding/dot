-- github.lua — octo.nvim: issues, pull requests and reviews as plain buffers.
--
-- Everything hangs off <leader>o ("octo (github)"), so the which-key popup is
-- the command list: press <leader>o and read what is on offer. <leader>oo goes
-- one better and drops *every* Octo command into the telescope picker.
--
-- The commands that need an argument (search, open by number, filtered list)
-- ask for it through vim.ui.input / vim.ui.select, which dressing.nvim (see
-- plugins/ui.lua) renders as a modal.
--
-- Needs the `gh` CLI: `dot install gh`, then `gh auth login` once per machine.

---Run `:Octo <args…>` with the arguments already split, so a prompted query
---containing spaces or quotes needs no escaping.
local function octo(args)
  vim.cmd({ cmd = "Octo", args = args })
end

local function words(input)
  return vim.split(input, "%s+", { trimempty = true })
end

---A keymap that asks for the argument first and then runs `:Octo …`.
---@param spec { prompt: string, default?: string, args: fun(input: string): string[] }
local function ask(spec)
  return function()
    vim.ui.input({ prompt = spec.prompt, default = spec.default }, function(input)
      input = vim.trim(input or "")
      if input == "" then return end
      octo(spec.args(input))
    end)
  end
end

---Pick issues or PRs, then type the filters — `state=open author=me`, and so
---on. Both lists take an optional leading `owner/repo`.
local function filtered_list()
  vim.ui.select({ "issues", "pull requests" }, { prompt = "List:" }, function(choice)
    if not choice then return end
    local object = choice == "issues" and "issue" or "pr"
    vim.ui.input({ prompt = "Filters > ", default = "state=open " }, function(input)
      if input == nil then return end
      octo(vim.list_extend({ object, "list" }, words(input)))
    end)
  end)
end

-- While reviewing, octo pops the comment thread for the line under the cursor
-- into the other split. It drives that from a CursorMoved autocmd registered at
-- setup *only* when `reviews.auto_show_threads` is on, which makes it a startup
-- decision. Owning the autocmd here instead is what makes <leader>ora a real
-- toggle — show_review_threads() returns early outside a diff buffer, so the
-- "*" pattern costs nothing elsewhere.
local auto_threads = true

local function apply_auto_threads()
  local group = vim.api.nvim_create_augroup("DotOctoAutoThreads", { clear = true })
  if not auto_threads then return end

  vim.api.nvim_create_autocmd("CursorMoved", {
    group    = group,
    pattern  = "*",
    callback = function()
      require("octo.reviews.thread-panel").show_review_threads(false)
    end,
    desc = "Octo: show the review thread under the cursor",
  })
end

local function toggle_auto_threads()
  auto_threads = not auto_threads
  apply_auto_threads()
  vim.notify("Octo: auto thread panel " .. (auto_threads and "on" or "off"))
end

return {
  {
    "pwntester/octo.nvim",
    cmd          = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      -- ── The ones you reach for ─────────────────────────────────────────
      { "<leader>oo", "<cmd>Octo actions<cr>",           desc = "Octo: every command (palette)" },
      { "<leader>oi", "<cmd>Octo issue list<cr>",        desc = "Octo: issues" },
      { "<leader>op", "<cmd>Octo pr list<cr>",           desc = "Octo: pull requests" },
      { "<leader>on", "<cmd>Octo notification list<cr>", desc = "Octo: notifications" },
      { "<leader>oI", "<cmd>Octo issue create<cr>",      desc = "Octo: new issue" },
      { "<leader>oP", "<cmd>Octo pr create<cr>",         desc = "Octo: new pull request" },
      { "<leader>oc", "<cmd>Octo pr checkout<cr>",       desc = "Octo: check out PR" },
      { "<leader>od", "<cmd>Octo pr changes<cr>",        desc = "Octo: PR changed files" },
      { "<leader>ok", "<cmd>Octo pr checks<cr>",         desc = "Octo: PR checks" },
      { "<leader>ot", "<cmd>Octo thread resolve<cr>",    desc = "Octo: resolve thread" },
      { "<leader>oT", "<cmd>Octo thread unresolve<cr>",  desc = "Octo: unresolve thread" },
      { "<leader>ob", "<cmd>Octo repo browser<cr>",      desc = "Octo: repo in browser" },

      -- ── Shortcut, then type the argument ───────────────────────────────
      {
        "<leader>os",
        ask({
          prompt = "GitHub search > ",
          args   = function(query) return vim.list_extend({ "search" }, words(query)) end,
        }),
        desc = "Octo: search GitHub…",
      },
      {
        -- `:Octo 42` and `:Octo <url>` both route themselves to the right
        -- buffer kind — issue, PR, discussion or release.
        "<leader>og",
        ask({
          prompt = "Issue / PR (number or URL) > ",
          args   = function(target) return words(target) end,
        }),
        desc = "Octo: open number or URL…",
      },
      { "<leader>of", filtered_list, desc = "Octo: filtered list…" },
      {
        "<leader>oR",
        ask({
          prompt = "Repo (owner/name) > ",
          args   = function(repo) return { "repo", "view", repo } end,
        }),
        desc = "Octo: open another repo…",
      },

      -- ── Review ─────────────────────────────────────────────────────────
      { "<leader>ors", "<cmd>Octo review start<cr>",    desc = "Review: start" },
      { "<leader>orr", "<cmd>Octo review resume<cr>",   desc = "Review: resume" },
      { "<leader>orx", "<cmd>Octo review submit<cr>",   desc = "Review: submit" },
      { "<leader>ord", "<cmd>Octo review discard<cr>",  desc = "Review: discard" },
      { "<leader>orc", "<cmd>Octo review comments<cr>", desc = "Review: pending comments" },
      { "<leader>orm", "<cmd>Octo review commit<cr>",   desc = "Review: pick commit" },
      { "<leader>ort", "<cmd>Octo review thread<cr>",   desc = "Review: thread at cursor (jump in)" },
      { "<leader>ora", toggle_auto_threads,             desc = "Review: toggle auto thread panel" },

      -- ── Add to the issue/PR you are looking at ─────────────────────────
      { "<leader>oac", "<cmd>Octo comment add<cr>",     desc = "Add: comment" },
      { "<leader>oas", "<cmd>Octo comment suggest<cr>", desc = "Add: suggestion (in review)" },
      { "<leader>oal", "<cmd>Octo label add<cr>",       desc = "Add: label" },
      { "<leader>oaa", "<cmd>Octo assignee add<cr>",    desc = "Add: assignee" },
      { "<leader>oav", "<cmd>Octo reviewer add<cr>",    desc = "Add: reviewer" },
    },
    opts = function()
      -- Prefer the gh that `dot install gh` put in ~/.local/bin over whatever
      -- an inherited PATH resolves to — same trick as `claude` in ai.lua.
      local gh = vim.fn.exepath("gh")
      if gh == "" then gh = vim.fn.expand("~/.local/bin/gh") end

      return {
        gh_cmd = vim.fn.executable(gh) == 1 and gh or "gh",
        picker = "telescope",
        -- Makes a bare `:Octo` list every command in the picker, which is what
        -- <leader>oo leans on.
        enable_builtin = true,

        -- Off so octo does not register its own CursorMoved autocmd;
        -- apply_auto_threads() above owns it, which keeps it toggleable.
        reviews = { auto_show_threads = false },

        -- Two of octo's buffer-local defaults sit on keys this config already
        -- uses globally: `<leader>qa` (approve) would stall <leader>q, and
        -- `<C-e>` (copy SHA) would shadow the harpoon menu inside PR and
        -- review buffers. Move both onto <localleader> (`\`) instead.
        mappings = {
          pull_request = {
            approve_pr = { lhs = "<localleader>pa", desc = "approve PR" },
            copy_sha   = { lhs = "<localleader>gs", desc = "copy commit SHA to system clipboard" },
          },
          review_diff = {
            copy_sha = { lhs = "<localleader>gs", desc = "copy commit SHA to system clipboard" },
          },
        },
      }
    end,
    config = function(_, opts)
      require("octo").setup(opts)
      apply_auto_threads()

      if vim.fn.executable(opts.gh_cmd) == 0 then
        vim.notify(
          "octo.nvim needs the gh CLI — run `dot install gh`, then `gh auth login`",
          vim.log.levels.WARN
        )
      end
    end,
  },
}
