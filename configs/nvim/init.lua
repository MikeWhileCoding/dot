-- init.lua — Neovim entry point
require("config.options")
require("config.keymaps")
require("config.lazy")

-- :ProjectTools / :ProjectToolsInit / :ProjectToolsReload — where the
-- project's formatters, linters and debuggers actually run.
require("project.runner").setup()
