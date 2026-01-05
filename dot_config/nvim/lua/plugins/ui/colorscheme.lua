-- Everblush colorscheme
return {
	"Everblush/nvim",
	name = "everblush",
	lazy = false,
	priority = 1000,
	config = function()
		require("everblush").setup({
			override = {},
			transparent_background = false,
			nvim_tree = {
				contrast = true,
			},
		})
		vim.cmd.colorscheme("everblush")
	end,
}
