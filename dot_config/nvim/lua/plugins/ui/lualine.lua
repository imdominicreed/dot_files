-- Lualine - Statusline

-- Neither jj nor Sapling gives lualine's built-in `branch` component anything
-- to show. Sapling has no git branch at all, and a colocated jj repo leaves
-- git's HEAD permanently detached, so the component renders a bare "HEAD". This
-- fills the slot with what actually names the current commit instead: the
-- bookmarks it carries, or a short id when it has none.
--
-- Neither `jj` nor `sl` is ever shelled out from the component itself: a
-- statusline redraws far too often for that. The value is refreshed
-- asynchronously on the events that can change it and memoised per directory,
-- so drawing is a table lookup. A nil entry means "not looked up yet", an empty
-- string "no VCS of ours here" — the two must stay distinct or every redraw
-- re-runs the lookup.
local vcs_head = {}

-- Which VCS a directory belongs to is asked through vcs.detect, which memoises
-- it: that probe is a few milliseconds once per directory, and this runs on
-- events rather than on redraw. Only the head lookup itself — the slow half —
-- stays asynchronous.
local head_probes = {
	{
		exe = "jj",
		root = function(dir) return require("vcs.detect").jj_root(dir) end,
		-- `--ignore-working-copy` keeps drawing a statusline from snapshotting
		-- the working copy as a side effect.
		cmd = {
			"jj", "--no-pager", "log", "--ignore-working-copy",
			"--revisions", "@", "--no-graph",
			"--template", 'if(bookmarks, bookmarks.join(" "), change_id.shortest(8))',
		},
	},
	{
		exe = "sl",
		root = function(dir) return require("vcs.detect").sapling_root(dir) end,
		cmd = {
			"sl", "--pager", "never", "log", "-r", ".",
			"--template", '{ifeq(join(bookmarks, ""), "", shortest(node, 8), join(bookmarks, " "))}',
		},
	},
}

local function refresh_vcs_head(force)
	local cwd = vim.uv.cwd() or ""
	if not force and vcs_head[cwd] ~= nil then
		return
	end
	vcs_head[cwd] = vcs_head[cwd] or ""

	for _, probe in ipairs(head_probes) do
		if vim.fn.executable(probe.exe) == 1 and probe.root(cwd) then
			vim.system(probe.cmd, { cwd = cwd, text = true }, function(res)
				vcs_head[cwd] = res.code == 0 and vim.trim(res.stdout) or ""
			end)
			return
		end
	end

	-- Not a repo either of them owns: leave the slot to the git `branch`
	-- component, which handles that case perfectly well.
	vcs_head[cwd] = ""
end

local function vcs_head_component()
	local head = vcs_head[vim.uv.cwd() or ""]
	return (head and head ~= "") and (" " .. head) or ""
end

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			theme = "auto",
			globalstatus = true,
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			disabled_filetypes = {
				statusline = { "dashboard", "alpha", "starter", "DiffviewFiles" },
			},
			refresh = { statusline = 1000 },
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = {
				vcs_head_component,
				-- A colocated jj repo keeps git's HEAD detached, so `branch`
				-- renders the parent commit's hash next to the head above it.
				-- Show it only where it is the one saying anything.
				{ "branch", cond = function() return vcs_head_component() == "" end },
			},
			lualine_c = {
				{
					"diagnostics",
					symbols = {
						error = " ",
						warn = " ",
						info = " ",
						hint = "󰝶 ",
					},
				},
				{ "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
				{ "filename", path = 1 },
			},
			lualine_x = {
				{
					"diff",
					source = function()
						-- mini.diff is asked first because it only ever attaches
						-- where it owns the buffer - a jj or Sapling repo - and
						-- the two never overlap.
						--
						-- Order matters here: gitsigns publishes
						-- `gitsigns_status_dict` from the repo context alone, so
						-- in a colocated jj repo the table exists and is merely
						-- empty of counts even though gitsigns declined to
						-- attach. Reading it first would show no diff at all.
						local md = vim.b.minidiff_summary
						if md then
							return { added = md.add, modified = md.change, removed = md.delete }
						end

						local gs = vim.b.gitsigns_status_dict
						if gs then
							return { added = gs.added, modified = gs.changed, removed = gs.removed }
						end
					end,
					symbols = {
						added = " ",
						modified = " ",
						removed = " ",
					},
				},
			},
			lualine_y = {
				{ "progress", separator = " ", padding = { left = 1, right = 0 } },
				{ "location", padding = { left = 0, right = 1 } },
			},
			lualine_z = {
				function()
					return " " .. os.date("%R")
				end,
			},
		},
		extensions = { "nvim-tree", "lazy" },
	},
	config = function(_, opts)
		require("lualine").setup(opts)

		vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained", "BufWritePost" }, {
			group = vim.api.nvim_create_augroup("LualineVcsHead", { clear = true }),
			callback = function()
				refresh_vcs_head(true)
			end,
		})
		-- Entering a buffer only fills a directory not seen yet; the events above
		-- are the ones that can move the bookmark or commit out from under us.
		vim.api.nvim_create_autocmd("BufEnter", {
			group = "LualineVcsHead",
			callback = function()
				refresh_vcs_head(false)
			end,
		})

		refresh_vcs_head(true)
	end,
}
