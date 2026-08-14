-- Lualine - Statusline

-- Sapling has no git branch for lualine's built-in `branch` component to find,
-- so the statusline's VCS slot goes blank inside a Sapling repo. This fills it
-- with the active bookmark, or the short hash when the commit has none.
--
-- `sl` is never shelled out from the component itself: a statusline redraws far
-- too often for that. The value is refreshed asynchronously on the events that
-- can actually change it and memoised per directory, so drawing is a table
-- lookup. A nil entry means "not looked up yet", an empty string "not a Sapling
-- repo" — the two must stay distinct or every redraw re-runs the lookup.
local sl_head = {}

local function refresh_sapling_head(force)
	if vim.fn.executable("sl") ~= 1 then
		return
	end

	local cwd = vim.uv.cwd() or ""
	if not force and sl_head[cwd] ~= nil then
		return
	end
	sl_head[cwd] = sl_head[cwd] or ""

	vim.system({ "sl", "--pager", "never", "root", "--dotdir" }, { cwd = cwd, text = true }, function(root)
		-- Sapling drives plain git repos too, reporting `<root>/.git/sl`. Only
		-- native repos (`<root>/.sl`) are ours; the rest keep the git branch
		-- component. Same test as diffview.lua and mini-diff.lua.
		local dotdir = vim.trim(root.stdout or "")
		if root.code ~= 0 or dotdir:sub(-4) ~= "/.sl" then
			sl_head[cwd] = ""
			return
		end

		local template = '{ifeq(join(bookmarks, ""), "", shortest(node, 8), join(bookmarks, " "))}'
		vim.system(
			{ "sl", "--pager", "never", "log", "-r", ".", "--template", template },
			{ cwd = cwd, text = true },
			function(res)
				sl_head[cwd] = res.code == 0 and vim.trim(res.stdout) or ""
			end
		)
	end)
end

local function sapling_head()
	local head = sl_head[vim.uv.cwd() or ""]
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
			lualine_b = { sapling_head, "branch" },
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
						-- gitsigns owns git repos...
						local gs = vim.b.gitsigns_status_dict
						if gs then
							return { added = gs.added, modified = gs.changed, removed = gs.removed }
						end

						-- ...and mini.diff owns Sapling ones, where gitsigns is
						-- hard-wired to git and never attaches.
						local md = vim.b.minidiff_summary
						if md then
							return { added = md.add, modified = md.change, removed = md.delete }
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
			group = vim.api.nvim_create_augroup("LualineSaplingHead", { clear = true }),
			callback = function()
				refresh_sapling_head(true)
			end,
		})
		-- Entering a buffer only fills a directory not seen yet; the events above
		-- are the ones that can move the bookmark or commit out from under us.
		vim.api.nvim_create_autocmd("BufEnter", {
			group = "LualineSaplingHead",
			callback = function()
				refresh_sapling_head(false)
			end,
		})

		refresh_sapling_head(true)
	end,
}
