-- init.lua — Neovim entry point
require("config.options")
require("config.keymaps")

-- :AI / <leader>i… — Copilot autofill and the optional Claude Code bridge.
-- Loaded before lazy so the plugin specs can read the saved on/off state.
require("ai").setup()

require("config.lazy")

-- :ProjectTools / :ProjectToolsInit / :ProjectToolsReload — where the
-- project's formatters, linters and debuggers actually run.
require("project.runner").setup()
