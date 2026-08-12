-- sapling.nvim - Interactive Smartlog for Sapling
return {
	"imdominicreed/nvim-sapling",
	version = "*", -- latest tagged release; use branch = "main" to track tip
	main = "sapling",
	cmd = "Sapling",
	keys = {
		{ "<leader>s", "<cmd>Sapling toggle<cr>", desc = "Sapling smartlog" },
		-- Alternative that does not collide with the <leader>s search group.
		{ "<leader>gl", "<cmd>Sapling toggle<cr>", desc = "Sapling smartlog" },
	},
	opts = {},
}
