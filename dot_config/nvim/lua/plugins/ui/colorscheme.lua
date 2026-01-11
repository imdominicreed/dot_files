-- Catppuccin colorscheme
return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false,
	priority = 1000,
	config = function()
		require("catppuccin").setup({
			flavour = "mocha",
			integrations = {
				auto_integations = true,
			-- 	cmp = true,
			-- 	gitsigns = true,
			-- 	nvim_tree = true,
			-- 	treesitter = true,
			-- 	mason = true,
			-- 	fidget = true,
			-- 	native_lsp = {
			-- 		enabled = true,
			-- 		underlines = {
			-- 			errors = { "undercurl" },
			-- 			hints = { "undercurl" },
			-- 			warnings = { "undercurl" },
			-- 			information = { "undercurl" },
			-- 		},
			-- 	},
			-- 	semantic_tokens = true,
			},
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}
