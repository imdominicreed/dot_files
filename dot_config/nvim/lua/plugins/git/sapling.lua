-- sapling.nvim - Interactive Smartlog for Sapling
--
-- `<leader>s` and `<leader>gl` used to live here as lazy `keys`. They now go
-- through the dispatcher in core/keymaps.lua, which picks between this and
-- jj.nvim based on the repo the cursor is in.
return {
	"imdominicreed/nvim-sapling",
	branch = "main", -- track tip, not the tagged release
	main = "sapling",
	cmd = "Sapling",
	opts = {},
}
