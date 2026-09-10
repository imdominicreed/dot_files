-- Diffview - diff viewer
--
-- Sapling support comes from lua/vcs/sapling.lua, jj support from
-- lua/vcs/jj.lua. Colocated jj repos - jj's default - need neither: they are
-- real git repos and diffview's own GitAdapter handles them.

---The directory the current buffer lives in, falling back to the cwd for
---buffers that have no file of their own.
local function buf_dir()
	local name = vim.api.nvim_buf_get_name(0)
	return name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
end

---Spell "from `base_revset` to the working copy" the way this jj repo can
---answer it, or nil if the revset names no commit.
---
---A colocated repo gets the single-rev form, whose right side is the live
---working tree, so diffview lets you edit files straight out of the diff. A
---non-colocated repo has no git index for that to work against (see
---lua/vcs/jj.lua), but it does not need one: `@` is a real commit that already
---holds whatever is on disk, so the two-rev form says the same thing.
---
---Either way the revset is resolved to a hash first, because diffview's
---`is_rev_arg_range` treats any `:` as a range separator and would misparse a
---revset containing `::`.
local function jj_range(root, base_revset)
	local detect = require("vcs.detect")

	local base = detect.jj_rev(root, base_revset)
	if not base then return nil end

	-- Every jj history bottoms out at a virtual root commit with the null id
	-- and no git object behind it, and a stack with nothing immutable above it
	-- resolves to exactly that. Git's empty tree means the same thing here -
	-- everything below is new - and unlike the null id it is a real object.
	if base:match("^0+$") then
		base = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
	end

	if detect.jj_colocated(root) then return base end

	local head = detect.jj_rev(root, "@")
	return head and (base .. ".." .. head) or nil
end

---Run a git command in `dir`, returning its trimmed first line, or nil.
local function git(dir, args)
	if vim.fn.executable("git") ~= 1 then return nil end

	local res = vim.system(
		vim.list_extend({ "git", "-C", dir }, args),
		{ text = true }
	):wait(3000)
	if res.code ~= 0 then return nil end

	local out = vim.trim((res.stdout or ""):gsub("\n.*", ""))
	return out ~= "" and out or nil
end

---What this git repo considers the base of the current branch.
---
---Asked rather than assumed: `origin/main` is not universal, and when the guess
---is wrong diffview reports only "Not a repo (or any parent), or no supported
---VCS adapter!" — which sends you looking for a broken repo instead of a
---misnamed branch.
local function git_base(dir)
	-- What this branch actually tracks is the best answer when it exists.
	local upstream = git(dir, { "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}" })
	if upstream then return upstream end

	-- Failing that, the remote's own idea of its default branch.
	local origin_head = git(dir, { "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
	if origin_head then return origin_head end

	for _, guess in ipairs({ "origin/main", "origin/master", "main", "master" }) do
		if git(dir, { "rev-parse", "--verify", "--quiet", guess }) then return guess end
	end

	return nil
end

---The git spelling of `diff_stack`.
local function git_stack(dir)
	if not git(dir, { "rev-parse", "--git-dir" }) then
		vim.notify("Not in a jj, Sapling or git repo", vim.log.levels.WARN)
		return
	end

	local base = git_base(dir)
	if not base then
		-- A repo with no upstream and no main/master has no stack to speak of,
		-- so show the uncommitted changes rather than erroring.
		vim.notify("No base branch found; showing uncommitted changes", vim.log.levels.INFO)
		vim.cmd("DiffviewOpen")
		return
	end

	vim.cmd("DiffviewOpen " .. base .. "...HEAD")
end

---Diff the whole stack: every draft commit on top of the last public ancestor,
---plus whatever is not yet part of a finished commit.
local function diff_stack()
	local detect = require("vcs.detect")
	local dir = buf_dir()

	local jj_root = detect.jj_root(dir)
	if jj_root then
		-- `~mutable()` is jj's spelling of Sapling's `public()`: the commits
		-- this repo considers finished. The most recent such ancestor is what
		-- the stack sits on, and with nothing drafted it is `@-` itself.
		local range = jj_range(jj_root, "latest(::@ & ~mutable())")
		if not range then
			vim.notify("Could not resolve the base of the stack", vim.log.levels.ERROR)
			return
		end

		return vim.cmd("DiffviewOpen " .. range)
	end

	local sl_root = detect.sapling_root(dir)
	if sl_root then
		-- Resolved to a hash for the same reason as the jj branch above.
		local out = vim.fn.system({
			"sl", "--pager", "never", "--cwd", sl_root,
			"log", "--rev=max(public() & ::.)", "--template={node}",
		})
		local base = vim.v.shell_error == 0 and vim.trim(out) or ""
		if base == "" then
			vim.notify("Could not resolve the base of the stack", vim.log.levels.ERROR)
			return
		end

		return vim.cmd("DiffviewOpen " .. base)
	end

	-- Plain git: the same question, in the only spelling git has for it.
	git_stack(dir)
end

---Diff only what is not yet part of a finished commit.
local function diff_uncommitted()
	local jj_root = require("vcs.detect").jj_root(buf_dir())

	if jj_root then
		-- jj has no uncommitted state: the working copy *is* `@`, snapshotted
		-- on every command. So "uncommitted changes" is `@` against its parent.
		local range = jj_range(jj_root, "@-")
		if not range then
			vim.notify("Could not resolve the working-copy parent", vim.log.levels.ERROR)
			return
		end

		return vim.cmd("DiffviewOpen " .. range)
	end

	vim.cmd("DiffviewOpen")
end

return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", diff_stack, desc = "Diff stack" },
		{ "<leader>gD", diff_uncommitted, desc = "Diff uncommitted changes" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history" },
		-- <leader>gq lives in core/keymaps.lua: it closes any diff view, not
		-- just this plugin's.
	},
	config = function(_, opts)
		require("diffview").setup(opts)
		require("vcs.sapling").register()
		require("vcs.jj").register()
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
