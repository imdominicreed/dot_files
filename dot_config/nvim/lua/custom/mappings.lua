local M = {}

M.dap = {
  plugin = true,
  n = {
    -- Breakpoints
    ["<leader>db"] = {
      "<cmd> DapToggleBreakpoint <CR>",
      "Add breakpoint at line"
    },
    
    -- UI
    ["<leader>dus"] = {
      function ()
        local widgets = require('dap.ui.widgets');
        local sidebar = widgets.sidebar(widgets.scopes);
        sidebar.open();
      end,
      "Open debugging sidebar"
    },

    -- Control
    ["<leader>dc"] = {
      function()
        require('dap').continue()
      end,
      "Continue/Start debugging"
    },
    ["<leader>do"] = {
      function()
        require('dap').step_over()
      end,
      "Step over"
    },
    ["<leader>di"] = {
      function()
        require('dap').step_into()
      end,
      "Step into"
    },
    ["<leader>dt"] = {
      function()
        require('dap').step_out()
      end,
      "Step out"
    },
    ["<leader>dl"] = {
      function()
        require('dap').run()
      end,
      "Run debug session"
    },
    ["<leader>dr"] = {
      function()
        require('dap').run_last()
      end,
      "Run last debug configuration"
    }
  }
}

M.dap_go = {
  plugin = true,
  n = {
    ["<leader>dgt"] = {
      function()
        require('dap-go').debug_test()
      end,
      "Debug go test"
    },
    ["<leader>dgl"] = {
      function()
        require('dap-go').debug_last()
      end,
      "Debug last go test"
    }
  }
}

M.gopher = {
  n = {
    ["<leader>gsj"] = {
      "<cmd> GoTagAdd json <CR>",
      "Add json struct tags"
    },
    ["<leader>gsy"] = {
      "<cmd> GoTagAdd yaml <CR>",
      "Add yaml struct tags"
    }
  }
}

vim.api.nvim_set_keymap('i', '<C-y>', 'copilot#Accept("\\<CR>")', {
  expr = true,
  silent = true
})

-- Disable default Tab mapping
vim.g.copilot_no_tab_map = true

return M
