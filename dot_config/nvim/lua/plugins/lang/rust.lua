-- Rustaceanvim - Rust IDE features
return {
	"mrcjkb/rustaceanvim",
	version = "^6",
	lazy = false,
	ft = { "rust" },
	config = function()
		vim.g.rustaceanvim = {
			server = {
				-- Keymaps handled by global LspAttach autocmd in lspconfig.lua
				default_settings = {
					["rust-analyzer"] = {
						checkOnSave = {
							command = "clippy",
						},
					},
				},
			},
		}
	end,
}
