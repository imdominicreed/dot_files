local plugins = {
	{
    "mason-org/mason-lspconfig.nvim",
    opts = {},
    dependencies = {
        { "mason-org/mason.nvim", opts = {} },
        "neovim/nvim-lspconfig",
    },
		lazy = false
},
	-- {
	--    "nvim-java/nvim-java",
	--    lazy = false,
	--    dependencies = {
	--      "nvim-java/lua-async-await",
	--      "nvim-java/nvim-java-core",
	--      -- "nvim-java/nvim-java-test",
	--      "nvim-java/nvim-java-dap",
	--      "muniftanjim/nui.nvim",
	--      "neovim/nvim-lspconfig",
	--      "mfussenegger/nvim-dap",
	--      {
	--        "williamboman/mason.nvim",
	--        opts = {
	--          registries = {
	--            "github:nvim-java/mason-registry",
	--            "github:mason-org/mason-registry",
	--          },
	--        },
	--      },
	--    },
	--    config = function()
	--      require("java").setup {}
	--      require("lspconfig").jdtls.setup {
	--        on_attach = require("plugins.configs.lspconfig").on_attach,
	--        capabilities = require("plugins.configs.lspconfig").capabilities,
	--        filetypes = { "java" },
	--      }
	--    end,
	--  },
	{
		"mfussenegger/nvim-dap",
		init = function()
			require("core.utils").load_mappings("dap")
		end
	},
	{
		"dreamsofcode-io/nvim-dap-go",
		ft = "go",
		dependencies = "mfussenegger/nvim-dap",
		config = function(_, opts)
			require("dap-go").setup(opts)
			require("core.utils").load_mappings("dap_go")
		end
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			require "plugins.configs.lspconfig"
			require "custom.configs.lspconfig"
		end,
	},
	-- {
	--   "olexsmir/gopher.nvim",
	--   ft = "go",
	--   config = function(_, opts)
	--     require("gopher").setup(opts)
	--     require("core.utils").load_mappings("gopher")
	--   end,
	--   build = function()
	--     vim.cmd [[silent! goinstalldeps]]
	--   end,
	-- },
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
	},
	{
		"github/copilot.vim",
		lazy = false,
	},
	{
		'mrcjkb/rustaceanvim',
		version = '^6', -- recommended
		lazy = false, -- this plugin is already lazy	}
	},
	-- {
	--    "CopilotC-Nvim/CopilotChat.nvim",
	--    dependencies = {
	--      { "github/copilot.vim" },
	--      { "nvim-lua/plenary.nvim", branch = "master" },
	--    },
	--    build = "make tiktoken",
	--    lazy = false,
	--    config = function()
	--      require("custom.configs.copilot")  -- Load your config file
	--    end,
	--  },
	{
		"olimorris/codecompanion.nvim",
		version = "v17.33.0",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {
		},
		config = function()
			require("custom.configs.codecompanion")
		end,
		lazy = false,
	},
	{
		"folke/edgy.nvim",
		event = "VeryLazy",
		opts = {}
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "codecompanion" }
	},
	{
		"j-hui/fidget.nvim",
		opts = {
		},
	}
}
return plugins
