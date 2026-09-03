-- PSR-12: four spaces, and `$` is part of a variable name.
vim.bo.shiftwidth  = 4
vim.bo.tabstop     = 4
vim.bo.softtabstop = 4
vim.bo.expandtab   = true
vim.opt_local.iskeyword:append("$")

-- Intelephense's premium licence adds "Import 'X'" code actions; this applies
-- the matching one for the symbol under the cursor without opening the menu.
vim.keymap.set("n", "<leader>li", function()
  vim.lsp.buf.code_action({
    apply  = true,
    filter = function(action)
      local title = (action.title or ""):lower()
      return title:find("^import") ~= nil or title:find("use declaration") ~= nil
    end,
  })
end, { buffer = true, desc = "PHP: import symbol under cursor" })
