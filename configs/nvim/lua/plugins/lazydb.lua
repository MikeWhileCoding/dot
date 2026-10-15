-- lazydb.lua — LazyDB floating terminal + SQL LSP (`lazydb lsp --stdio`)
return {
  {
    "yelog/lazydb.nvim",
    -- ft so the SQL LSP (catalog completion, diagnostics) attaches without
    -- opening the UI first.
    ft   = { "sql" },
    cmd  = { "LazyDB", "LazyDBToggle", "LazyDBHide", "LazyDBStop", "LazyDBRestart" },
    keys = {
      { "<leader>D", function() require("lazydb").toggle() end, desc = "Toggle LazyDB" },
    },
    opts = {
      window = { width = 0.92, height = 0.90, border = "rounded" },
    },
  },
}
