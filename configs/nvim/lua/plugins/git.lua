-- git.lua — git integration
return {
  -- Gitsigns: hunk indicators in the gutter
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = "Git: " .. desc })
        end

        -- Navigation
        map("n", "]h", gs.next_hunk,   "Next hunk")
        map("n", "[h", gs.prev_hunk,   "Prev hunk")
        -- Actions
        map("n", "<leader>gs", gs.stage_hunk,          "Stage hunk")
        map("n", "<leader>gr", gs.reset_hunk,          "Reset hunk")
        map("n", "<leader>gS", gs.stage_buffer,        "Stage buffer")
        map("n", "<leader>gu", gs.undo_stage_hunk,     "Undo stage hunk")
        map("n", "<leader>gR", gs.reset_buffer,        "Reset buffer")
        map("n", "<leader>gp", gs.preview_hunk,        "Preview hunk")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gd", gs.diffthis,            "Diff this")
      end,
    },
  },

  -- Fugitive: Git commands in Neovim
  {
    "tpope/vim-fugitive",
    cmd  = { "Git", "G" },
    keys = {
      { "<leader>gg", "<cmd>Git<cr>",         desc = "Git status (fugitive)" },
      { "<leader>gc", "<cmd>Git commit<cr>",  desc = "Git commit" },
      { "<leader>gl", "<cmd>Git log<cr>",     desc = "Git log" },
    },
  },
}
