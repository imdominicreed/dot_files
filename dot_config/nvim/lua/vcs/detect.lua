-- Which VCS owns a given path, answered once per directory.
--
-- Four modules need this question - gitsigns, mini.diff, diffview and the
-- smartlog dispatcher - and each used to answer it for itself. The probes are
-- gathered here and memoised because they run from `attach` hooks: a fresh
-- subprocess per buffer is a cost you can feel on a large session.
local M = {}

local cache = {}

---Run `probe` once per (kind, dir) pair and remember the answer.
---
---`false` is the miss marker rather than `nil`, so a directory that is not a
---repo is remembered as such instead of being re-probed on every attach.
local function memo(kind, dir, probe)
	if not dir or dir == "" or vim.fn.isdirectory(dir) == 0 then return nil end

	local key = kind .. "\0" .. dir
	if cache[key] == nil then
		cache[key] = probe(dir) or false
	end

	return cache[key] or nil
end

---Read a file whose entire contents are a single path.
local function read_path(file)
	local fd = io.open(file, "r")
	if not fd then return nil end

	local contents = fd:read("*a")
	fd:close()

	local path = vim.trim(contents or "")
	return path ~= "" and path or nil
end

---Absolute path of the jj repo containing `dir`, or nil.
---@param dir string
---@return string?
function M.jj_root(dir)
	return memo("jj", dir, function(d)
		-- `--ignore-working-copy` matters: without it a mere location query
		-- snapshots the working copy into `@`, which is both slower and a
		-- surprising side effect for something that only asks "where am I".
		local res = vim.system(
			{ "jj", "root", "--ignore-working-copy" },
			{ cwd = d, text = true }
		):wait(3000)

		return res.code == 0 and vim.trim(res.stdout) or nil
	end)
end

---Absolute path of the Sapling repo containing `dir`, or nil.
---
---Sapling speaks git natively, so plain `sl root` succeeds inside git repos
---too. The dotdir separates them: a native repo reports `<root>/.sl`, a
---git-backed one `<root>/.git/sl`. Only the former is Sapling's to claim.
---@param dir string
---@return string?
function M.sapling_root(dir)
	return memo("sl", dir, function(d)
		local res = vim.system(
			{ "sl", "--pager", "never", "root", "--dotdir" },
			{ cwd = d, text = true }
		):wait(3000)

		local dotdir = res.code == 0 and vim.trim(res.stdout) or ""
		return dotdir:sub(-4) == "/.sl" and dotdir:sub(1, -5) or nil
	end)
end

---The git directory backing a jj repo.
---
---jj stores every change as a real git commit, so git tooling can read even a
---non-colocated repo - it just has to be pointed at the right place. The store
---records that as `git_target`, a path relative to the store directory:
---`../../../.git` when colocated, plain `git` when hidden inside `.jj`.
---@param root string # a jj repo root, as returned by `M.jj_root`
---@return string?
function M.jj_git_dir(root)
	return memo("jjgitdir", root, function(r)
		-- A secondary workspace has `.jj/repo` as a file naming the real repo
		-- directory rather than being that directory itself.
		local repo = r .. "/.jj/repo"
		if vim.fn.isdirectory(repo) == 0 then
			repo = read_path(repo)
			if not repo then return nil end
		end

		local store = repo .. "/store"
		local target = read_path(store .. "/git_target")
		if not target then return nil end

		local dir = vim.fs.normalize(target:sub(1, 1) == "/" and target or (store .. "/" .. target))
		return vim.fn.isdirectory(dir) == 1 and dir or nil
	end)
end

---True when the jj repo also presents a top-level `.git`, which is jj's
---default for new repos. Plain git tooling then works with no redirection, so
---diffview's own GitAdapter handles the repo better than anything here could.
---@param root string
---@return boolean
function M.jj_colocated(root)
	return vim.fn.isdirectory(root .. "/.git") == 1
end

---Resolve a jj revset to a single commit id, or nil if it names no commit.
---@param root string
---@param revset string
---@return string?
function M.jj_rev(root, revset)
	local res = vim.system({
		"jj", "--no-pager", "log", "--ignore-working-copy",
		"--revisions", revset, "--no-graph", "--template", "commit_id",
	}, { cwd = root, text = true }):wait(5000)

	if res.code ~= 0 then return nil end

	local id = vim.trim(res.stdout or "")
	return id ~= "" and id or nil
end

---Forget every memoised answer. Repos are created and deleted mid-session and
---nothing else invalidates the cache.
function M.reset()
	cache = {}
end

return M
