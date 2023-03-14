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
      },
      pickers = {
        find_files = {
          find_command = { 'rg', '--files', '--hidden', '-g', '!.git' },
        },
        oldfiles = {
          cwd_only = true,
        },
        buffers = {
          sort_mru = true,
          ignore_current_buffer = true,
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
      local builtin = require('telescope.builtin')

      telescope.setup(opts)

      -- See `:help telescope.builtin`
      vim.keymap.set('n', '<leader><space>', builtin.find_files, { desc = '[ ] Search Files' })
      vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'Search [B]uffers' })
      vim.keymap.set('n', '<leader>?', builtin.oldfiles, { desc = '[?] Find recently opened files' })
      vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find,
        { desc = '[/] Fuzzily search in current buffer' })

      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })

      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })

      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>st', builtin.treesitter, { desc = '[S]earch [T]reesitter' })

      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader>sM', builtin.marks, { desc = '[S]earch [M]arks' })
      vim.keymap.set('n', '<leader>SM', builtin.marks, { desc = '[S]earch [M]arks' })
      vim.keymap.set('n', '<leader>sR', builtin.registers, { desc = '[S]earch [R]egisters' })
      vim.keymap.set('n', '<leader>SR', builtin.registers, { desc = '[S]earch [R]egisters' })
      vim.keymap.set('n', '<leader>sJ', builtin.jumplist, { desc = '[S]earch [J]umplist' })
      vim.keymap.set('n', '<leader>SJ', builtin.jumplist, { desc = '[S]earch [J]umplist' })
      vim.keymap.set('n', '<leader>sL', builtin.loclist, { desc = '[S]earch [L]oclist' })
      vim.keymap.set('n', '<leader>SL', builtin.loclist, { desc = '[S]earch [L]oclist' })
      vim.keymap.set('n', '<leader>sQ', builtin.quickfix, { desc = '[S]earch [Q]uickfix' })
      vim.keymap.set('n', '<leader>SQ', builtin.quickfix, { desc = '[S]earch [Q]uickfix' })

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
