-- Neovim options
local opt = vim.opt
local g = vim.g

-- Leader key
g.mapleader = " "
g.maplocalleader = " "

-- netrw: used as the sidebar file tree for remote (scp://) browsing, since
-- nvim-tree is local-filesystem only. :Lexplore opens it as a left split.
g.netrw_liststyle = 3 -- tree listing
g.netrw_winsize = 25 -- 25% width
g.netrw_banner = 0 -- no header blurb
g.netrw_browse_split = 4 -- open files in the previous window
g.netrw_fastbrowse = 2 -- keep cached listings (big win over ssh); R to refresh
g.netrw_keepdir = 0 -- cwd follows the browsed dir, so :e/:find work relatively
g.netrw_sizestyle = "H" -- human-readable file sizes
g.netrw_localcopydircmd = "cp -r" -- recursive copy instead of failing on dirs
g.netrw_preview = 1 -- p previews in a vertical split
g.netrw_alto = 0

-- General
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.termguicolors = true
opt.timeoutlen = 400
opt.updatetime = 250
opt.undofile = true

-- UI
opt.laststatus = 3 -- global statusline
opt.showmode = false
opt.cursorline = true
opt.number = true
opt.numberwidth = 2
opt.ruler = false
opt.signcolumn = "yes"
opt.fillchars = { eob = " " }
opt.shortmess:append("sI") -- disable nvim intro

-- Indenting
opt.expandtab = false
opt.shiftwidth = 2
opt.smartindent = true
opt.tabstop = 2
opt.softtabstop = 2

-- Search
opt.ignorecase = true
opt.smartcase = true

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Line wrapping behavior
opt.whichwrap:append("<>[]hl")

-- Disable default providers
for _, provider in ipairs({ "node", "perl", "python3", "ruby" }) do
	g["loaded_" .. provider .. "_provider"] = 0
end

-- Add mason binaries to path
local is_windows = vim.fn.has("win32") ~= 0
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin" .. (is_windows and ";" or ":") .. vim.env.PATH
