-- editor.lua — file navigation, quick marks, formatting, comments
return {
  -- Oil: file browser as a buffer
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (Oil)" },
    },
    opts = {
      default_file_explorer = true,
      view_options          = { show_hidden = true },
    },
  },

  -- Harpoon: quick file marks
  {
    "ThePrimeagen/harpoon",
    branch       = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon:setup()

      vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end,                         { desc = "Harpoon add" })
      vim.keymap.set("n", "<C-e>",     function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon menu" })
      vim.keymap.set("n", "<C-h>",     function() harpoon:list():select(1) end,                     { desc = "Harpoon 1" })
      vim.keymap.set("n", "<C-t>",     function() harpoon:list():select(2) end,                     { desc = "Harpoon 2" })
      vim.keymap.set("n", "<C-n>",     function() harpoon:list():select(3) end,                     { desc = "Harpoon 3" })
      vim.keymap.set("n", "<C-s>",     function() harpoon:list():select(4) end,                     { desc = "Harpoon 4" })
    end,
  },

  -- Conform: formatting
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    keys = {
      { "<leader>lf", function() require("conform").format({ async = true }) end, desc = "Format buffer" },
    },
    opts = {
      formatters_by_ft = {
        lua        = { "stylua" },
        go         = { "gofmt" },
        python     = { "black" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json       = { "prettier" },
        yaml       = { "prettier" },
        markdown   = { "prettier" },
        sh         = { "shfmt" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
      },
    },
  },

  -- Comment: toggle comments
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gc", mode = { "n", "v" }, desc = "Toggle comment" },
    },
    opts = {},
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts  = { check_ts = true },
  },

  -- Surround
  {
    "kylechui/nvim-surround",
    version = "*",
    event   = "VeryLazy",
    opts    = {},
  },

  -- Which-key: show pending keybindings
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts  = {
      plugins = { spelling = true },
      spec = {
        { "<leader>s", group = "search/telescope" },
        { "<leader>h", group = "harpoon" },
        { "<leader>l", group = "lsp" },
        { "<leader>g", group = "git" },
      },
    },
  },
}
