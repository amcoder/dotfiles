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
      groups = {
        all = {
          CursorLine = { bg = 'bg2' },
        },
      },
    },
    config = function(_, opts)
      require('nightfox').setup(opts)
      -- vim.cmd.colorscheme('nordfox')
    end,
  },

  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      flavour = 'macchiato',
      integrations = {
        diffview = true,
        fidget = true,
        mason = true,
        neotree = true,
        neotest = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { 'undercurl' },
            hints = { 'undercurl' },
            warnings = { 'undercurl' },
            information = { 'undercurl' },
          },
        },
        notify = true,
        overseer = true,
        which_key = true,
      },
      custom_highlights = function(C)
        return {
          ['@lsp.type.property.cs'] = { fg = C.blue },
          ['@lsp.type.constantName'] = { link = '@constant' },
          ['@lsp.type.fieldName'] = { link = '@variable.member' },
        }
      end,
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      vim.cmd.colorscheme('catppuccin')
    end,
  },

  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    opts = {
      options = {
        theme = 'catppuccin',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        ignore_focus = {
          'neo-tree',
        },
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
