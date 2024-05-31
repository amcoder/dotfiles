vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true

return {
  {
    'supermaven-inc/supermaven-nvim',
    opts = {
      keymaps = {
        accept_suggestion = '<C-c>',
        clear_suggestions = '<C-]>',
        accept_word = '<M-Right>',
      },
    },
  },
  {
    'github/copilot.vim',
    enabled = false,
    config = function()
      vim.cmd('imap <silent><script><expr> <C-c> copilot#Accept("<CR>")')
      vim.keymap.set('n', '<leader>cp', ':Copilot<cr>', { desc = 'Open Copilot' })
    end,
  },
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    enabled = false,
    branch = 'canary',
    dependencies = {
      { 'github/copilot.vim' }, -- or github/copilot.vim
      { 'nvim-lua/plenary.nvim' }, -- for curl, log wrapper
    },
    config = function(_, opts)
      local chat = require('CopilotChat')
      local select = require('CopilotChat.select')

      chat.setup(opts)

      vim.api.nvim_create_user_command('CopilotChatVisual', function(args)
        chat.ask(args.args, { selection = select.visual })
      end, { nargs = '*', range = true })

      -- Inline chat with Copilot
      vim.api.nvim_create_user_command('CopilotChatInline', function(args)
        chat.ask(args.args, {
          selection = select.visual,
          window = {
            layout = 'float',
            relative = 'cursor',
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = '*', range = true })

      -- Restore CopilotChatBuffer
      vim.api.nvim_create_user_command('CopilotChatBuffer', function(args)
        chat.ask(args.args, { selection = select.buffer })
      end, { nargs = '*', range = true })
    end,
    event = 'VeryLazy',
    keys = {
      -- Show help actions with telescope
      {
        '<leader>cch',
        function()
          local actions = require('CopilotChat.actions')
          require('CopilotChat.integrations.telescope').pick(actions.help_actions())
        end,
        desc = 'CopilotChat - Help actions',
      },
      -- Show prompts actions with telescope
      {
        '<leader>ccp',
        function()
          local actions = require('CopilotChat.actions')
          require('CopilotChat.integrations.telescope').pick(actions.prompt_actions())
        end,
        desc = 'CopilotChat - Prompt actions',
      },
      {
        '<leader>ccp',
        ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions())<CR>",
        mode = 'x',
        desc = 'CopilotChat - Prompt actions',
      },
      -- Code related commands
      { '<leader>cce', '<cmd>CopilotChatExplain<cr>', desc = 'CopilotChat - Explain code' },
      { '<leader>cct', '<cmd>CopilotChatTests<cr>', desc = 'CopilotChat - Generate tests' },
      { '<leader>ccF', '<cmd>CopilotChatFix<cr>', desc = 'CopilotChat - Fix code' },
      { '<leader>ccd', '<cmd>CopilotChatDocs<cr>', desc = 'CopilotChat - Document code' },
      { '<leader>cco', '<cmd>CopilotChatOptimize<cr>', desc = 'CopilotChat - Optimize code' },
      { '<leader>ccf', '<cmd>CopilotChatFixDiagnostic<cr>', desc = 'CopilotChat - Fix Diagnostic' },
      { '<leader>ccl', '<cmd>CopilotChatReset<cr>', desc = 'CopilotChat - Clear buffer and chat history' },
      { '<leader>ccv', '<cmd>CopilotChatToggle<cr>', desc = 'CopilotChat - Toggle Vsplit' },
      -- Chat with Copilot in visual mode
      {
        '<leader>ccv',
        ':CopilotChatVisual',
        mode = 'x',
        desc = 'CopilotChat - Open in vertical split',
      },
      {
        '<leader>ccx',
        ':CopilotChatInline<cr>',
        mode = 'x',
        desc = 'CopilotChat - Inline chat',
      },
      -- Custom input for CopilotChat
      {
        '<leader>cci',
        function()
          vim.ui.input('Ask Copilot: ', function(input)
            if input ~= '' then
              vim.cmd('CopilotChat ' .. input)
            end
          end)
        end,
        desc = 'CopilotChat - Ask input',
      },
      -- Generate commit message based on the git diff
      {
        '<leader>ccm',
        '<cmd>CopilotChatCommit<cr>',
        desc = 'CopilotChat - Generate commit message for all changes',
      },
      {
        '<leader>ccM',
        '<cmd>CopilotChatCommitStaged<cr>',
        desc = 'CopilotChat - Generate commit message for staged changes',
      },
      -- Quick chat with Copilot
      {
        '<leader>ccq',
        function()
          vim.ui.input('Quick Chat: ', function(input)
            if input ~= '' then
              vim.cmd('CopilotChatBuffer ' .. input)
            end
          end)
        end,
        desc = 'CopilotChat - Quick chat',
      },
    },
  },
}
