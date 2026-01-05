-- Indent-blankline - Indent guides
return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		indent = {
			char = "│",
			tab_char = "│",
		},
		scope = {
			enabled = true,
			show_start = true,
			show_end = false,
		},
		exclude = {
			filetypes = {
				"help",
				"alpha",
				"dashboard",
				"nvim-tree",
				"Trouble",
				"lazy",
				"mason",
				"notify",
				"toggleterm",
			},
		},
	},
}
