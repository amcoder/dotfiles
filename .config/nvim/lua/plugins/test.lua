return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',

      'Issafalcon/neotest-dotnet',
    },
    config = function()
      local neotest = require('neotest')

      neotest.setup({
        adapters = {
          require('neotest-dotnet')({
            dap = {
              args = { justMyCode = false },
              adapter_name = 'coreclr',
            },
            discovery_root = 'solution',
          }),
        },
        discovery = {
          concurrent = 4,
        },
        output = {
          open_on_run = true,
        },
        consumers = {
          overseer = require('neotest.consumers.overseer'),
        },
      })

      vim.keymap.set('n', '<leader>rt', neotest.run.run, { desc = '[R]un Nearest [T]est' })
      vim.keymap.set('n', '<leader>rd', function()
        neotest.run.run({ strategy = 'dap' })
      end, { desc = '[R]un Nearest Test [D]ebug' })
      vim.keymap.set('n', '<leader>rf', function()
        neotest.run.run(vim.fn.expand('%'))
      end, { desc = '[R]un Tests in [F]ile' })
      vim.keymap.set('n', '<leader>ra', function()
        neotest.run.run(vim.fn.getcwd())
      end, { desc = '[R]un [A]ll Tests' })

      vim.keymap.set('n', '<leader>to', neotest.output.open, { desc = 'Test [O]utput' })
      vim.keymap.set('n', '<leader>tp', neotest.output_panel.toggle, { desc = 'Test [P]anel' })
      vim.keymap.set('n', '<leader>ts', neotest.summary.toggle, { desc = 'Test [S]ummary' })
    end,
  },
}
