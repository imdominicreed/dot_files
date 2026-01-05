-- CodeCompanion - AI chat
return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	lazy = false,
	keys = {
		{ "<leader>ccc", "<cmd>CodeCompanion<cr>", desc = "CodeCompanion" },
		{ "<leader>cct", "<cmd>CodeCompanion generate_tests<cr>", desc = "Generate tests" },
		{ "<leader>ccr", "<cmd>CodeCompanion review<cr>", mode = "v", desc = "Code review" },
		{ "<leader>cca", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion actions" },
		{ "<leader>cca", "<cmd>CodeCompanionActions<cr>", mode = "v", desc = "CodeCompanion actions" },
	},
	config = function()
		-- Custom highlight for markdown headers
		vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { fg = "#FFFFFF", bg = "#bb9af7", bold = true })

		-- Load custom prompts from prompts directory
		local prompt_dir = vim.fn.expand("~/.config/nvim/prompts/")
		local prompt_library = {}
		local handle = io.popen('ls -1 "' .. prompt_dir .. '" 2>/dev/null | grep ".md$"')
		if handle then
			for filename in handle:lines() do
				local f = io.open(prompt_dir .. "/" .. filename, "r")
				if f then
					local name = filename:gsub("%.md$", "")
					prompt_library[name] = {
						strategy = "chat",
						description = "Loaded from " .. filename,
						opts = {},
						prompts = {
							{
								role = "system",
								content = f:read("*all"),
								opts = {},
							},
						},
					}
					f:close()
				end
			end
			handle:close()
		end

		require("codecompanion").setup({
			ignore_warnings = true,
			prompt_library = prompt_library,
			strategies = {
				chat = {
					name = "copilot",
					model = "gpt-4.1",
				},
				inline = {
					adapter = "copilot",
				},
			},
			display = {
				chat = {
					tool_processing = {
						message = "Loading...",
						spinner = true,
					},
					roles = {
						llm = function(adapter)
							return "CodeCompanion (" .. adapter.formatted_name .. ")"
						end,
						user = "Me",
					},
					icons = {
						buffer_pin = " ",
						buffer_watch = "👀 ",
					},
					debug_window = {
						width = vim.o.columns - 5,
						height = vim.o.lines - 2,
					},
					window = {
						layout = "vertical",
						position = nil,
						border = "single",
						height = 0.8,
						width = 0.45,
						relative = "editor",
						full_height = true,
						sticky = false,
						opts = {
							breakindent = true,
							cursorcolumn = false,
							cursorline = false,
							foldcolumn = "0",
							linebreak = true,
							list = false,
							numberwidth = 1,
							signcolumn = "no",
							spell = false,
							wrap = true,
						},
					},
					token_count = function(tokens, adapter)
						return " (" .. tokens .. " tokens)"
					end,
				},
			},
		})

		-- Command abbreviation
		vim.cmd([[cab cc CodeCompanion]])

		-- Fidget spinner integration
		local spinner = {
			completed = "󰗡 Completed",
			error = " Error",
			cancelled = "󰜺 Cancelled",
			handles = {},
		}

		local function format_adapter(adapter)
			local parts = {}
			table.insert(parts, adapter.formatted_name)
			if adapter.model and adapter.model ~= "" then
				table.insert(parts, "(" .. adapter.model .. ")")
			end
			return table.concat(parts, " ")
		end

		local ok, progress = pcall(require, "fidget.progress")
		if ok then
			local group = vim.api.nvim_create_augroup("codecompanion.spinner", {})

			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeCompanionRequestStarted",
				group = group,
				callback = function(args)
					local handle = progress.handle.create({
						title = "",
						message = "  Sending...",
						lsp_client = {
							name = format_adapter(args.data.adapter),
						},
						window = {
							align = "cursor",
						},
					})
					spinner.handles[args.data.id] = handle
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeCompanionRequestFinished",
				group = group,
				callback = function(args)
					local handle = spinner.handles[args.data.id]
					spinner.handles[args.data.id] = nil
					if handle then
						if args.data.status == "success" then
							handle.message = spinner.completed
						elseif args.data.status == "error" then
							handle.message = spinner.error
						else
							handle.message = spinner.cancelled
						end
						handle:finish()
					end
				end,
			})
		end

		-- Inline loading indicator
		vim.api.nvim_create_autocmd("User", {
			pattern = "CodeCompanionRequestStarted",
			callback = function()
				local ns = vim.api.nvim_create_namespace("codecompanion_loading")
				local bufnr = vim.api.nvim_get_current_buf()
				local line = vim.api.nvim_win_get_cursor(0)[1] - 1
				local id = vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
					virt_text = { { "⏳ Loading...", "Comment" } },
					virt_text_pos = "eol",
				})
				vim.defer_fn(function()
					pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, id)
				end, 1000)
			end,
		})
	end,
}
