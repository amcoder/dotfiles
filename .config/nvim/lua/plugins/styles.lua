return {
  -- Color schemes
  { 'navarasu/onedark.nvim', lazy = true },
  { 'gbprod/nord.nvim',      lazy = true },
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'nordfox'
    end,
  },

  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    opts = {
      options = {
        theme = 'nordfox',
      },
    },
  },
}
