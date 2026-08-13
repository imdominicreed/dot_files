-- A Sapling (`sl`) VCS adapter for diffview.nvim.
--
-- Sapling is a Mercurial fork and keeps most of its command surface, so this
-- subclasses diffview's HgAdapter and overrides only what actually diverges:
-- version detection, repo discovery, and the handful of hg-isms Sapling
-- dropped (named branches, revision numbers, `debugmergestate -Tjson`).
--
-- diffview hardcodes its adapter list in `vcs.get_adapter`, so `M.register()`
-- wraps that function rather than editing the plugin: Sapling is tried only
-- after the built-in adapters decline, which keeps git repos on GitAdapter.
local M = {}

M.cmd = { "sl" }

---Adapter class, built lazily so that requiring this module does not force
---diffview to load.
local function build()
  local oop = require("diffview.oop")
  local utils = require("diffview.utils")
  local async = require("diffview.async")
  local Job = require("diffview.job").Job
  local FileEntry = require("diffview.scene.file_entry").FileEntry
  local HgAdapter = require("diffview.vcs.adapters.hg").HgAdapter
  local RevType = require("diffview.vcs.rev").RevType
  local await = async.await
  local pl = utils.path

  ---@class SaplingAdapter : HgAdapter
  local SaplingAdapter = oop.create_class("SaplingAdapter", HgAdapter)

  SaplingAdapter.Rev = HgAdapter.Rev
  SaplingAdapter.config_key = "sapling"
  -- Must be its own table: sharing HgAdapter's would cross-contaminate the
  -- bootstrap results of the two adapters.
  SaplingAdapter.bootstrap = {
    done = false,
    ok = false,
    version = {},
    target_version = { major = 0, minor = 1, patch = 0 },
  }

  function SaplingAdapter.run_bootstrap()
    local bs = SaplingAdapter.bootstrap
    bs.done = true

    local function err(msg)
      bs.err = msg
      DiffviewGlobal.logger:error("[SaplingAdapter] " .. msg)
    end

    if vim.fn.executable(M.cmd[1]) ~= 1 then
      return err(("Configured Sapling command is not executable: '%s'"):format(M.cmd[1]))
    end

    -- `sl version` prints e.g. "Sapling 0.2.20260522-084851+1e764c94"
    local out = utils.job(utils.flatten({ M.cmd, "version" }))
    local version = out[1] and out[1]:match("^Sapling%s+(%S+)")
    if not version then
      return err("Could not get Sapling version!")
    end

    local major, minor, patch = version:match("(%d+)%.?(%d*)%.?(%d*)")
    if not major then
      return err(("Could not parse Sapling version: %s!"):format(version))
    end

    bs.version = {
      major = tonumber(major),
      minor = tonumber(minor) or 0,
      patch = tonumber(patch) or 0,
    }
    bs.version_string = version
    bs.ok = true
  end

  ---Resolve the Sapling dotdir for a path, or nil if it is not one of ours.
  ---
  ---Sapling speaks git natively, so plain `sl root` succeeds inside git repos
  ---too. The dotdir separates them: a native repo reports `<root>/.sl`, a
  ---git-backed one `<root>/.git/sl`. Only the former belongs to this adapter;
  ---the rest is left to GitAdapter, which handles it better.
  local function sapling_dotdir(path)
    local out, code = utils.job(utils.flatten({ M.cmd, { "root", "--dotdir" } }), path)
    if code ~= 0 then return nil end

    local dotdir = out[1] and vim.trim(out[1])
    if not dotdir or dotdir:sub(-4) ~= "/.sl" then return nil end

    return dotdir
  end

  function SaplingAdapter.find_toplevel(top_indicators)
    for _, p in ipairs(top_indicators) do
      if not pl:is_dir(p) then p = pl:parent(p) end

      if p and pl:readable(p) then
        local dotdir = sapling_dotdir(p)
        if dotdir then return nil, dotdir:sub(1, -5) end
      end
    end

    local msg_paths = vim.tbl_map(function(v)
      local rel = pl:relative(v, ".")
      return utils.str_quote(rel == "" and "." or rel)
    end, top_indicators)

    return ("Path not a Sapling repo (or any parent): %s"):format(table.concat(msg_paths, ", ")), ""
  end

  -- HgAdapter.create hardcodes its own class, so it cannot be inherited.
  function SaplingAdapter.create(toplevel, path_args, cpath)
    local adapter = SaplingAdapter({
      toplevel = toplevel,
      path_args = path_args,
      cpath = cpath,
    })

    local err
    if not adapter.ctx.toplevel then
      err = "Could not find top-level of the repository!"
    elseif not pl:is_dir(adapter.ctx.toplevel) then
      err = "The top-level is not a readable directory: " .. adapter.ctx.toplevel
    end

    return err, adapter
  end

  -- diffview's file-history template asks for `{p1.node}` and `{p2.rev}`.
  -- Sapling exposes those as flat `{p1node}` / `{p2rev}` keywords and errors
  -- with "keyword 'p1' has no member" on the dotted form, so re-introduce the
  -- dotted spelling as template aliases rather than duplicating the ~140 lines
  -- of streaming plumbing that embeds the template.
  local template_aliases = {
    "--config",
    "templatealias.p1=dict(node=p1node)",
    "--config",
    "templatealias.p2=dict(node=p2node, rev=p2rev)",
  }

  function SaplingAdapter:get_command()
    return utils.vec_join(M.cmd, template_aliases)
  end

  -- hg exposes this as `root --template={hgpath}`; Sapling has a flag instead.
  function SaplingAdapter:get_dir(path)
    return sapling_dotdir(path)
  end

  -- Sapling has no `debugmergestate -Tjson`. Reporting "no merge in progress"
  -- matches what HgAdapter does when the call fails, and only costs the
  -- three-way layout during an unresolved merge.
  function SaplingAdapter:get_merge_context()
    return { ours = {}, theirs = {}, base = {} }
  end

  -- Only the trailing hgrc probe needs replacing here: HgAdapter reads it via
  -- `log --rev=0`, and Sapling has no revision numbers, so rev 0 never
  -- resolves. The gates in front of it still matter — without them untracked
  -- files get listed in commit-to-commit diffs, where they make no sense.
  function SaplingAdapter:show_untracked(opt)
    opt = opt or {}

    -- An untracked file only means something against the working copy.
    if opt.revs and opt.revs.right and opt.revs.right.type ~= RevType.LOCAL then
      return false
    end

    -- An explicit `--untracked-files` flag wins.
    if opt.dv_opt and type(opt.dv_opt.show_untracked) == "boolean" then
      return opt.dv_opt.show_untracked
    end

    return true
  end

  -- HgAdapter runs `debugmergestate -Tjson` alongside the status job and joins
  -- the two, so on Sapling - which has no such flag - the failing merge probe
  -- takes the whole file listing down with it. This is the same routine minus
  -- the merge half, which costs conflict entries but makes listing work.
  SaplingAdapter.tracked_files = async.wrap(function(self, left, right, args, kind, opt, callback)
    local namestat_job = Job({
      command = self:bin(),
      args = utils.vec_join(
        self:args(),
        "status",
        "--modified",
        "--added",
        "--removed",
        "--deleted",
        "--template={status} {path}\n",
        args
      ),
      cwd = self.ctx.toplevel,
      retry = 2,
      log_opt = { label = "SaplingAdapter:tracked_files()" },
    })

    local ok = await(Job.join({ namestat_job }))
    if not ok then
      callback(namestat_job.stderr, nil)
      return
    end

    local files = {}

    for _, s in ipairs(namestat_job.stdout) do
      if s ~= " " and s ~= "" and kind ~= "staged" then
        local status = s:sub(1, 1):gsub("%s", " ")
        local name = vim.trim(s:match("[%a%s]%s*(.*)"))

        table.insert(files, FileEntry.with_layout(opt.default_layout, {
          adapter = self,
          path = name,
          status = status,
          -- Mercurial cannot report per-file line counts here either; see
          -- diffview.nvim#366.
          stats = {},
          kind = kind,
          revs = { a = left, b = right },
        }))
      end
    end

    callback(nil, files, {})
  end)

  -- Sapling dropped named branches, so `branches` does not exist. Offer the
  -- things that actually name a commit here instead.
  function SaplingAdapter:rev_candidates(arg_lead, opt)
    opt = vim.tbl_extend("keep", opt or {}, { accept_range = false })

    local names = self:exec_sync({
      "log",
      "--rev=heads(all())",
      "--template={node|short}\\n{bookmarks}\\n{remotenames}\\n",
    }, { cwd = self.ctx.toplevel, silent = true })

    local ret, seen = {}, {}
    local function add(word)
      if word ~= "" and not seen[word] then
        seen[word] = true
        table.insert(ret, word)
      end
    end

    add(".")
    add(".^")
    for _, name in ipairs(names or {}) do
      -- A commit can carry several bookmarks on one line.
      for word in tostring(name):gmatch("%S+") do
        add(word)
      end
    end

    return ret
  end

  return SaplingAdapter
end

---Teach diffview about Sapling. Safe to call more than once.
function M.register()
  if M._registered then return end
  M._registered = true

  -- Several lookups are keyed on `config_key`, so "sapling" needs entries of
  -- its own or file history indexes nil. Sapling's log flags match hg's, so
  -- hg's defaults are the right starting point - and a user can now override
  -- `file_history_panel.log_options.sapling` independently.
  local config = require("diffview.config")
  config.log_option_defaults.sapling = vim.deepcopy(config.log_option_defaults.hg)

  local log_options = config.get_config().file_history_panel.log_options
  log_options.sapling = log_options.sapling or vim.deepcopy(log_options.hg)

  local vcs = require("diffview.vcs")
  local SaplingAdapter = build()
  local get_adapter = vcs.get_adapter

  ---@diagnostic disable-next-line: duplicate-set-field
  vcs.get_adapter = function(opt)
    -- Let the built-in adapters answer first: a git-backed Sapling repo is
    -- better served by GitAdapter.
    local err, adapter = get_adapter(opt)
    if not err then return err, adapter end

    if not SaplingAdapter.bootstrap.done then SaplingAdapter.run_bootstrap() end
    if not SaplingAdapter.bootstrap.ok then return err end

    opt.cmd_ctx = opt.cmd_ctx or {}

    local top_indicators, path_args = opt.top_indicators, opt.cmd_ctx.path_args
    if not top_indicators then
      path_args, top_indicators = SaplingAdapter.get_repo_paths(opt.cmd_ctx.path_args, opt.cmd_ctx.cpath)
    end

    local sl_err, toplevel = SaplingAdapter.find_toplevel(top_indicators)
    if sl_err then return err end

    return SaplingAdapter.create(toplevel, path_args, opt.cmd_ctx.cpath)
  end
end

return M
