-- Diffview - Git diff viewer (Sapling support via lua/vcs/sapling.lua)

-- Diff the whole stack: every draft commit on top of the last public ancestor,
-- plus whatever is still uncommitted.
--
-- The revset is resolved to a concrete hash here rather than handed to
-- DiffviewOpen: `is_rev_arg_range` treats any `:` as a range separator, so a
-- revset containing `::` would be misparsed. A single rev makes diffview diff
-- it against the working copy, which is exactly the stack.
local function diff_stack()
	local function sl(args)
		local out = vim.fn.system(vim.list_extend({ "sl", "--pager", "never" }, args))
		if vim.v.shell_error ~= 0 then return nil end
		return vim.trim(out)
	end

	local dotdir = sl({ "root", "--dotdir" })
	if not dotdir or dotdir:sub(-4) ~= "/.sl" then
		-- Not a Sapling repo: the git spelling of the same question.
		vim.cmd("DiffviewOpen origin/main...HEAD")
		return
	end

	-- The most recent public ancestor is the base the stack sits on. With no
	-- draft commits this is `.` itself, leaving just the uncommitted changes.
	local base = sl({ "log", "--rev=max(public() & ::.)", "--template={node}" })
	if not base or base == "" then
		vim.notify("Could not resolve the base of the stack", vim.log.levels.ERROR)
		return
	end

	vim.cmd("DiffviewOpen " .. base)
end

return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", diff_stack, desc = "Diff stack" },
		{ "<leader>gD", "<cmd>DiffviewOpen<cr>", desc = "Diff uncommitted changes" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history" },
		-- <leader>gq lives in core/keymaps.lua: it closes any diff view, not
		-- just this plugin's.
	},
	config = function(_, opts)
		require("diffview").setup(opts)
		require("vcs.sapling").register()
	end,
	opts = {
		keymaps = {
			diff3 = {
				{ "n", "n", function() require("diffview.actions").next_conflict() end, { desc = "Next conflict" } },
				{ "n", "b", function() require("diffview.actions").prev_conflict() end, { desc = "Back conflict" } },
			},
			view = {
				{ "n", "n", "]c", { desc = "Next hunk" } },
				{ "n", "b", "[c", { desc = "Back hunk" } },
				-- Diffview only binds `q` in its popups, so the tab it opens has
				-- no obvious way out. Match the smartlog and every other panel.
				{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
			},
			file_panel = {
				{ "n", "n", function() require("diffview.actions").next_entry() end, { desc = "Next file" } },
				{ "n", "b", function() require("diffview.actions").prev_entry() end, { desc = "Back file" } },
				{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
			},
		},
		view = {
			merge_tool = {
				layout = "diff3_mixed",
			},
		},
	},
}
