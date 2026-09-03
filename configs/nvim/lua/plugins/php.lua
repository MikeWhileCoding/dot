-- php.lua — Laravel tooling and Xdebug.
--
-- Formatting (pint, blade-formatter) and diagnostics (phpstan) live in
-- plugins/tools.lua: they share the project runner with the JS tooling, and
-- `.nvim-tools.json` decides which container each of them runs in.
return {
  -- ── Laravel: artisan, routes, models, blade-aware gf, completion ──────
  {
    "adalessa/laravel.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
      "nvim-telescope/telescope.nvim",
    },
    ft    = { "php", "blade" },
    event = { "BufEnter composer.json" },
    keys  = {
      { "<leader>ll", function() Laravel.pickers.laravel() end,              desc = "Laravel: picker" },
      { "<leader>la", function() Laravel.pickers.artisan() end,              desc = "Laravel: artisan" },
      { "<leader>lr", function() Laravel.pickers.routes() end,               desc = "Laravel: routes" },
      { "<leader>lm", function() Laravel.pickers.make() end,                 desc = "Laravel: make" },
      { "<leader>lc", function() Laravel.pickers.commands() end,             desc = "Laravel: custom commands" },
      { "<leader>lo", function() Laravel.pickers.resources() end,            desc = "Laravel: resources" },
      { "<leader>lt", function() Laravel.commands.run("actions") end,        desc = "Laravel: code actions" },
      { "<leader>lu", function() Laravel.commands.run("hub") end,            desc = "Laravel: artisan hub" },
      { "<leader>lp", function() Laravel.commands.run("command_center") end, desc = "Laravel: command center" },
      { "<leader>lk", function() Laravel.run("artisan docs") end,            desc = "Laravel: docs" },
      { "<C-g>",      function() Laravel.commands.run("view:finder") end,    desc = "Laravel: view finder" },
      {
        "gf",
        function()
          if Laravel.app("gf").cursorOnResource() then
            return "<cmd>lua Laravel.commands.run('gf')<cr>"
          end
          return "gf"
        end,
        expr = true, noremap = true, desc = "Laravel: go to resource",
      },
    },
    opts = function()
      local rn   = require("project.runner")
      local cfg  = rn.config(0)
      local opts = {
        features = { pickers = { provider = "telescope" } },
      }

      -- Reuse the project's `.nvim-tools.json` for artisan/composer/npm too,
      -- so there is a single place that says where things run.
      if (cfg.runner or "local") ~= "local" then
        local map = {}
        for _, exe in ipairs({ "php", "composer", "npm", "yarn" }) do
          local spec = rn.command(exe, 0)
          if spec then map[exe] = spec.argv end
        end
        if not vim.tbl_isempty(map) then
          local definitions = { { name = "nvim-tools", map = map } }
          vim.list_extend(definitions, vim.deepcopy(require("laravel.options.environments").definitions))
          opts.environments = { default = "nvim-tools", definitions = definitions }
        end
      end

      return opts
    end,
    config = function(_, opts)
      require("laravel").setup(opts)

      -- laravel.nvim registers a cmp source named "laravel" (views, routes,
      -- config keys, env vars, model columns) — enable it for PHP buffers.
      local ok, cmp = pcall(require, "cmp")
      if ok then
        cmp.setup.filetype({ "php", "blade", "tinker" }, {
          sources = cmp.config.sources({
            { name = "laravel",  priority = 1100 },
            { name = "nvim_lsp", priority = 1000 },
            { name = "luasnip",  priority = 750 },
            { name = "buffer",   priority = 500 },
            { name = "path",     priority = 250 },
          }),
        })
      end
    end,
  },

  -- ── Debugging: Xdebug, with the container path mapping ────────────────
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
      { "theHamsta/nvim-dap-virtual-text", opts = {} },
    },
    ft   = { "php", "blade" },
    keys = {
      { "<leader>bb", function() require("dap").toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
      { "<leader>bB", function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end, desc = "Debug: conditional breakpoint" },
      { "<leader>bc", function() require("dap").continue() end,    desc = "Debug: continue / start" },
      { "<leader>bo", function() require("dap").step_over() end,   desc = "Debug: step over" },
      { "<leader>bi", function() require("dap").step_into() end,   desc = "Debug: step into" },
      { "<leader>bu", function() require("dap").step_out() end,    desc = "Debug: step out" },
      { "<leader>bx", function() require("dap").terminate() end,   desc = "Debug: terminate" },
      { "<leader>br", function() require("dap").repl.toggle() end, desc = "Debug: REPL" },
      { "<leader>bt", function() require("dapui").toggle() end,    desc = "Debug: toggle UI" },
      { "<F5>",  function() require("dap").continue() end,  desc = "Debug: continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
    },
    config = function()
      local dap   = require("dap")
      local dapui = require("dapui")

      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/php-debug-adapter"
      local adapter   = vim.fn.executable(mason_bin) == 1 and mason_bin or "php-debug-adapter"

      dap.adapters.php = { type = "executable", command = adapter, args = {} }

      dap.configurations.php = {
        {
          type    = "php",
          request = "launch",
          name    = "Listen for Xdebug",
          -- Resolved per session from .nvim-tools.json, so a dockerised
          -- project maps /var/www/html back onto the checkout on this machine.
          port         = function() return require("project.runner").xdebug(0).port end,
          pathMappings = function() return require("project.runner").xdebug(0).pathMappings end,
        },
      }

      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"]     = function() dapui.close() end

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped",    { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
    end,
  },
}
