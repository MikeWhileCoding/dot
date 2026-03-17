-- options.lua — editor settings
local opt = vim.opt

-- Indentation
opt.tabstop      = 2
opt.shiftwidth   = 2
opt.expandtab    = true
opt.smartindent  = true
opt.breakindent  = true

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Search
opt.hlsearch   = false
opt.incsearch  = true
opt.ignorecase = true
opt.smartcase  = true

-- UI
opt.termguicolors = true
opt.signcolumn    = "yes"
opt.cursorline    = true
opt.scrolloff     = 8
opt.sidescrolloff = 8
opt.wrap          = false
opt.colorcolumn   = "120"
opt.splitright    = true
opt.splitbelow    = true
opt.showmode      = false  -- shown by lualine

-- Files
opt.undofile  = true
opt.swapfile  = false
opt.backup    = false
opt.clipboard = "unnamedplus"

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight   = 10

-- Misc
opt.updatetime = 250
opt.timeoutlen = 300
opt.mouse      = "a"
opt.fileencoding = "utf-8"
