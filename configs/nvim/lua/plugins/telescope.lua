-- telescope.lua — fuzzy finder
return {
  {
    "nvim-telescope/telescope.nvim",
    cmd          = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond  = function() return vim.fn.executable("make") == 1 end,
      },
    },
    keys = {
      -- ── Your binds (priority) ───────────────────────────────────────
      { "<leader>pf", "<cmd>Telescope find_files<cr>",  desc = "Find files" },
      { "<C-p>",      "<cmd>Telescope git_files<cr>",   desc = "Git files" },
      { "<leader>ps", function()
          require("telescope.builtin").grep_string({ search = vim.fn.input("Grep > ") })
        end, desc = "Grep prompt" },

      -- ── Extras ─────────────────────────────────────────────────────
      { "<leader>sg", "<cmd>Telescope live_grep<cr>",                   desc = "Live grep" },
      { "<leader>sb", "<cmd>Telescope buffers<cr>",                     desc = "Buffers" },
      { "<leader>sh", "<cmd>Telescope help_tags<cr>",                   desc = "Help tags" },
      { "<leader>sr", "<cmd>Telescope oldfiles<cr>",                    desc = "Recent files" },
      { "<leader>sd", "<cmd>Telescope diagnostics<cr>",                 desc = "Diagnostics" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<cr>",        desc = "Document symbols" },
      { "<leader>sw", "<cmd>Telescope grep_string<cr>",                 desc = "Word under cursor" },
      { "<leader>s/", "<cmd>Telescope current_buffer_fuzzy_find<cr>",   desc = "Search buffer" },
    },
    config = function()
      local telescope = require("telescope")
      local actions   = require("telescope.actions")

      telescope.setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_config    = { prompt_position = "top" },
          mappings         = {
            i = {
              ["<C-j>"]   = actions.move_selection_next,
              ["<C-k>"]   = actions.move_selection_previous,
              ["<C-q>"]   = actions.send_selected_to_qflist + actions.open_qflist,
              ["<Esc>"]   = actions.close,
            },
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
    end,
  },
}
