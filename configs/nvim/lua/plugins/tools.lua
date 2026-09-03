-- tools.lua — formatters and linters that run *where the project runs*.
--
-- pint, phpstan and biome usually live inside the project's container. Every
-- command here is built by `project.runner` from the project's
-- `.nvim-tools.json`, including the host <-> container path translation.
-- `:ProjectTools` shows what that resolves to for the current buffer.
local function runner() return require("project.runner") end

---Does this project use biome (rather than prettier) for JS/TS/JSON/CSS?
local function uses_biome(bufnr)
  local rn   = runner()
  local cfg  = rn.config(bufnr)
  local tool = (cfg.tools or {}).biome
  if tool then return tool.enabled ~= false end
  for _, name in ipairs({ "biome.json", "biome.jsonc" }) do
    if vim.uv.fs_stat(rn.root(bufnr) .. "/" .. name) then return true end
  end
  return false
end

---Formatter that rewrites a temp file in place (pint, blade-formatter).
---conform writes that temp file *next to the original*, so the container sees
---it through the same bind mount as the rest of the project.
local function file_formatter(name, extra_args)
  return {
    inherit        = false,
    stdin          = false,
    tmpfile_format = "conform.$RANDOM.$FILENAME",
    command = function(_, ctx)
      local spec = runner().command(name, ctx.buf)
      return spec and spec.argv[1] or name
    end,
    args = function(_, ctx)
      local spec = runner().command(name, ctx.buf)
      if not spec then return {} end
      local args = vim.list_slice(spec.argv, 2)
      vim.list_extend(args, extra_args or {})
      vim.list_extend(args, spec.opts.args or {})
      table.insert(args, runner().to_remote(ctx.filename, spec.env, spec.root))
      return args
    end,
    cwd       = function(_, ctx) return runner().root(ctx.buf) end,
    condition = function(_, ctx) return runner().available(name, ctx.buf) end,
  }
end

---Formatter that reads the buffer on stdin and prints the result (biome).
---`docker exec -i` / `compose exec -T` keep stdin open, so no temp file is
---needed — only the *reported* path has to be the container's.
local function stdin_formatter(name, build_args)
  return {
    inherit = false,
    stdin   = true,
    command = function(_, ctx)
      local spec = runner().command(name, ctx.buf)
      return spec and spec.argv[1] or name
    end,
    args = function(_, ctx)
      local spec = runner().command(name, ctx.buf)
      if not spec then return {} end
      local args = vim.list_slice(spec.argv, 2)
      vim.list_extend(args, build_args(spec, runner().to_remote(ctx.filename, spec.env, spec.root)))
      vim.list_extend(args, spec.opts.args or {})
      return args
    end,
    cwd       = function(_, ctx) return runner().root(ctx.buf) end,
    condition = function(_, ctx) return runner().available(name, ctx.buf) end,
  }
end

local BIOME_FILETYPES = {
  "javascript", "javascriptreact", "typescript", "typescriptreact",
  "json", "jsonc", "css", "graphql",
}

return {
  -- ── Formatting ────────────────────────────────────────────────────────
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft       = opts.formatters_by_ft or {}
      opts.formatters_by_ft.php   = { "pint" }
      opts.formatters_by_ft.blade = { "blade-formatter" }

      -- Biome where the project has adopted it, prettier everywhere else.
      for _, ft in ipairs(BIOME_FILETYPES) do
        local fallback = opts.formatters_by_ft[ft] or { "prettier" }
        opts.formatters_by_ft[ft] = function(bufnr)
          if uses_biome(bufnr) then return { "biome" } end
          return fallback
        end
      end

      opts.formatters = opts.formatters or {}
      opts.formatters.pint = file_formatter("pint")
      opts.formatters["blade-formatter"] = file_formatter("blade-formatter", { "--write" })
      -- `check` also sorts imports and applies safe lint fixes; set
      -- `tools.biome.subcommand = "format"` in .nvim-tools.json for plain
      -- formatting.
      opts.formatters.biome = stdin_formatter("biome", function(spec, path)
        local sub = spec.opts.subcommand or "check"
        if sub == "format" then
          return { "format", "--stdin-file-path", path }
        end
        return { sub, "--write", "--stdin-file-path", path }
      end)

      return opts
    end,
  },

  -- ── Diagnostics ───────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-lint",
    ft = { "php", "javascript", "javascriptreact", "typescript", "typescriptreact",
           "json", "jsonc", "css", "graphql" },
    config = function()
      local lint = require("lint")
      local rn   = require("project.runner")

      local function has_phpstan_config(root)
        for _, name in ipairs({ "phpstan.neon", "phpstan.neon.dist", "phpstan.dist.neon" }) do
          if vim.uv.fs_stat(root .. "/" .. name) then return true end
        end
        return false
      end

      local noop = { cmd = "true", args = {}, stdin = false, append_fname = false, parser = function() return {} end }

      -- phpstan / larastan, one file at a time, JSON output mapped back onto
      -- host paths.
      lint.linters.phpstan = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local spec  = rn.command("phpstan", bufnr)
        if not spec then return noop end

        local bufname  = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
        local severity = spec.opts.severity == "error"
            and vim.diagnostic.severity.ERROR
            or vim.diagnostic.severity.WARN

        local args = vim.list_slice(spec.argv, 2)
        vim.list_extend(args, { "analyse", "--error-format=json", "--no-progress", "--no-interaction" })
        local level = spec.opts.level
        if not level and not has_phpstan_config(spec.root) then level = 5 end
        if level then table.insert(args, "--level=" .. level) end
        if spec.opts.config then table.insert(args, "--configuration=" .. spec.opts.config) end
        -- Containers usually ship php.ini with memory_limit=128M, which is
        -- not enough for a Laravel project. Raise it unless the project's
        -- `tools.phpstan.args` already sets one.
        local user_args = spec.opts.args or {}
        local has_memory_limit = false
        for _, a in ipairs(user_args) do
          if vim.startswith(a, "--memory-limit") then has_memory_limit = true break end
        end
        if not has_memory_limit then table.insert(args, "--memory-limit=" .. (spec.opts.memory_limit or "1G")) end
        vim.list_extend(args, user_args)
        table.insert(args, rn.to_remote(bufname, spec.env, spec.root))

        return {
          cmd             = spec.argv[1],
          cwd             = spec.cwd,
          args            = args,
          stdin           = false,
          append_fname    = false,
          ignore_exitcode = true,
          parser = function(output)
            local start = output and output:find("{")
            if not start then return {} end
            local ok, decoded = pcall(vim.json.decode, output:sub(start))
            if not ok or type(decoded) ~= "table" then return {} end

            local diagnostics = {}
            for path, entry in pairs(decoded.files or {}) do
              if vim.fs.normalize(rn.to_local(path, spec.env, spec.root)) == bufname then
                for _, message in ipairs(entry.messages or {}) do
                  table.insert(diagnostics, {
                    lnum     = math.max((tonumber(message.line) or 1) - 1, 0),
                    col      = 0,
                    message  = message.message,
                    code     = message.identifier,
                    source   = "phpstan",
                    severity = severity,
                  })
                end
              end
            end
            -- Configuration problems (missing neon, bad level, …) land here.
            for _, err in ipairs(decoded.errors or {}) do
              table.insert(diagnostics, {
                lnum     = 0,
                col      = 0,
                message  = tostring(err),
                source   = "phpstan",
                severity = vim.diagnostic.severity.ERROR,
              })
            end
            return diagnostics
          end,
        }
      end

      -- biome lint, reusing nvim-lint's parser for biome's CLI output.
      local biome_builtin = require("lint.linters.biomejs")
      lint.linters.biomejs = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local spec  = rn.command("biome", bufnr)
        if not spec then return noop end

        local args = vim.list_slice(spec.argv, 2)
        table.insert(args, "lint")
        vim.list_extend(args, spec.opts.args or {})
        table.insert(args, rn.to_remote(vim.api.nvim_buf_get_name(bufnr), spec.env, spec.root))

        return {
          cmd             = spec.argv[1],
          cwd             = spec.cwd,
          args            = args,
          stdin           = false,
          append_fname    = false,
          ignore_exitcode = true,
          stream          = "both",
          parser          = biome_builtin.parser,
        }
      end

      local function lint_buffer(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "php" then
          if rn.available("phpstan", bufnr) then lint.try_lint("phpstan") end
        elseif vim.tbl_contains(BIOME_FILETYPES, ft) then
          if uses_biome(bufnr) and rn.available("biome", bufnr) then lint.try_lint("biomejs") end
        end
      end

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        callback = function(ev) lint_buffer(ev.buf) end,
        desc     = "Lint through the project's runner",
      })

      vim.keymap.set("n", "<leader>ln", function()
        lint_buffer(vim.api.nvim_get_current_buf())
      end, { desc = "Lint buffer" })
    end,
  },
}
