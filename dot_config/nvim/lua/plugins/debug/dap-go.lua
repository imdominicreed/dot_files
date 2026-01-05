-- DAP Go - Go debugging
return {
	"dreamsofcode-io/nvim-dap-go",
	ft = "go",
	dependencies = "mfussenegger/nvim-dap",
	keys = {
		{
			"<leader>dgt",
			function()
				require("dap-go").debug_test()
			end,
			desc = "Debug Go test",
		},
		{
			"<leader>dgl",
			function()
				require("dap-go").debug_last()
			end,
			desc = "Debug last Go test",
		},
	},
	config = function()
		require("dap-go").setup()
	end,
}
