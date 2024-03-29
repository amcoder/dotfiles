return {
  {
    'EdenEast/nightfox.nvim',
    priority = 1000, -- make sure to load this before all the other start plugins
    opts = {
      options = {
        styles = {
          comments = 'italic',
        },
      },
    },
    config = function(_, opts)
      require('nightfox').setup(opts)
      vim.cmd.colorscheme('nordfox')
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
      sections = {
        lualine_a = {
          {
            'mode',
            fmt = function(res)
              return res:sub(1, 1)
            end,
          },
        },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'overseer', 'filetype' },
      },
    },
  },
}
