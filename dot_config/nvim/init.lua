-- Neovim configuration
-- Classic structure without NvChad

-- Machine-local overrides, loaded before anything reads them. lua/machine.lua is
-- deliberately untracked (see .chezmoiignore), so one machine can differ without
-- the difference reaching the dotfiles repo or the other machines.
pcall(require, "machine")

require("core.options")
require("core.lazy")
require("core.keymaps")
require("core.autocmds")
