-- Working a gh-reviews report the way you work a review: hide what is done.
--
-- `gh-reviews` (my-scripts/gh-reviews) exports a pull request as Markdown and
-- re-runs replace only the generated block, preserving whatever you wrote
-- between each comment's `comment-note` markers. That note block is therefore
-- the one durable place to record "I handled this one", so resolving a comment
-- stamps a marker inside it. Everything else here - the folds, the jumps, the
-- quickfix list - is read back out of the buffer, which means the file stays
-- the single source of truth and survives the next `gh-reviews` run untouched.
local M = {}

local RESOLVED_MARK = "<!-- gh-reviews:resolved -->"
local GENERATED_START = "<!-- gh-reviews:generated:start -->"

local NOTE_START = "^%s*<!%-%- gh%-reviews:comment%-note:(%d+):start %-%->%s*$"
local NOTE_END = "^%s*<!%-%- gh%-reviews:comment%-note:(%d+):end %-%->%s*$"
-- Every inline comment is introduced by a heading holding nothing but a
-- backticked `path:line`, at level 5 under a review and level 3 when GitHub
-- returned it unattached, so match the fence rather than the depth.
local HEADING = "^#+%s+`([^`]+)`%s*$"
local LINK = "^%-%s+Link:%s+%[view comment%]%((.-)%)%s*$"
local AUTHOR = "^%-%s+Author:%s+(.-)%s*$"

local namespace = vim.api.nvim_create_namespace("gh_reviews")

---Per-buffer parse of the report: the comment list plus the fold level each
---line should report. Rebuilt on every change; a report is a few hundred lines
---so a full re-scan is cheaper than tracking edits.
---@type table<integer, { comments: table[], levels: table<integer, string>, by_heading: table<integer, table> }>
local state = {}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "gh-reviews" })
end

---Split the buffer into comment blocks.
---
---A block runs from its `path:line` heading through its note-block end marker,
---which is also where the note you are allowed to edit lives - so a resolved
---mark is simply a line inside that range.
---@param buf integer
---@return table[] comments
local function parse(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local comments = {}
	local pending, open = nil, nil

	for lnum, line in ipairs(lines) do
		if open then
			if line:match(NOTE_END) then
				open.note_end = lnum
				open.last = lnum
				comments[#comments + 1] = open
				open, pending = nil, nil
			elseif vim.trim(line) == RESOLVED_MARK then
				open.resolved = true
			end
		else
			local target = line:match(HEADING)
			if target then
				local path, at = target:match("^(.*):(%d+)$")
				pending = {
					heading = lnum,
					target = target,
					path = path or target,
					line = tonumber(at),
				}
			elseif pending then
				pending.url = pending.url or line:match(LINK)
				pending.author = pending.author or line:match(AUTHOR)

				-- First quoted line of the comment body, kept for the quickfix
				-- text so the list reads as feedback rather than filenames.
				if not pending.summary then
					local body = line:match("^>%s?(.+)$")
					if body and vim.trim(body) ~= "" then pending.summary = vim.trim(body) end
				end

				local id = line:match(NOTE_START)
				if id then
					pending.id = tonumber(id)
					pending.note_start = lnum
					pending.resolved = false
					open = pending
				end
			end
		end
	end

	-- Swallow the blank lines that follow a block, bar one: a closed fold that
	-- leaves three blank lines behind it looks like a rendering bug.
	for _, comment in ipairs(comments) do
		local last = comment.last
		while lines[last + 1] and vim.trim(lines[last + 1]) == "" do
			last = last + 1
		end
		comment.last = math.max(comment.note_end, last - 1)
	end

	return comments
end

---Fold levels for `foldmethod=expr`.
---
---Only resolved comments fold. Anything still open stays flat, so nothing you
---have yet to read can hide behind a fold you did not ask for.
local function fold_levels(comments)
	local levels = {}
	for _, comment in ipairs(comments) do
		if comment.resolved then
			levels[comment.heading] = ">1"
			for lnum = comment.heading + 1, comment.last do
				levels[lnum] = "1"
			end
		end
	end
	return levels
end

local function summarize(buf, comments)
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

	local resolved = 0
	for _, comment in ipairs(comments) do
		if comment.resolved then resolved = resolved + 1 end
	end
	local open = #comments - resolved
	if #comments == 0 then return end

	-- The title line, so the tally sits where you look first.
	local title
	for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 40, false)) do
		if line:match("^#%s+%S") then
			title = lnum
			break
		end
	end
	if not title then return end

	vim.api.nvim_buf_set_extmark(buf, namespace, title - 1, 0, {
		virt_text = {
			{ "  " .. open .. " open", open > 0 and "GhReviewsOpen" or "GhReviewsResolved" },
			{ " · " .. resolved .. " resolved", "GhReviewsResolved" },
		},
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

local function refresh(buf)
	local entry = state[buf]
	if not entry then return end

	entry.comments = parse(buf)
	entry.levels = fold_levels(entry.comments)
	entry.by_heading = {}
	for _, comment in ipairs(entry.comments) do
		entry.by_heading[comment.heading] = comment
	end

	summarize(buf, entry.comments)
end

function M.foldexpr()
	local entry = state[vim.api.nvim_win_get_buf(0)]
	return entry and entry.levels[vim.v.lnum] or "0"
end

function M.foldtext()
	local entry = state[vim.api.nvim_win_get_buf(0)]
	local comment = entry and entry.by_heading[vim.v.foldstart]
	if not comment then return vim.fn.getline(vim.v.foldstart) end

	return string.format(
		"  ✓ %s%s  ·  %d lines resolved",
		comment.target,
		comment.author and ("  " .. comment.author) or "",
		vim.v.foldend - vim.v.foldstart + 1
	)
end

---The comment the cursor sits in. A closed fold puts the cursor on the heading
---line, so containment covers both the folded and the unfolded case.
local function comment_at(buf, lnum)
	local entry = state[buf]
	if not entry then return nil end

	for _, comment in ipairs(entry.comments) do
		if lnum >= comment.heading and lnum <= comment.last then return comment end
	end
	return nil
end

local function current(buf)
	buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
	local comment = comment_at(buf, vim.api.nvim_win_get_cursor(0)[1])
	if not comment then notify("No review comment under the cursor", vim.log.levels.WARN) end
	return buf, comment
end

---Mark the comment under the cursor resolved, or un-resolve it again.
---
---The buffer is written straight away: an unsaved mark is a mark the next
---`gh-reviews` run cannot preserve. `noautocmd` keeps format-on-save away from
---generated Markdown.
function M.toggle(buf)
	local comment
	buf, comment = current(buf or 0)
	if not comment then return end

	if comment.resolved then
		for lnum = comment.note_end - 1, comment.note_start, -1 do
			local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
			if line and vim.trim(line) == RESOLVED_MARK then
				vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, {})
			end
		end
	else
		vim.api.nvim_buf_set_lines(buf, comment.note_start, comment.note_start, false, { RESOLVED_MARK })
	end

	refresh(buf)
	if vim.bo[buf].modified and vim.api.nvim_buf_get_name(buf) ~= "" then
		vim.api.nvim_buf_call(buf, function() vim.cmd("silent! noautocmd write") end)
	end

	-- `zX`, not `zx`: both recompute the folds, but `zx` ends with a `zv` that
	-- would immediately re-open the fold the cursor is standing in - which is
	-- always the one just resolved.
	vim.cmd("normal! zX")
	vim.api.nvim_win_set_cursor(0, { comment.heading, 0 })
	notify(comment.target .. (comment.resolved and " reopened" or " resolved"))
end

---Jump to the next or previous comment that is still open.
---@param step integer # 1 forwards, -1 backwards
function M.goto_open(step)
	local buf = vim.api.nvim_get_current_buf()
	local entry = state[buf]
	if not entry then return end

	local cursor = vim.api.nvim_win_get_cursor(0)[1]
	local from, to = 1, #entry.comments
	if step < 0 then
		from, to = to, 1
	end

	for index = from, to, step do
		local comment = entry.comments[index]
		local beyond = step > 0 and comment.heading > cursor or comment.heading < cursor
		if beyond and not comment.resolved then
			vim.cmd("normal! m'")
			vim.api.nvim_win_set_cursor(0, { comment.heading, 0 })
			vim.cmd("normal! zz")
			return
		end
	end

	notify("No " .. (step > 0 and "further" or "earlier") .. " open comment")
end

---Where the report's repo-relative paths are rooted. The report usually sits in
---the repo it describes, but it is just as often kept somewhere else, so fall
---back to the working directory before giving up.
local function resolve_path(buf, path)
	local roots = { vim.fs.root(buf, { ".git", ".jj", ".sl" }), vim.fn.getcwd() }
	for _, root in ipairs(roots) do
		if root then
			local candidate = root .. "/" .. path
			if vim.fn.filereadable(candidate) == 1 then return candidate end
		end
	end
	return nil
end

---Open the source line the comment is about, in a window that is not this one.
function M.open_source(buf)
	local comment
	buf, comment = current(buf or 0)
	if not comment then return end

	local file = resolve_path(buf, comment.path)
	if not file then
		notify("Cannot find " .. comment.path .. " below the repo root or cwd", vim.log.levels.WARN)
		return
	end

	local this = vim.api.nvim_get_current_win()
	local target
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if win ~= this and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
			target = win
			break
		end
	end
	if target then
		vim.api.nvim_set_current_win(target)
	else
		vim.cmd("vsplit")
	end

	vim.cmd.edit(vim.fn.fnameescape(file))
	if comment.line then
		pcall(vim.api.nvim_win_set_cursor, 0, { comment.line, 0 })
		vim.cmd("normal! zz")
	end
end

---Open the comment on github.com.
function M.open_url(buf)
	local comment
	buf, comment = current(buf or 0)
	if not comment then return end

	if not comment.url then
		notify("That comment has no link", vim.log.levels.WARN)
		return
	end
	vim.ui.open(comment.url)
end

---Send every still-open comment to the quickfix list, pointed at the real
---source lines - the list to walk while you are actually fixing things.
function M.quickfix(buf)
	buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
	local entry = state[buf]
	if not entry then return end

	local items = {}
	for _, comment in ipairs(entry.comments) do
		if not comment.resolved then
			local file = resolve_path(buf, comment.path)
			items[#items + 1] = {
				filename = file or vim.api.nvim_buf_get_name(buf),
				lnum = file and comment.line or comment.heading,
				col = 1,
				text = string.format("%s %s", comment.author or "", comment.summary or comment.target),
			}
		end
	end

	if #items == 0 then
		notify("Nothing open - every comment is resolved")
		return
	end

	vim.fn.setqflist({}, " ", { title = "gh-reviews: open comments", items = items })
	vim.cmd("copen")
end

---Show the resolved comments again without un-resolving them.
function M.toggle_hidden()
	local enabled = not vim.wo.foldenable
	vim.wo.foldenable = enabled
	-- Folds remember having been opened by hand, so re-enabling alone can leave
	-- resolved comments on screen; `zX` makes "hide" mean it.
	if enabled then vim.cmd("normal! zX") end
	notify(enabled and "Resolved comments hidden" or "Showing resolved comments")
end

---Fold options belong to the window, so they are re-applied every time the
---report is displayed. `vim.wo[0][0]` scopes them to this buffer in this
---window, so another buffer shown here later gets its own folding back.
local function apply_window_options()
	local wo = vim.wo[0][0]
	wo.foldmethod = "expr"
	wo.foldexpr = "v:lua.require'ghreviews'.foldexpr()"
	wo.foldtext = "v:lua.require'ghreviews'.foldtext()"
	wo.foldenable = true
	wo.foldlevel = 0
	wo.foldminlines = 0
	-- Fold lines read as prose here, so drop the trailing dot fill. Rebuilt
	-- from the current value rather than appended: `apply_window_options` runs
	-- again on every BufWinEnter, and appending a key twice throws.
	local fill = vim.opt_local.fillchars:get()
	fill.fold = " "
	vim.opt_local.fillchars = fill
end

local function attach(buf)
	if state[buf] then return end
	state[buf] = { comments = {}, levels = {}, by_heading = {} }

	local group = vim.api.nvim_create_augroup("GhReviewsBuffer" .. buf, { clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufWritePost" }, {
		group = group,
		buffer = buf,
		callback = function() refresh(buf) end,
	})
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		buffer = buf,
		callback = apply_window_options,
	})
	vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
		group = group,
		buffer = buf,
		callback = function() state[buf] = nil end,
	})

	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = "Review: " .. desc })
	end
	map("<leader>rr", M.toggle, "toggle resolved")
	-- `zi` already means "toggle folding", and in a report the folds are exactly
	-- the resolved comments - so it keeps its meaning instead of costing a
	-- leader key. `<leader>rh` was the obvious mnemonic and is Reset hunk.
	map("zi", M.toggle_hidden, "show/hide resolved")
	map("<leader>ro", M.open_url, "open comment on GitHub")
	map("<leader>rq", M.quickfix, "open comments to quickfix")
	map("<CR>", M.open_source, "jump to the source line")
	map("]r", function() M.goto_open(1) end, "next open comment")
	map("[r", function() M.goto_open(-1) end, "previous open comment")

	local command = function(name, fn, desc)
		vim.api.nvim_buf_create_user_command(buf, name, fn, { desc = desc })
	end
	command("GhReviewsToggle", function() M.toggle() end, "Toggle resolved on the comment under the cursor")
	command("GhReviewsHidden", function() M.toggle_hidden() end, "Show or hide resolved comments")
	command("GhReviewsSource", function() M.open_source() end, "Open the source line under review")
	command("GhReviewsUrl", function() M.open_url() end, "Open the comment on github.com")
	command("GhReviewsQuickfix", function() M.quickfix() end, "Send open comments to the quickfix list")

	pcall(function()
		require("which-key").add({ { "<leader>r", group = "Review", buffer = buf } })
	end)

	apply_window_options()
	refresh(buf)
end

---A gh-reviews report is either named like one or carries the generated marker
---near the top - the marker also catches reports you renamed.
local function is_report(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name:match("github%-reviews%-[^/]*%.md$") then return true end

	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 60, false)) do
		if line:find(GENERATED_START, 1, true) then return true end
	end
	return false
end

function M.setup()
	vim.api.nvim_set_hl(0, "GhReviewsResolved", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "GhReviewsOpen", { link = "WarningMsg", default = true })

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = vim.api.nvim_create_augroup("GhReviews", { clear = true }),
		pattern = { "*.md", "*.markdown" },
		callback = function(event)
			if is_report(event.buf) then attach(event.buf) end
		end,
	})
end

return M
