-- Snacks.nvim - Modern picker and utilities
return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		picker = {},
	},
	keys = {
		-- Find/Search
		{ "<leader>sf", function() Snacks.picker.files() end, desc = "Find Files" },
		{ "<leader>sF", function() Snacks.picker.files({ hidden = true, ignored = true }) end, desc = "Find All Files" },
		{ "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
		{ "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Grep Word", mode = { "n", "x" } },
		{ "<leader>sb", function() Snacks.picker.buffers() end, desc = "Buffers" },
		{ "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
		{ "<leader>sr", function() Snacks.picker.recent() end, desc = "Recent Files" },
		{ "<leader>s/", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
		-- Git
		{ "<leader>gc", function() Snacks.picker.git_log() end, desc = "Git Commits" },
		{ "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
		-- Other
		{ "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
		{ "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
	},
}
