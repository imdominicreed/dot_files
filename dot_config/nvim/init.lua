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

-- Folding, navigation and quickfix for gh-reviews pull-request reports.
--
-- Guarded because init.lua and lua/ghreviews/ can arrive separately: a dotfiles
-- commit carrying one without the other should cost you review folding, not
-- every start on that machine. A module that is present but broken still shouts.
local has_ghreviews, ghreviews = pcall(require, "ghreviews")
if has_ghreviews then
	ghreviews.setup()
elseif not tostring(ghreviews):match("module 'ghreviews' not found") then
	vim.notify(tostring(ghreviews), vim.log.levels.ERROR)
end
