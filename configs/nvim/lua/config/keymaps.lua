-- keymaps.lua — core keybindings (plugin keymaps live in each plugin spec)
local map = vim.keymap.set

vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

-- ── Your binds (priority) ─────────────────────────────────────────────

-- File explorer (Oil)
map("n", "<leader>pv", function() require("oil").open() end, { desc = "Open file explorer" })

-- ── Harpoon (defined here for visibility; wired in plugins/editor.lua) ─
-- <leader>a   add file
-- <C-e>       toggle quick menu
-- <C-h>       select 1
-- <C-t>       select 2
-- <C-n>       select 3
-- <C-s>       select 4

-- ── Telescope (defined here for visibility; wired in plugins/telescope.lua) ─
-- <leader>pf  find files
-- <C-p>       git files
-- <leader>ps  grep prompt

-- ── Laravel / PHP (wired in plugins/php.lua) ──────────────────────────
-- <leader>ll  laravel picker      <leader>la  artisan
-- <leader>lr  routes              <leader>lu  artisan hub
-- <leader>lm  make                <leader>lt  code actions
-- <C-g>       blade view finder   gf          follow route()/view()/config()
-- <leader>li  import class (php)  :LaravelIdeHelper  regenerate model stubs
--
-- ── Debug / Xdebug (wired in plugins/php.lua) ─────────────────────────
-- <leader>bb  breakpoint          <leader>bc / <F5>  continue
-- <leader>bo  step over           <leader>bi  step into
-- <leader>bt  toggle dap-ui       <leader>bx  terminate

-- ── AI: Copilot autofill + Claude Code (wired in lua/ai/init.lua and
--        plugins/ai.lua; state persists across restarts) ───────────────
-- <leader>it  toggle Copilot        <leader>ia  toggle autofill (ghost text)
-- <leader>ib  toggle autofill here  <leader>is  status
-- <leader>ip  Copilot panel         <leader>iA  Copilot sign in
-- <leader>ic  Claude Code toggle    <leader>if  Claude Code focus
-- <leader>ix  send buffer/selection <leader>im  pick Claude model
-- <leader>iy / <leader>in  accept / reject a Claude diff
-- :AI [status|on|off|toggle|autofill|buffer|claude]
--
-- Insert mode (Copilot): <M-l> accept  <M-w> word  <M-j> line
--                        <M-]> / <M-[> cycle  <C-]> dismiss
--                        <Tab> accepts too, once the cmp menu is closed

-- ── Split navigation (use <C-w> prefix — <C-h/n/s> reserved for harpoon) ──
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower split" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper split" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })

-- Resize splits
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Increase window height" })
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Decrease window height" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- ── Useful extras ─────────────────────────────────────────────────────

-- Better up/down on wrapped lines
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==",  { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==",  { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Quickfix
map("n", "<leader>q", "<cmd>copen<cr>", { desc = "Open quickfix" })
map("n", "[q",        "<cmd>cprev<cr>", { desc = "Prev quickfix" })
map("n", "]q",        "<cmd>cnext<cr>", { desc = "Next quickfix" })

-- Diagnostics
map("n", "[d",        vim.diagnostic.goto_prev,  { desc = "Prev diagnostic" })
map("n", "]d",        vim.diagnostic.goto_next,  { desc = "Next diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic" })

-- Buffer / save
map("n", "<leader>w", "<cmd>w<cr>",   { desc = "Save" })
map("n", "<leader>W", "<cmd>wa<cr>",  { desc = "Save all" })
map("n", "<leader>x", "<cmd>bd<cr>",  { desc = "Close buffer" })
map("n", "<Esc>",     "<cmd>noh<cr>", { desc = "Clear search highlight" })
