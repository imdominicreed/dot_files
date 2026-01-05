-- Toggleterm - Terminal integration
return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = {
		{ "<A-i>", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle floating terminal" },
		{ "<A-h>", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Toggle horizontal terminal" },
		{ "<A-v>", "<cmd>ToggleTerm direction=vertical<cr>", desc = "Toggle vertical terminal" },
		{ "<leader>h", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "New horizontal terminal" },
		{ "<leader>v", "<cmd>ToggleTerm direction=vertical<cr>", desc = "New vertical terminal" },
		-- Terminal mode mappings
		{ "<A-i>", "<cmd>ToggleTerm direction=float<cr>", mode = "t", desc = "Toggle floating terminal" },
		{ "<A-h>", "<cmd>ToggleTerm direction=horizontal<cr>", mode = "t", desc = "Toggle horizontal terminal" },
		{ "<A-v>", "<cmd>ToggleTerm direction=vertical<cr>", mode = "t", desc = "Toggle vertical terminal" },
	},
	opts = {
		size = function(term)
			if term.direction == "horizontal" then
				return 15
			elseif term.direction == "vertical" then
				return vim.o.columns * 0.4
			end
		end,
		open_mapping = nil,
		hide_numbers = true,
		shade_terminals = true,
		shading_factor = 2,
		start_in_insert = true,
		insert_mappings = true,
		persist_size = true,
		direction = "float",
		close_on_exit = true,
		shell = vim.o.shell,
		float_opts = {
			border = "curved",
			winblend = 0,
			highlights = {
				border = "Normal",
				background = "Normal",
			},
		},
	},
}
