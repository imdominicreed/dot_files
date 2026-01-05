-- Fidget - LSP progress indicator
return {
	"j-hui/fidget.nvim",
	event = "LspAttach",
	opts = {
		notification = {
			window = {
				winblend = 0,
			},
		},
	},
}
