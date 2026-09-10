-- A Jujutsu (`jj`) VCS adapter for diffview.nvim, for non-colocated repos only.
--
-- jj stores every change as an ordinary git commit, so almost nothing about
-- reading a jj repo is jj-specific - the only question is where the git
-- objects live. A colocated repo (jj's default) keeps them in a top-level
-- `.git`, which diffview's own GitAdapter finds unaided; that case never
-- reaches this file. A non-colocated repo hides them in `.jj/repo/store/git`,
-- and git tooling can read that perfectly well once pointed at it.
--
-- So this subclasses GitAdapter and overrides three things: how the repo is
-- found (`jj root`), where its git directory is (`store/git_target`), and the
-- `--git-dir`/`--work-tree` pair that redirects every git call there.
--
-- Deliberately not supported: views with the working copy on one side. Those
-- read the git index, and a non-colocated repo has none - jj keeps its own
-- working-copy state and never writes one. `@` is a real commit that already
-- holds whatever is on disk, so diffing `@-..@` says the same thing; that is
-- what the <leader>gd / <leader>gD maps do in these repos.
--
-- diffview hardcodes its adapter list in `vcs.get_adapter`, so `M.register()`
-- wraps that function rather than editing the plugin: jj is tried only after
-- the built-in adapters decline.
local M = {}

M.cmd = { "jj" }

---Adapter class, built lazily so requiring this module does not force diffview
---to load.
local function build()
	local oop = require("diffview.oop")
	local utils = require("diffview.utils")
	local config = require("diffview.config")
	local GitAdapter = require("diffview.vcs.adapters.git").GitAdapter
	local GitRev = require("diffview.vcs.adapters.git.rev").GitRev
	local RevType = require("diffview.vcs.rev").RevType
	local detect = require("vcs.detect")
	local pl = utils.path

	---@class JJAdapter : GitAdapter
	local JJAdapter = oop.create_class("JJAdapter", GitAdapter)

	JJAdapter.Rev = GitAdapter.Rev
	JJAdapter.config_key = "jj"
	-- Must be its own table: sharing GitAdapter's would cross-contaminate the
	-- bootstrap results of the two adapters.
	JJAdapter.bootstrap = {
		done = false,
		ok = false,
		version = {},
		target_version = { major = 2, minor = 31, patch = 0 },
	}

	function JJAdapter.run_bootstrap()
		local bs = JJAdapter.bootstrap
		bs.done = true

		if vim.fn.executable(M.cmd[1]) ~= 1 then
			bs.err = ("Configured jj command is not executable: '%s'"):format(M.cmd[1])
			DiffviewGlobal.logger:error("[JJAdapter] " .. bs.err)
			return
		end

		-- Everything this adapter runs is git, so git's own bootstrap is the
		-- one that has to pass. Borrow its verdict rather than re-deriving it.
		if not GitAdapter.bootstrap.done then GitAdapter.run_bootstrap() end

		local git_bs = GitAdapter.bootstrap
		bs.ok = git_bs.ok
		bs.err = git_bs.err
		bs.version = git_bs.version
		bs.version_string = git_bs.version_string
		bs.target_version = git_bs.target_version
	end

	---The root of the non-colocated jj repo containing `path`, or nil.
	---
	---Colocated repos are filtered out here rather than at registration time:
	---they are strictly better served by GitAdapter, which gets a real index
	---and so can diff against the working copy.
	local function jj_toplevel(path)
		local root = detect.jj_root(path)
		if not root or detect.jj_colocated(root) then return nil end
		return detect.jj_git_dir(root) and root or nil
	end

	function JJAdapter.find_toplevel(top_indicators)
		for _, p in ipairs(top_indicators) do
			if not pl:is_dir(p) then p = pl:parent(p) end

			if p and pl:readable(p) then
				local root = jj_toplevel(p)
				if root then return nil, root end
			end
		end

		local msg_paths = vim.tbl_map(function(v)
			local rel = pl:relative(v, ".")
			return utils.str_quote(rel == "" and "." or rel)
		end, top_indicators)

		return ("Path not a non-colocated jj repo (or any parent): %s")
			:format(table.concat(msg_paths, ", ")), ""
	end

	-- GitAdapter.create hardcodes its own class, so it cannot be inherited.
	function JJAdapter.create(toplevel, path_args, cpath)
		local adapter = JJAdapter({
			toplevel = toplevel,
			path_args = path_args,
			cpath = cpath,
		})

		local err
		if not adapter.ctx.toplevel then
			err = "Could not find the top-level of the repository!"
		elseif not pl:is_dir(adapter.ctx.toplevel) then
			err = "The top-level is not a readable directory: " .. adapter.ctx.toplevel
		elseif not adapter.ctx.dir then
			err = "Could not find the git store inside .jj!"
		end

		return err, adapter
	end

	-- GitAdapter asks git where its directory is; here git has to be told.
	function JJAdapter:get_dir(path)
		local root = detect.jj_root(path)
		return root and detect.jj_git_dir(root) or nil
	end

	-- The whole adapter, really: run ordinary git, against jj's object store
	-- and this working tree.
	--
	-- `get_dir` is called from `init` before `ctx` exists, so the unredirected
	-- form has to be a valid answer too.
	function JJAdapter:get_command()
		local git_cmd = config.get_config().git_cmd
		if not (self.ctx and self.ctx.dir) then return git_cmd end

		return utils.vec_join(
			git_cmd,
			"--git-dir=" .. self.ctx.dir,
			"--work-tree=" .. self.ctx.toplevel
		)
	end

	-- The `.git/MERGE_HEAD` family that GitAdapter probes for does not exist in
	-- jj's store: jj records conflicts inside the commit itself. Reporting "no
	-- merge in progress" costs the three-way layout during conflict resolution
	-- and keeps everything else working.
	function JJAdapter:get_merge_context()
		return { ours = {}, theirs = {}, base = {} }
	end

	-- A non-colocated store has no usable `HEAD`: jj keeps every commit under
	-- `refs/jj/keep/*` and leaves `HEAD` pointing at a branch it never created,
	-- so `git rev-parse HEAD` fails outright. The working-copy commit is what
	-- HEAD would have meant.
	function JJAdapter:head_rev()
		local id = detect.jj_rev(self.ctx.toplevel, "@")
		return id and GitRev(RevType.COMMIT, id, true) or nil
	end

	-- `git log` with no revision also means HEAD, so file history has to be
	-- given a starting point explicitly. Anything the user asked for wins; this
	-- only fills in the default.
	local git_prepare_fh_options = GitAdapter.prepare_fh_options

	function JJAdapter:prepare_fh_options(log_options, single_file)
		local opts = git_prepare_fh_options(self, log_options, single_file)

		if not opts.rev_range then
			local head = self:head_rev()
			opts.rev_range = head and head.commit or nil
		end

		return opts
	end

	-- The dry run asks git whether there is any history worth opening a panel
	-- for, but builds that probe from the *unprepared* options - so it asks
	-- about HEAD and comes back empty every time here, before the walk above
	-- ever runs. The walk reports an empty history on its own.
	function JJAdapter:file_history_dry_run()
		return true, ""
	end

	return JJAdapter
end

---Teach diffview about non-colocated jj repos. Safe to call more than once.
function M.register()
	if M._registered then return end
	M._registered = true

	-- Several lookups are keyed on `config_key`, so "jj" needs entries of its
	-- own or file history indexes nil. Everything this adapter runs is git, so
	-- git's defaults are exactly right - and `file_history_panel.log_options.jj`
	-- can now be overridden independently.
	local config = require("diffview.config")
	config.log_option_defaults.jj = vim.deepcopy(config.log_option_defaults.git)

	local log_options = config.get_config().file_history_panel.log_options
	log_options.jj = log_options.jj or vim.deepcopy(log_options.git)

	local vcs = require("diffview.vcs")
	local JJAdapter = build()
	local get_adapter = vcs.get_adapter

	---@diagnostic disable-next-line: duplicate-set-field
	vcs.get_adapter = function(opt)
		-- Let the built-in adapters answer first: a colocated jj repo is a
		-- perfectly good git repo and belongs to GitAdapter.
		local err, adapter = get_adapter(opt)
		if not err then return err, adapter end

		if not JJAdapter.bootstrap.done then JJAdapter.run_bootstrap() end
		if not JJAdapter.bootstrap.ok then return err end

		opt.cmd_ctx = opt.cmd_ctx or {}

		local top_indicators, path_args = opt.top_indicators, opt.cmd_ctx.path_args
		if not top_indicators then
			path_args, top_indicators =
				JJAdapter.get_repo_paths(opt.cmd_ctx.path_args, opt.cmd_ctx.cpath)
		end

		local jj_err, toplevel = JJAdapter.find_toplevel(top_indicators)
		if jj_err then return err end

		return JJAdapter.create(toplevel, path_args, opt.cmd_ctx.cpath)
	end
end

return M
