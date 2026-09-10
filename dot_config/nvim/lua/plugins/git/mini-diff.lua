-- mini.diff - gutter signs for the VCSs gitsigns will not touch
--
-- gitsigns is hard-wired to `git`, which leaves two gaps: a Sapling repo has no
-- `.git` at all, and a jj repo has one only when colocated - and even then the
-- signs it draws are a coincidence of how jj keeps the git index parked on
-- `@-`, which stops being true the moment a repo is not colocated.
--
-- mini.diff takes pluggable sources and tries them in order, so both get a
-- source of their own here: `jj file show -r @-` and `sl cat -r .` supply the
-- committed text, and each source refuses to attach outside its own kind of
-- repo. gitsigns keeps plain git repos to itself (see gitsigns.lua), so no
-- buffer ever ends up with two sets of signs.
return {
	"echasnovski/mini.diff",
	version = "*",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local detect = require("vcs.detect")

		---Build a mini.diff source from the two things that actually differ
		---between these VCSs: how you find the repo, and how you ask it for the
		---committed version of a file.
		---@param spec { name: string, root: fun(dir: string): string?, ref_cmd: fun(path: string): string[] }
		local function make_source(spec)
			local group_name = "MiniDiff" .. spec.name

			local function set_ref(buf_id)
				if not vim.api.nvim_buf_is_valid(buf_id) then return end

				local path = vim.api.nvim_buf_get_name(buf_id)
				local root = spec.root(vim.fs.dirname(path))
				if not root then return end

				vim.system(spec.ref_cmd(path), { cwd = root, text = true }, function(res)
					vim.schedule(function()
						if not vim.api.nvim_buf_is_valid(buf_id) then return end

						-- A failed read means the file does not exist in the
						-- reference revision, i.e. it is new. An empty table
						-- clears the diff, matching what mini.diff's own Git
						-- source does: a `""` reference would be read as a
						-- single blank line and mis-render the first hunk.
						local text = res.code == 0 and res.stdout or {}
						pcall(MiniDiff.set_ref_text, buf_id, text)
					end)
				end)
			end

			local function map(buf_id, lhs, rhs, desc)
				vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = desc })
			end

			return {
				name = spec.name,

				attach = function(buf_id)
					local path = vim.api.nvim_buf_get_name(buf_id)
					if path == "" or vim.fn.filereadable(path) == 0 then return false end
					if not spec.root(vim.fs.dirname(path)) then return false end

					-- The reference only moves when the repo does (commit,
					-- amend, new, edit), so refresh on the events that follow
					-- those rather than polling.
					local group = vim.api.nvim_create_augroup(group_name .. buf_id, { clear = true })
					vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained" }, {
						group = group,
						buffer = buf_id,
						callback = function() set_ref(buf_id) end,
					})

					-- Parity with the gitsigns maps, which never fire here.
					map(buf_id, "]c", function() MiniDiff.goto_hunk("next") end, "Next hunk")
					map(buf_id, "[c", function() MiniDiff.goto_hunk("prev") end, "Previous hunk")
					map(buf_id, "<leader>ph", function() MiniDiff.toggle_overlay(buf_id) end, "Preview hunks (overlay)")
					map(buf_id, "<leader>rh", function() MiniDiff.do_hunks(buf_id, "reset") end, "Reset hunk")

					set_ref(buf_id)
				end,

				detach = function(buf_id)
					pcall(vim.api.nvim_del_augroup_by_name, group_name .. buf_id)
				end,

				-- Neither VCS has a staging index, so there is nothing to apply
				-- hunks to.
				apply_hunks = function()
					vim.notify(
						spec.name .. " has no index: staging hunks is not supported",
						vim.log.levels.WARN
					)
				end,
			}
		end

		local jj_source = make_source({
			name = "jj",
			root = detect.jj_root,
			-- `@-` is the parent of the working-copy change, so this diff is
			-- "everything I have done since the last change I finished" - the
			-- same thing gitsigns shows against the index in a git repo.
			--
			-- `--ignore-working-copy` keeps drawing signs from snapshotting the
			-- working copy into `@` as a side effect.
			ref_cmd = function(path)
				return { "jj", "--no-pager", "file", "show", "--ignore-working-copy", "-r", "@-", path }
			end,
		})

		local sapling_source = make_source({
			name = "sapling",
			root = detect.sapling_root,
			ref_cmd = function(path)
				return { "sl", "--pager", "never", "--color", "never", "cat", "-r", ".", path }
			end,
		})

		require("mini.diff").setup({
			-- Tried in order; the first one whose `attach` does not return
			-- false wins. A repo is never both, so the order is arbitrary.
			source = { jj_source, sapling_source },
			view = {
				style = "sign",
				signs = { add = "│", change = "│", delete = "󰍵" },
			},
		})
	end,
}
