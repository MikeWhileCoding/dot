-- treesitter.lua — syntax highlighting and text objects
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build  = ":TSUpdate",
    event  = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter").setup({
        ensure_installed = {
          "bash", "c", "css", "dockerfile", "go", "html",
          "javascript", "json", "lua", "markdown", "markdown_inline",
          "python", "rust", "sql", "toml", "typescript", "vim",
          "vimdoc", "yaml",
        },
        auto_install = true,
      })
    end,
  },

  -- Text objects (af/if for functions, ac/ic for classes, ]f/[f to jump)
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event        = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          enable    = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        move = {
          enable    = true,
          set_jumps = true,
          goto_next_start     = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
          goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
        },
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts         = { max_lines = 3 },
  },

  {
    "hiphish/rainbow-delimiters.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event        = { "BufReadPost", "BufNewFile" },
    -- init runs before the plugin's FileType autocmd is registered,
    -- so the global is already set when the autocmd fires.
    init = function()
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = function(bufnr)
            local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
            if not ok or not parser then return nil end
            return require("rainbow-delimiters").strategy["global"]
          end,
        },
        query = {
          [""] = "rainbow-delimiters",
          lua  = "rainbow-blocks",
        },
      }
    end,
  },
}
