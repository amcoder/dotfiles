return {
  {
    -- NeoTree
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    event = 'VeryLazy',
    opts = {
      close_if_last_window = false,
      use_popups_for_input = false,
      popup_border_style = 'rounded',
      open_files_do_not_replace_types = { 'terminal', 'Trouble', 'qf', 'help', 'fugitive' },
    },
    config = function(_, opts)
      vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])

      require('neo-tree').setup(opts)

      vim.keymap.set('n', '<leader>tt', ':Neotree toggle<cr>', { desc = 'Neo[t]ree [T]oggle', silent = true })
      vim.keymap.set('n', '<leader>tr', ':Neotree reveal<cr>', { desc = 'Neo[t]ree [R]eveal', silent = true })
      vim.keymap.set('n', '<leader>tf', ':Neotree filesystem<cr>', { desc = 'Neo[t]ree [F]iles', silent = true })
      vim.keymap.set('n', '<leader>tb', ':Neotree buffers<cr>', { desc = 'Neo[t]ree [B]uffers', silent = true })
      vim.keymap.set('n', '<leader>tg', ':Neotree git_status<cr>', { desc = 'Neo[t]ree [G]it', silent = true })
    end,
  },
}
