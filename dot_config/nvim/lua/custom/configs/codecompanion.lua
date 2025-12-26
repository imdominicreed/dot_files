
-- Key mappings for CodeCompanion
vim.api.nvim_set_keymap('n', '<Leader>ccc', ':CodeCompanion<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>cct', ':CodeCompanion generate_tests<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<Leader>ccr', ':CodeCompanion review<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>cca', ':CodeCompanionActions<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<Leader>cca', ':CodeCompanionActions<CR>', { noremap = true, silent = true })



vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { fg="#FFFFFF", bg = "#bb9af7", bold = true })  -- Soft purple for headers


local prompt_dir = vim.fn.expand("~/.config/nvim/prompts/")
local prompt_library = {}
local handle = io.popen('ls -1 "' .. prompt_dir .. '" | grep ".md$"')
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
						opts = {
						},
          },
        }
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
				---The header name for the LLM's messages
				---@type string|fun(adapter: CodeCompanion.Adapter): string
				llm = function(adapter)
					return "CodeCompanion (" .. adapter.formatted_name .. ")"
				end,

				---The header name for your messages
				---@type string
				user = "Me",
			},
			-- Change the default icons
			icons = {
				buffer_pin = " ",
				buffer_watch = "👀 ",
			},

			-- Alter the sizing of the debug window
			debug_window = {
				---@return number|fun(): number
				width = vim.o.columns - 5,
				---@return number|fun(): number
				height = vim.o.lines - 2,
			},

			-- Options to customize the UI of the chat buffer
			window = {
				layout = "vertical", -- float|vertical|horizontal|buffer
				position = nil,  -- left|right|top|bottom (nil will default depending on vim.opt.splitright|vim.opt.splitbelow)
				border = "single",
				height = 0.8,
				width = 0.45,
				relative = "editor",
				full_height = true, -- when set to false, vsplit will be used to open the chat buffer vs. botright/topleft vsplit
				sticky = false, -- when set to true and `layout` is not `"buffer"`, the chat buffer will remain opened when switching tabs
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
			---Customize how tokens are displayed
			---@param tokens number
			---@param adapter CodeCompanion.Adapter
			---@return string
			token_count = function(tokens, adapter)
				return " (" .. tokens .. " tokens)"
			end,
		}
	}
})

vim.cmd([[cab cc CodeCompanion]])

local spinner = {
  completed = "󰗡 Completed",
  error = " Error",
  cancelled = "󰜺 Cancelled",
}

---Format the adapter name and model for display with the spinner
---@param adapter CodeCompanion.Adapter
---@return string
local function format_adapter(adapter)
  local parts = {}
  table.insert(parts, adapter.formatted_name)
  if adapter.model and adapter.model ~= "" then
    table.insert(parts, "(" .. adapter.model .. ")")
  end
  return table.concat(parts, " ")
end
---Setup the spinner for CodeCompanion
---@return nil
local function codecompanion_spinner()
  local ok, progress = pcall(require, "fidget.progress")
  if not ok then
    return
  end

  spinner.handles = {}

	local group = vim.api.nvim_create_augroup("dotfiles.codecompanion.spinner", {})


  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionRequestStarted",
    group = group,
    callback = function(args)
      local handle = progress.handle.create({
        title = "",
        message = "  Sending...",
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

codecompanion_spinner()

-- Inline loading indicator for chat buffer
local function show_inline_loading(bufnr, line)
  local ns = vim.api.nvim_create_namespace("codecompanion_loading")
  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
    virt_text = { { "⏳ Loading...", "Comment" } },
    virt_text_pos = "eol",
  })
  vim.defer_fn(function()
    vim.api.nvim_buf_del_extmark(bufnr, ns, id)
  end, 1000)
end

vim.api.nvim_create_autocmd("User", {
  pattern = "CodeCompanionRequestStarted",
  callback = function(args)
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
    show_inline_loading(bufnr, line)
  end,
})

