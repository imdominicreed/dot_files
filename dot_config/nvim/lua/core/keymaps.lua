-- Keymaps
local map = vim.keymap.set

-- General
map("n", "<Esc>", "<cmd>noh<CR>", { desc = "Clear highlights" })
map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "Copy whole file" })

-- <leader>e: nvim-tree normally, netrw sidebar when the context is remote.
-- nvim-tree only speaks the local filesystem, so scp:// paths must go to netrw.
local function remote_dir()
	local is_url = function(s)
		return type(s) == "string" and s ~= "" and s:match("^%a[%w+.%-]*://") ~= nil
	end

	-- netrw records the directory it is browsing; most reliable when already in it
	local curdir = vim.b.netrw_curdir
	if is_url(curdir) then
		return curdir
	end

	local name = vim.api.nvim_buf_get_name(0)
	if is_url(name) then
		-- a trailing slash means it is already a directory
		if name:sub(-1) == "/" then
			return (name:gsub("/+$", ""))
		end
		return vim.fn.fnamemodify(name, ":h")
	end

	local cwd = vim.fn.getcwd()
	if is_url(cwd) then
		return cwd
	end

	return nil
end

map("n", "<leader>e", function()
	local dir = remote_dir()
	if dir then
		vim.cmd("Lexplore " .. vim.fn.fnameescape(dir))
	else
		vim.cmd("NvimTreeFocus")
	end
end, { desc = "Explorer (nvim-tree, or netrw when remote)" })

-- Remote browsing (netrw sidebar; nvim-tree cannot read scp:// paths)
map("n", "<leader>R", function()
	vim.ui.input({ prompt = "Remote dir: ", default = "scp://" }, function(path)
		if path and path ~= "" and path ~= "scp://" then
			vim.cmd("Lexplore " .. vim.fn.fnameescape(path))
		end
	end)
end, { desc = "Remote tree (netrw sidebar)" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })

-- Insert mode navigation
map("i", "<C-b>", "<ESC>^i", { desc = "Beginning of line" })
map("i", "<C-e>", "<End>", { desc = "End of line" })
map("i", "<C-h>", "<Left>", { desc = "Move left" })
map("i", "<C-l>", "<Right>", { desc = "Move right" })
map("i", "<C-j>", "<Down>", { desc = "Move down" })
map("i", "<C-k>", "<Up>", { desc = "Move up" })

-- Line numbers toggle
map("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "Toggle line number" })
map("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "Toggle relative number" })

-- Better movement on wrapped lines
map({ "n", "x" }, "j", 'v:count || mode(1)[0:1] == "no" ? "j" : "gj"', { expr = true, desc = "Move down" })
map({ "n", "x" }, "k", 'v:count || mode(1)[0:1] == "no" ? "k" : "gk"', { expr = true, desc = "Move up" })
map({ "n", "x" }, "<Down>", 'v:count || mode(1)[0:1] == "no" ? "j" : "gj"', { expr = true, desc = "Move down" })
map({ "n", "x" }, "<Up>", 'v:count || mode(1)[0:1] == "no" ? "k" : "gk"', { expr = true, desc = "Move up" })

-- Indenting in visual mode
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Don't copy replaced text in visual mode
map("x", "p", 'p:let @+=@0<CR>:let @"=@0<CR>', { silent = true, desc = "Paste without copying replaced text" })

-- Terminal escape
map("t", "<C-x>", vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true), { desc = "Escape terminal mode" })

-- Buffer
map("n", "<leader>b", "<cmd>enew<CR>", { desc = "New buffer" })
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Close buffer" })

-- LSP formatting
map("n", "<leader>fm", function()
	vim.lsp.buf.format({ async = true })
end, { desc = "LSP formatting" })

-- Copilot
vim.g.copilot_no_tab_map = true
map("i", "<C-y>", 'copilot#Accept("\\<CR>")', { expr = true, silent = true, desc = "Accept Copilot suggestion" })
