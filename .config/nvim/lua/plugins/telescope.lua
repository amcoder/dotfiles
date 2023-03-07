return {
  -- Fuzzy Finder (files, lsp, etc)
  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'folke/trouble.nvim'
    },
    event = 'VeryLazy',
    opts = {
      defaults = {
        mappings = {
          i = {
                ['<C-u>'] = false,
                ['<C-d>'] = false,
                ["<c-t>"] = function(prompt_bufnr, _mode)
              require('trouble.providers.telescope').open_with_trouble(prompt_bufnr, _mode)
            end,
          },
          n = {
                ["<c-t>"] = function(prompt_bufnr, _mode)
              require('trouble.providers.telescope').open_with_trouble(prompt_bufnr, _mode)
            end,
          }
        },
      },
    },
    config = function(_, opts)
      local telescope = require('telescope')

      telescope.setup(opts)

      -- Enable telescope fzf native, if installed
      pcall(telescope.load_extension, 'fzf')
    end
  },

  -- Fuzzy Finder Algorithm which requires local dependencies to be built.
  -- Only load if `make` is available. Make sure you have the system
  -- requirements installed.
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    -- NOTE: If you are having trouble with this installation,
    --       refer to the README for telescope-fzf-native for more instructions.
    build = 'make',
    cond = function()
      return vim.fn.executable 'make' == 1
    end,
  },

}
