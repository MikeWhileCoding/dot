-- ui.lua — status line, indent guides, notifications
return {
  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme           = "vague",
        component_separators = { left = "", right = "" },
        section_separators  = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          -- Copilot autofill state — see lua/ai/init.lua.
          {
            function()
              local ok, ai = pcall(require, "ai")
              return ok and ai.statusline() or ""
            end,
            on_click = function()
              local ok, ai = pcall(require, "ai")
              if ok then ai.toggle("autofill") end
            end,
          },
          "encoding", "fileformat", "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent  = { char = "│" },
      scope   = { enabled = true },
    },
  },

  -- UI component improvements (input, select)
  {
    "stevearc/dressing.nvim",
    opts = {},
  },

  -- Icons
  { "nvim-tree/nvim-web-devicons", lazy = true },
}
