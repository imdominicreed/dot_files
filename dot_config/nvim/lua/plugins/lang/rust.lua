-- Rustaceanvim - Rust IDE features
return {
	"mrcjkb/rustaceanvim",
	version = "^6",
	lazy = false,
	ft = { "rust" },
	config = function()
		vim.g.rustaceanvim = {
			server = {
				on_attach = function(client, bufnr)
					local map = function(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
					end

					-- Rust-specific keymaps
					map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
					map("n", "gd", vim.lsp.buf.definition, "Go to definition")
					map("n", "K", vim.lsp.buf.hover, "Hover")
					map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
					map("n", "<leader>ra", vim.lsp.buf.rename, "Rename")
					map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
					map("n", "gr", vim.lsp.buf.references, "References")
				end,
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
