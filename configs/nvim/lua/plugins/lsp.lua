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
        "intelephense",
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
    config       = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach = function(_, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
        end
        map("gd", "<cmd>Telescope lsp_definitions<cr>", "Go to definition")
        map("gr", "<cmd>Telescope lsp_references<cr>", "References")
        map("gI", "<cmd>Telescope lsp_implementations<cr>", "Implementations")
        map("gD", vim.lsp.buf.declaration, "Declaration")
        map("K", vim.lsp.buf.hover, "Hover docs")
        map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")
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

      -- Intelephense — the premium licence unlocks rename, code actions and
      -- the smarter diagnostics. The key is read from (first hit wins):
      --   $INTELEPHENSE_LICENCE_KEY / $INTELEPHENSE_LICENSE_KEY
      --   ~/.config/intelephense/licence.txt
      --   ~/intelephense/licence.txt          (Intelephense's own default)
      -- Keep the key out of this repo; it is a secret.
      local function intelephense_licence()
        local env = vim.env.INTELEPHENSE_LICENCE_KEY or vim.env.INTELEPHENSE_LICENSE_KEY
        if env and env ~= "" then return vim.trim(env) end

        for _, path in ipairs({
          vim.fn.expand("~/.config/intelephense/licence.txt"),
          vim.fn.expand("~/intelephense/licence.txt"),
        }) do
          local fd = io.open(path, "r")
          if fd then
            local key = vim.trim(fd:read("*a") or "")
            fd:close()
            if key ~= "" then return key end
          end
        end
      end

      vim.lsp.config("intelephense", {
        init_options = {
          licenceKey  = intelephense_licence(),
          storagePath = vim.fn.stdpath("cache") .. "/intelephense",
        },
        settings = {
          intelephense = {
            -- Laravel apps are large; the default 1MB cutoff skips files.
            files = {
              maxSize     = 5000000,
              exclude     = {
                "**/.git/**", "**/node_modules/**", "**/bower_components/**",
                "**/vendor/**/{Tests,tests}/**", "**/.history/**",
                "**/storage/framework/**", "**/bootstrap/cache/**",
              },
            },
            -- Facades and dynamic model attributes resolve once
            -- `composer require --dev barryvdh/laravel-ide-helper` has written
            -- _ide_helper.php / _ide_helper_models.php into the project root —
            -- Intelephense indexes them from there automatically.
            stubs = {
              "apache", "bcmath", "bz2", "calendar", "com_dotnet", "Core", "csv", "ctype",
              "curl", "date", "dba", "dom", "enchant", "exif", "fileinfo", "filter", "fpm",
              "ftp", "gd", "gettext", "gmp", "hash", "iconv", "imagick", "imap", "intl",
              "json", "ldap", "libxml", "mbstring", "meta", "mysqli", "oci8", "odbc",
              "openssl", "pcntl", "pcre", "PDO", "pdo_ibm", "pdo_mysql", "pdo_pgsql",
              "pdo_sqlite", "pgsql", "Phar", "posix", "pspell", "readline", "redis",
              "Reflection", "session", "shmop", "SimpleXML", "snmp", "soap", "sockets",
              "sodium", "SPL", "sqlite3", "standard", "superglobals", "sysvmsg", "sysvsem",
              "sysvshm", "tidy", "tokenizer", "xml", "xmlreader", "xmlrpc", "xmlwriter",
              "xsl", "Zend OPcache", "zip", "zlib",
            },
            completion = {
              -- Accepting a class from the completion menu writes its `use`
              -- statement — the auto-import behaviour the premium licence adds.
              insertUseDeclaration                    = true,
              fullyQualifyGlobalConstantsAndFunctions = false,
              triggerParameterHints                   = true,
            },
            -- Pint owns formatting (see plugins/tools.lua).
            format = { enable = false },
          },
        },
      })

      -- laravel-ls (the Laravel language server) — only when it is installed.
      if vim.fn.executable("laravel-lsp") == 1 then
        vim.lsp.config("laravel_lsp", {
          cmd = { "laravel-lsp" },
          filetypes = { "php", "blade" },
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, "artisan")

            if root then
              on_dir(root)
            end
          end,
        })
        vim.lsp.enable("laravel_lsp")
      end

      -- Enable all servers mason-lspconfig ensures are installed
      vim.lsp.enable({
        "lua_ls", "bashls", "jsonls", "yamlls",
        "pyright", "ts_ls", "html", "cssls",
        "intelephense",
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
