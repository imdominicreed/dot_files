-- Which-key - Keybinding hints
return {
	"folke/which-key.nvim",
	keys = { "<leader>", "<c-r>", "<c-w>", '"', "'", "`", "c", "v", "g" },
	cmd = "WhichKey",
	config = function()
		local wk = require("which-key")
		wk.setup({
			plugins = {
				marks = true,
				registers = true,
				spelling = { enabled = true, suggestions = 20 },
				presets = {
					operators = false,
					motions = false,
					text_objects = false,
					windows = true,
					nav = true,
					z = true,
					g = true,
				},
			},
			icons = {
				breadcrumb = "»",
				separator = "➜",
				group = "+",
			},
			win = {
				border = "rounded",
				padding = { 2, 2, 2, 2 },
			},
			layout = {
				height = { min = 4, max = 25 },
				width = { min = 20, max = 50 },
				spacing = 3,
				align = "left",
			},
		})

		-- Register groups
		wk.add({
			{ "<leader>f", group = "Find" },
			{ "<leader>g", group = "Git" },
			{ "<leader>l", group = "LSP" },
			{ "<leader>d", group = "Debug" },
			{ "<leader>c", group = "Code/AI" },
			{ "<leader>w", group = "Workspace" },
		})
	end,
}
