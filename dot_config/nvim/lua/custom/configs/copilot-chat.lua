-- Setup CopilotChat
require("CopilotChat").setup({
  model = 'gpt-4.1',
  temperature = 0.1,
  window = {
    layout = 'float',
    width = 80,
    height = 20,
    border = 'rounded',
    title = '🤖 AI Assistant',
    zindex = 100,
  },
  headers = {
    user = '👤 You',
    assistant = '🤖 Copilot',
    tool = '🔧 Tool',
  },
  separator = '━━',
  auto_fold = true,
  auto_insert_mode = true,
})

-- Auto-command to customize chat buffer behavior
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = 'copilot-*',
  callback = function()
    vim.opt_local.relativenumber = false
    vim.opt_local.number = false
    vim.opt_local.conceallevel = 0
  end,
})

-- Custom highlights
vim.api.nvim_set_hl(0, 'CopilotChatHeader', { fg = '#7C3AED', bold = true })
vim.api.nvim_set_hl(0, 'CopilotChatSeparator', { fg = '#374151' })
