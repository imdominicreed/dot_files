-- Treesitter - Syntax highlighting and more
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local ts = require("nvim-treesitter")
		--
		-- -- Install core parsers
		-- ts.install({
		-- 	"go",
		-- 	"gomod",
		-- 	"gosum",
		-- 	"gowork",
		-- 	"lua",
		-- 	"python",
		-- 	"rust",
		-- 	"vim",
		-- 	"vimdoc",
		-- 	"markdown",
		-- 	"markdown_inline",
		-- })
		--
		-- Enable treesitter features on FileType
		-- vim.api.nvim_create_autocmd("FileType", {
		-- 	group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
		-- 	callback = function(event)
		-- 		pcall(vim.treesitter.start, event.buf)
		-- 	end,
		-- })
	end,
}
