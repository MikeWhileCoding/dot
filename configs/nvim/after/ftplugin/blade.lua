-- Blade templates: four spaces and blade-style comments for `gc`.
vim.bo.shiftwidth   = 4
vim.bo.tabstop      = 4
vim.bo.softtabstop  = 4
vim.bo.expandtab    = true
vim.bo.commentstring = "{{-- %s --}}"

-- `@` is part of a Blade directive, so completion sees `@foreach` as one word.
vim.opt_local.iskeyword:append("@-@")
