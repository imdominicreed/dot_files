-- Treesitter - Syntax highlighting and more
return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSInstall python go lua rust",
}
