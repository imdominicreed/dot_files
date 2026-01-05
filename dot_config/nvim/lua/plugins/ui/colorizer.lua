-- Colorizer - Color preview
return {
	"NvChad/nvim-colorizer.lua",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		filetypes = { "*" },
		user_default_options = {
			RGB = true,
			RRGGBB = true,
			names = false,
			RRGGBBAA = true,
			AARRGGBB = true,
			rgb_fn = true,
			hsl_fn = true,
			css = true,
			css_fn = true,
			mode = "background",
			tailwind = false,
			sass = { enable = false },
			virtualtext = "■",
		},
	},
	config = function(_, opts)
		require("colorizer").setup(opts)
		vim.defer_fn(function()
			require("colorizer").attach_to_buffer(0)
		end, 0)
	end,
}
