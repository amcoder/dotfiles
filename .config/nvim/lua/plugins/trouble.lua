return {
  {
    'folke/trouble.nvim',
    event = 'VeryLazy',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    config = function(_, opts)
      require('trouble').setup(opts)

      vim.keymap.set('n', '<leader>xx', '<cmd>TroubleToggle<cr>', { silent = true, noremap = true, desc = '[T]rouble' })
      vim.keymap.set(
        'n',
        '<leader>xw',
        '<cmd>TroubleToggle workspace_diagnostics<cr>',
        { silent = true, noremap = true, desc = 'Trouble [W]orkspace Diagnostics' }
      )
      vim.keymap.set(
        'n',
        '<leader>xd',
        '<cmd>TroubleToggle document_diagnostics<cr>',
        { silent = true, noremap = true, desc = 'Trouble [D]ocument Diagnostics' }
      )
      vim.keymap.set(
        'n',
        '<leader>xl',
        '<cmd>TroubleToggle loclist<cr>',
        { silent = true, noremap = true, desc = 'Trouble [L]ocation List' }
      )
      vim.keymap.set(
        'n',
        '<leader>xq',
        '<cmd>TroubleToggle quickfix<cr>',
        { silent = true, noremap = true, desc = 'Trouble LSP [Q]uickfix List' }
      )
      vim.keymap.set(
        'n',
        '<leader>xr',
        '<cmd>TroubleToggle lsp_references<cr>',
        { silent = true, noremap = true, desc = 'Trouble LSP [R]eferences' }
      )
      vim.keymap.set(
        'n',
        '<leader>xt',
        '<cmd>TroubleToggle telescope<cr>',
        { silent = true, noremap = true, desc = 'Trouble [T]elescope' }
      )
      vim.keymap.set('n', ']c', function()
        require('trouble').next({ skip_groups = true, jump = true })
      end, { silent = true, noremap = true, desc = 'Trouble Next' })
      vim.keymap.set('n', '[c', function()
        require('trouble').previous({ skip_groups = true, jump = true })
      end, { silent = true, noremap = true, desc = 'Trouble Previous' })
      vim.keymap.set('n', ']C', function()
        require('trouble').last({ skip_groups = true, jump = true })
      end, { silent = true, noremap = true, desc = 'Trouble Last' })
      vim.keymap.set('n', '[C', function()
        require('trouble').first({ skip_groups = true, jump = true })
      end, { silent = true, noremap = true, desc = 'Trouble First' })
    end,
  },
}
