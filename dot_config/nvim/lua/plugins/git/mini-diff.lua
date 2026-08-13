-- mini.diff - gutter signs for Sapling repos
--
-- gitsigns is hard-wired to `git` and never attaches inside a Sapling repo.
-- mini.diff takes a pluggable source, so we back it with `sl cat -r .` to get
-- the committed version of each file. The source refuses to attach outside a
-- Sapling repo, which leaves git repos to gitsigns and avoids double signs.
return {
	"echasnovski/mini.diff",
	version = "*",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local roots = {}

		-- `sl root` per directory, memoised: it runs on every buffer attach.
		--
		-- Sapling speaks git natively, so `sl root` also succeeds inside plain
		-- git repos. The dotdir is what separates them: a native Sapling repo
		-- reports `<root>/.sl`, a git-backed one `<root>/.git/sl`. Only the
		-- former is ours; the rest stays with gitsigns.
		local function sapling_root(dir)
			if roots[dir] == nil then
				local res = vim.system(
					{ "sl", "--pager", "never", "root", "--dotdir" },
					{ cwd = dir, text = true }
				):wait(3000)
				local dotdir = res.code == 0 and vim.trim(res.stdout) or ""
				roots[dir] = dotdir:sub(-4) == "/.sl" and dotdir:sub(1, -5) or false
			end
			return roots[dir]
		end

		local function set_ref(buf_id)
			if not vim.api.nvim_buf_is_valid(buf_id) then
				return
			end
			local path = vim.api.nvim_buf_get_name(buf_id)
			local root = sapling_root(vim.fs.dirname(path))
			if not root then
				return
			end

			vim.system(
				{ "sl", "--pager", "never", "--color", "never", "cat", "-r", ".", path },
				{ cwd = root, text = true },
				function(res)
					vim.schedule(function()
						if not vim.api.nvim_buf_is_valid(buf_id) then
							return
						end
						-- A failed `cat` means the file is untracked. An empty
						-- table clears the diff, matching what mini.diff's own
						-- Git source does: a `""` reference would be treated as
						-- a single blank line and mis-render the first hunk.
						local text = res.code == 0 and res.stdout or {}
						pcall(MiniDiff.set_ref_text, buf_id, text)
					end)
				end
			)
		end

		local function map(buf_id, mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = buf_id, desc = desc })
		end

		local source = {
			name = "sapling",

			attach = function(buf_id)
				local path = vim.api.nvim_buf_get_name(buf_id)
				if path == "" or vim.fn.filereadable(path) == 0 then
					return false
				end
				if not sapling_root(vim.fs.dirname(path)) then
					return false
				end

				-- The reference only moves when the repo does (commit, amend,
				-- goto), so refresh on the events that follow those.
				local group = vim.api.nvim_create_augroup("MiniDiffSapling" .. buf_id, { clear = true })
				vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained" }, {
					group = group,
					buffer = buf_id,
					callback = function()
						set_ref(buf_id)
					end,
				})

				-- Parity with the gitsigns maps, which never fire here.
				map(buf_id, "n", "]c", function()
					MiniDiff.goto_hunk("next")
				end, "Next hunk")
				map(buf_id, "n", "[c", function()
					MiniDiff.goto_hunk("prev")
				end, "Previous hunk")
				map(buf_id, "n", "<leader>ph", function()
					MiniDiff.toggle_overlay(buf_id)
				end, "Preview hunks (overlay)")
				map(buf_id, "n", "<leader>rh", function()
					MiniDiff.do_hunks(buf_id, "reset")
				end, "Reset hunk")

				set_ref(buf_id)
			end,

			detach = function(buf_id)
				pcall(vim.api.nvim_del_augroup_by_name, "MiniDiffSapling" .. buf_id)
			end,

			-- Sapling has no staging index, so there is nothing to apply to.
			apply_hunks = function()
				vim.notify("Sapling has no index: staging hunks is not supported", vim.log.levels.WARN)
			end,
		}

		require("mini.diff").setup({
			source = source,
			view = {
				style = "sign",
				signs = { add = "│", change = "│", delete = "󰍵" },
			},
		})
	end,
}
