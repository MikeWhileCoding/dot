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
      -- PHP formatting can be a `docker exec` round-trip, so it gets a much
      -- longer budget than a local formatter needs.
      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "php" or ft == "blade" then
          return { timeout_ms = 5000, lsp_format = "never" }
        end
        return { timeout_ms = 500, lsp_format = "fallback" }
      end,
    },
  },

  -- Comments: toggle comments
  {
    "OliverHeffernan/comments.nvim",
    keys = {
      { "<C-/>", "<cmd>DotComment<cr>",       mode = "n", desc = "Toggle comment" },
      { "<C-/>", ":DotComment<cr>",           mode = "x", desc = "Toggle comment" },
      { "<C-/>", "<Esc><cmd>DotComment<cr>i", mode = "i", desc = "Toggle comment" },
      { "<C-_>", "<cmd>DotComment<cr>",       mode = "n", desc = "Toggle comment" },
      { "<C-_>", ":DotComment<cr>",           mode = "x", desc = "Toggle comment" },
      { "<C-_>", "<Esc><cmd>DotComment<cr>i", mode = "i", desc = "Toggle comment" },
    },
    config = function()
      local comments = require("comments")

      local function plugin_comment(opts)
        local range = opts.range == 0 and "" or ("%d,%d"):format(opts.line1, opts.line2)
        vim.cmd(range .. "Comment")
      end

      local vue_markers = {
        template_element = { "<!--", "-->" },
        script_element   = { "//", "" },
        style_element    = { "/*", "*/" },
      }

      vim.api.nvim_create_user_command("DotComment", function(opts)
        if vim.bo.filetype ~= "vue" then
          plugin_comment(opts)
          return
        end

        local ok, parser = pcall(vim.treesitter.get_parser, 0, "vue")
        local trees = ok and parser:parse() or nil
        if not trees or not trees[1] then
          plugin_comment(opts)
          return
        end

        local root = trees[1]:root()
        local cursor = vim.api.nvim_win_get_cursor(0)
        for line_number = opts.line1, opts.line2 do
          local line = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]
          local column = math.max((line:find("%S") or 1) - 1, 0)
          local node = root:named_descendant_for_range(line_number - 1, column, line_number - 1, column)
          local markers

          while node and not markers do
            markers = vue_markers[node:type()]
            node = node:parent()
          end

          if markers then
            local indent, text = line:match("^(%s*)(.*)$")
            if vim.startswith(text, markers[1]) and (markers[2] == "" or text:sub(-#markers[2]) == markers[2]) then
              local finish = markers[2] == "" and nil or -#markers[2] - 1
              text = text:sub(#markers[1] + 1, finish)
            else
              text = markers[1] .. text .. markers[2]
            end
            vim.api.nvim_buf_set_lines(0, line_number - 1, line_number, false, { indent .. text })
          else
            vim.api.nvim_win_set_cursor(0, { line_number, 0 })
            comments.comment_based_on_context()
          end
        end
        vim.api.nvim_win_set_cursor(0, cursor)
      end, { range = true })
    end,
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
        { "<leader>l", group = "lsp/laravel" },
        { "<leader>b", group = "debug" },
        { "<leader>g", group = "git" },
        { "<leader>i", group = "ai (copilot/claude)" },
      },
    },
  },
}
