-- Treesitter - Syntax highlighting and more
return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPost", "BufNewFile" },
	cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
	build = ":TSUpdate",
	opts = {
		ensure_installed = {
			"lua",
			"vim",
			"vimdoc",
			"go",
			"gomod",
			"gosum",
			"rust",
			"javascript",
			"typescript",
			"tsx",
			"json",
			"yaml",
			"toml",
			"markdown",
			"markdown_inline",
			"bash",
			"fish",
			"html",
			"css",
		},
		highlight = {
			enable = true,
			use_languagetree = true,
		},
		indent = { enable = true },
	},
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)
	end,
}
