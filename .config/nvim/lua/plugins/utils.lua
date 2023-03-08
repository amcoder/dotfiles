return {
  -- Detect tabstop and shiftwidth automatically
  {
    'tpope/vim-sleuth',
    event = 'BufEnter',
  },
  {
    'tpope/vim-repeat',
  },
  {
    'tpope/vim-surround',
  },

  {
    'mbbill/undotree',
    cmd = { 'UndotreeShow', 'UndotreeHide', 'UndotreeFocus', 'UndotreeToggle' },
  },

  -- Useful plugin to show you pending keybinds.
  -- NOTE: opts purposely left empty
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
  },

  {
    -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    event = 'BufEnter',
    opts = {
      char = '┊',
      show_trailing_blankline_indent = false,
      show_current_context = true,
    },
  },

  -- Nice select and input pupups
  { 'stevearc/dressing.nvim', event = 'VeryLazy' },

  -- Highlight word under cursor
  { 'RRethy/vim-illuminate',  event = 'VeryLazy' },
}
