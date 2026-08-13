-- Gitsigns - Git integration
return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		attach_to_untracked = false,
		signs = {
			add = { text = "│" },
			change = { text = "│" },
			delete = { text = "󰍵" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "│" },
		},
		on_attach = function(bufnr)
			-- Skip pseudo-buffers. Replaces the removed `on_attach_pre` option;
			-- on_attach returning false prevents attach.
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name:match("^diffview://") or name:match("^fugitive://") then
				return false
			end

			local gs = package.loaded.gitsigns

			local function map(mode, l, r, desc)
				vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
			end

			-- Navigation
			map("n", "]c", function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(function()
					gs.next_hunk()
				end)
				return "<Ignore>"
			end, "Next hunk")

			map("n", "[c", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gs.prev_hunk()
				end)
				return "<Ignore>"
			end, "Previous hunk")

			-- Actions
			map("n", "<leader>rh", gs.reset_hunk, "Reset hunk")
			map("n", "<leader>ph", gs.preview_hunk, "Preview hunk")
			map("n", "<leader>gb", function()
				gs.blame_line({ full = true })
			end, "Blame line")
			map("n", "<leader>td", gs.toggle_deleted, "Toggle deleted")
		end,
	},
}
