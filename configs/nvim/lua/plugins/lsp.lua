-- lsp.lua — LSP via Neovim 0.11 native vim.lsp.config + Mason
return {
  -- Mason: install/manage LSP servers, linters, formatters
  {
    "williamboman/mason.nvim",
    cmd  = "Mason",
    opts = { ui = { border = "rounded" } },
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "lua_ls", "bashls", "jsonls", "yamlls",
        "pyright", "ts_ls", "html", "cssls",
      },
    },
  },

  -- Native LSP config (nvim 0.11+)
  {
    "neovim/nvim-lspconfig",
    event        = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach = function(_, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
        end
        map("gd",         "<cmd>Telescope lsp_definitions<cr>",     "Go to definition")
        map("gr",         "<cmd>Telescope lsp_references<cr>",      "References")
        map("gI",         "<cmd>Telescope lsp_implementations<cr>", "Implementations")
        map("gD",         vim.lsp.buf.declaration,                  "Declaration")
        map("K",          vim.lsp.buf.hover,                        "Hover docs")
        map("<leader>rn", vim.lsp.buf.rename,                       "Rename symbol")
        map("<leader>ca", vim.lsp.buf.code_action,                  "Code action")
        map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format")
      end

      -- Shared defaults for all servers
      vim.lsp.config("*", {
        capabilities = capabilities,
        on_attach    = on_attach,
      })

      -- Per-server overrides
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime     = { version = "LuaJIT" },
            workspace   = { checkThirdParty = false },
            telemetry   = { enable = false },
            diagnostics = { globals = { "vim" } },
          },
        },
      })

      -- Enable all servers mason-lspconfig ensures are installed
      vim.lsp.enable({
        "lua_ls", "bashls", "jsonls", "yamlls",
        "pyright", "ts_ls", "html", "cssls",
      })

      -- Diagnostics appearance
      vim.diagnostic.config({
        virtual_text  = { prefix = "●" },
        severity_sort = true,
        float         = { border = "rounded", source = true },
      })
    end,
  },
}
