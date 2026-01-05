-- LSP Configuration
return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason.nvim",
		"williamboman/mason-lspconfig.nvim",
	},
	config = function()
		local lspconfig = require("lspconfig")

		-- Diagnostic config
		vim.diagnostic.config({
			virtual_text = { prefix = "●" },
			signs = true,
			underline = true,
			update_in_insert = false,
			severity_sort = true,
			float = { border = "rounded" },
		})

		-- LSP keymaps
		local on_attach = function(client, bufnr)
			local map = function(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
			end

			map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
			map("n", "gd", vim.lsp.buf.definition, "Go to definition")
			map("n", "K", vim.lsp.buf.hover, "Hover")
			map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
			map("n", "<leader>ls", vim.lsp.buf.signature_help, "Signature help")
			map("n", "<leader>D", vim.lsp.buf.type_definition, "Type definition")
			map("n", "<leader>ra", vim.lsp.buf.rename, "Rename")
			map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
			map("n", "gr", vim.lsp.buf.references, "References")
			map("n", "<leader>lf", function()
				vim.diagnostic.open_float({ border = "rounded" })
			end, "Floating diagnostic")
			map("n", "[d", function()
				vim.diagnostic.goto_prev({ float = { border = "rounded" } })
			end, "Previous diagnostic")
			map("n", "]d", function()
				vim.diagnostic.goto_next({ float = { border = "rounded" } })
			end, "Next diagnostic")
			map("n", "<leader>q", vim.diagnostic.setloclist, "Diagnostic loclist")
			map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
			map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
			map("n", "<leader>wl", function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, "List workspace folders")
		end

		-- Capabilities
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities.textDocument.completion.completionItem = {
			documentationFormat = { "markdown", "plaintext" },
			snippetSupport = true,
			preselectSupport = true,
			insertReplaceSupport = true,
			labelDetailsSupport = true,
			deprecatedSupport = true,
			commitCharactersSupport = true,
			tagSupport = { valueSet = { 1 } },
			resolveSupport = {
				properties = {
					"documentation",
					"detail",
					"additionalTextEdits",
				},
			},
		}

		-- Server configurations
		local servers = {
			lua_ls = {
				settings = {
					Lua = {
						codeLens = { enable = true },
						hint = { enable = true, semicolon = "Disable" },
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							library = {
								vim.fn.expand("$VIMRUNTIME/lua"),
								vim.fn.expand("$VIMRUNTIME/lua/vim/lsp"),
								vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
							},
							maxPreload = 100000,
							preloadFileSize = 10000,
						},
					},
				},
			},
			gopls = {
				settings = {
					gopls = {
						buildFlags = { "--tags=cukes,awscliit" },
						verboseOutput = true,
						completeUnimported = true,
						gofumpt = true,
						analyses = {
							unusedparams = true,
						},
					},
				},
			},
		}

		-- Setup servers
		for server, config in pairs(servers) do
			config.on_attach = on_attach
			config.capabilities = capabilities
			lspconfig[server].setup(config)
		end
	end,
}
