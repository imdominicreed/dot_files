-- jj.nvim - the interactive log, status and rebase UI for Jujutsu
--
-- This is the jj counterpart to nvim-sapling: a log buffer you drive with
-- single keys (`<CR>` edit, `d` describe, `<S-d>` diff, `n` new, `s` squash,
-- `r` rebase, `a` abandon, `b` bookmark, `p` push, `o` open PR).
--
-- `<leader>s` and `<leader>gl` reach it through the dispatcher in
-- core/keymaps.lua rather than a lazy `keys` entry here, because those two keys
-- have to pick between this plugin and nvim-sapling at press time.
return {
	"NicolasGB/jj.nvim",
	version = "*",
	cmd = {
		"J",
		"Jbrowse",
		"Jdiff",
		"Jhdiff",
		"Jvdiff",
		"Jread",
		"Jedit",
		"Jtabedit",
		"Jsplit",
		"Jvsplit",
	},
	keys = {
		{ "<leader>gj", "<cmd>J st<cr>", desc = "jj status" },
	},
	opts = {
		diff = {
			-- Registered in `config` below: diffview where it works, jj's own
			-- diff where it does not.
			backend = "auto",
		},
		-- No destructive-action guard is configured because jj does not need
		-- one: `a` (abandon) and friends are all undone by `<S-u>` in the same
		-- buffer, which runs `jj undo` against the operation log.
	},
	config = function(_, opts)
		local diff = require("jj.diff")

		-- jj.nvim's diffview backend hands raw jj commit ids to `DiffviewOpen`,
		-- which needs a git repo that can resolve them. A colocated repo has
		-- one; a non-colocated repo keeps its git store hidden inside `.jj`,
		-- where diffview only reaches it through the adapter in vcs/jj.lua -
		-- and that adapter deliberately does not do working-copy-vs-index
		-- views, because jj has no index to compare against.
		--
		-- So rather than pinning one backend for every repo, pick per call.
		local function pick_backend()
			local detect = require("vcs.detect")
			local root = detect.jj_root(vim.fn.getcwd())
			if root and detect.jj_colocated(root) then
				return "diffview"
			end
			return "native"
		end

		---Delegate to a real backend, chosen when the key is actually pressed.
		---@param method string
		local function delegate(method)
			return function(o)
				diff[method](vim.tbl_extend("force", o or {}, { backend = pick_backend() }))
			end
		end

		diff.register_backend("auto", {
			diff_current = delegate("diff_current"),
			show_revision = delegate("show_revision"),
			diff_revisions = delegate("diff_revisions"),
			diff_history_revisions = delegate("diff_history_revisions"),
		})

		require("jj").setup(opts)
	end,
}
