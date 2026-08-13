-- Snacks.nvim - Modern picker and utilities
local function git_log_with_refs(opts, ctx)
	local git = require("snacks.picker.source.git")
	local proc = require("snacks.picker.source.proc").proc

	local args = git.git(
		"log",
		"--pretty=format:%h%x1f%D%x1f%s%x1f%ch%x1f%an",
		"--abbrev-commit",
		"--decorate",
		"--date=short",
		"--color=never",
		"--no-show-signature",
		"--no-patch",
		opts
	)

	if opts.author then
		table.insert(args, "--author=" .. opts.author)
	end

	local file
	if opts.current_line then
		local cursor = vim.api.nvim_win_get_cursor(ctx.filter.current_win)
		file = vim.api.nvim_buf_get_name(ctx.filter.current_buf)
		args[#args + 1] = "-L"
		args[#args + 1] = cursor[1] .. ",+1:" .. file
	elseif opts.current_file then
		file = vim.api.nvim_buf_get_name(ctx.filter.current_buf)
		if opts.follow then
			args[#args + 1] = "--follow"
		end
		args[#args + 1] = "--"
		args[#args + 1] = file
	end

	if ctx.filter.search ~= "" then
		vim.list_extend(args, { "-S", ctx.filter.search })
	end

	file = file ~= nil and vim.fs.normalize(file) or nil
	local cwd = vim.fs.normalize(file and vim.fn.fnamemodify(file, ":h") or opts.cwd or vim.uv.cwd() or ".")
	cwd = Snacks.git.get_root(cwd) or cwd

	local renames = { file }
	return function(cb)
		if file then
			local is_rename = false
			proc({
				cmd = "git",
				cwd = cwd,
				args = git.git(
					"log",
					"-z",
					"--follow",
					"--name-status",
					"--pretty=format:''",
					"--diff-filter=R",
					"--",
					file,
					opts
				),
			}, ctx)(function(item)
				for _, text in ipairs(vim.split(item.text, "\0")) do
					if text:find("^R%d%d%d$") then
						is_rename = true
					elseif is_rename then
						is_rename = false
						renames[#renames + 1] = text
					end
				end
			end)
		end

		proc(ctx:opts({
			cwd = cwd,
			cmd = "git",
			args = args,
			transform = function(item)
				local parts = vim.split(item.text, "\31", { plain = true })
				if #parts ~= 5 then
					Snacks.notify.error(("failed to parse log item:\n%q"):format(item.text))
					return false
				end

				item.cwd = cwd
				item.commit = parts[1]
				item.refs = parts[2]
				item.msg = parts[3]
				item.date = parts[4]
				item.author = parts[5]
				item.file = file
				item.files = renames
			end,
		}), ctx)(cb)
	end
end

local function git_log_format_with_refs(item, picker)
	local align = Snacks.picker.util.align
	local ret = {}

	ret[#ret + 1] = { picker.opts.icons.git.commit, "SnacksPickerGitCommit" }
	ret[#ret + 1] = { align(item.commit or item.branch or "HEAD", 8, { truncate = true }), "SnacksPickerGitCommit" }
	ret[#ret + 1] = { " " }

	if item.refs and item.refs ~= "" then
		ret[#ret + 1] = { "(" .. item.refs .. ")", "SnacksPickerGitBranch" }
		ret[#ret + 1] = { " " }
	end

	if item.date then
		ret[#ret + 1] = { align(item.date, 16), "SnacksPickerGitDate" }
		ret[#ret + 1] = { " " }
	end

	Snacks.picker.highlight.extend(ret, Snacks.picker.format.commit_message(item, picker))

	if item.author then
		ret[#ret + 1] = { " <" .. item.author .. ">", "SnacksPickerGitAuthor" }
	end

	return ret
end

local function diffview_commit_against_head(picker, item)
	picker:close()

	if not (item and item.commit) then
		Snacks.notify.warn("No commit selected", { title = "Snacks Picker" })
		return
	end

	vim.cmd("DiffviewOpen " .. item.commit .. "..HEAD")
end

local function git_log_diff_against_head()
	Snacks.picker.git_log({
		confirm = diffview_commit_against_head,
	})
end

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		picker = {
			sources = {
				git_log = {
					finder = git_log_with_refs,
					format = git_log_format_with_refs,
				},
				git_log_file = {
					finder = git_log_with_refs,
					format = git_log_format_with_refs,
				},
				git_log_line = {
					finder = git_log_with_refs,
					format = git_log_format_with_refs,
				},
			},
		},
	},
	keys = {
		-- Find/Search
		{ "<leader>sf", function() Snacks.picker.files() end, desc = "Find Files" },
		{ "<leader>sF", function() Snacks.picker.files({ hidden = true, ignored = true }) end, desc = "Find All Files" },
		{ "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
		{ "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Grep Word", mode = { "n", "x" } },
		{ "<leader>sb", function() Snacks.picker.buffers() end, desc = "Buffers" },
		{ "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
		{ "<leader>sr", function() Snacks.picker.recent() end, desc = "Recent Files" },
		{ "<leader>s/", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
		-- Git
		-- <leader>gd belongs to diffview's stack diff; this takes the slot freed
		-- when the plain commit picker moved to <leader>gC.
		{ "<leader>gc", git_log_diff_against_head, desc = "Diff Commit Against HEAD" },
		{ "<leader>gC", function() Snacks.picker.git_log() end, desc = "Git Commits" },
		{ "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
		-- Other
		{ "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
		{ "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
	},
}
