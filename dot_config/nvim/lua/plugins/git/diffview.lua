-- Diffview - Git diff viewer
return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen origin/main...HEAD<cr>", desc = "Diff against main" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history" },
		{ "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
	},
	opts = {
		keymaps = {
			diff3 = {
				{ "n", "n", function() require("diffview.actions").next_conflict() end, { desc = "Next conflict" } },
				{ "n", "b", function() require("diffview.actions").prev_conflict() end, { desc = "Back conflict" } },
			},
			view = {
				{ "n", "n", "]c", { desc = "Next hunk" } },
				{ "n", "b", "[c", { desc = "Back hunk" } },
			},
			file_panel = {
				{ "n", "n", function() require("diffview.actions").next_entry() end, { desc = "Next file" } },
				{ "n", "b", function() require("diffview.actions").prev_entry() end, { desc = "Back file" } },
			},
		},
		view = {
			merge_tool = {
				layout = "diff3_mixed",
			},
		},
	},
}
