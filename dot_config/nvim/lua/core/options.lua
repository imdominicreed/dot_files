-- Neovim options
local opt = vim.opt
local g = vim.g

-- Leader key
g.mapleader = " "
g.maplocalleader = " "

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
