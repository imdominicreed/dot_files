-- Mason - LSP/DAP/Linter/Formatter installer
return {
	{
		"williamboman/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
		opts = {
			ensure_installed = {
				-- LSP
				"lua-language-server",
				"gopls",
				"rust-analyzer",
				-- Formatters
				"gofumpt",
				"goimports-reviser",
				"golines",
				"stylua",
			},
			ui = {
				icons = {
					package_pending = " ",
					package_installed = "󰄳 ",
					package_uninstalled = " 󰚌",
				},
			},
			max_concurrent_installers = 10,
		},
		config = function(_, opts)
			require("mason").setup(opts)

			-- Custom command to install all
			vim.api.nvim_create_user_command("MasonInstallAll", function()
				if opts.ensure_installed and #opts.ensure_installed > 0 then
					vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
				end
			end, {})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		lazy = true,
		opts = {},
	},
}
