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
      })

      vim.keymap.set('n', '<leader>tt', neotest.run.run, { desc = 'Run [T]est' })
      vim.keymap.set('n', '<leader>tf', function()
        neotest.run.run(vim.fn.expand('%'))
      end, { desc = '[T]est [F]ile' })
      vim.keymap.set('n', '<leader>ta', function()
        neotest.run.run(vim.fn.getcwd())
      end, { desc = '[T]est [A]ll' })

      vim.keymap.set('n', '<leader>to', neotest.output.open, { desc = 'Test [O]utput' })
      vim.keymap.set('n', '<leader>tp', neotest.output_panel.toggle, { desc = 'Test [P]anel' })
      vim.keymap.set('n', '<leader>ts', neotest.summary.toggle, { desc = 'Test [S]ummary' })
    end,
  },
}
