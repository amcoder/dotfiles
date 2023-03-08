local send_to_qflist = function(prompt_bufnr)
  local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)

  if next(picker:get_multi_selection()) ~= nil then
    require('telescope.actions').send_selected_to_qflist(prompt_bufnr)
  else
    require('telescope.actions').send_to_qflist(prompt_bufnr)
  end
  require('telescope.actions').open_qflist(prompt_bufnr)
end

local open_with_trouble = function(prompt_bufnr, _mode)
  require('trouble.providers.telescope').open_with_trouble(prompt_bufnr, _mode)
end

local cycle_layout = function(prompt_bufnr, _mode)
  require('telescope.actions.layout').cycle_layout_next(prompt_bufnr, _mode)
end

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
                ["<c-q>"] = send_to_qflist,
                ["<c-t>"] = open_with_trouble,
                ["<c-]>"] = cycle_layout,
          },
          n = {
                ["<M-q>"] = false,
                ["<c-q>"] = send_to_qflist,
                ["<c-t>"] = open_with_trouble,
                ["<c-]>"] = cycle_layout,
          }
        },
        path_display = {
          'truncate'
        },
        dynamic_preview_title = true,
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "-g",
          "!.git",
        },
        -- wrap_results = true,
      },
      pickers = {
        find_files = {
          find_command = { 'rg', '--files', '--hidden', '-g', '!.git' },
        },
        lsp_references = {
          fname_width = false
        },
        quickfix = {
          fname_width = false
        },
        loclist = {
          fname_width = false
        },
        jumplist = {
          fname_width = false
        },
      }
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
