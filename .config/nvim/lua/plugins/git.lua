return {
  {
    'tpope/vim-fugitive',
    event = 'VeryLazy',
    config = function()
      vim.keymap.set('n', '<leader>gs', ':G<cr>', { desc = '[G]it [S]tatus', silent = true })
      vim.keymap.set('n', '<leader>gb', ':Git blame<cr>', { desc = '[G]it [B]lame', silent = true })
      vim.keymap.set('v', '<leader>gb', ":'<,'>Git blame<cr>", { desc = '[G]it [B]lame', silent = true })
      vim.keymap.set('n', '<leader>gd', ':Gvdiffsplit<cr>', { desc = '[G]it [D]iff', silent = true })
      vim.keymap.set('n', '<leader>gl', ':GBrowse!<cr>', { desc = '[G]it[h]ub', silent = false })
      vim.keymap.set('v', '<leader>gl', ":'<,'>GBrowse!<cr>", { desc = '[G]it[h]ub', silent = false })
    end,
  },

  { 'tpope/vim-rhubarb', event = 'VeryLazy' },

  -- Add bitbuicket support to fugitive
  'tommcdo/vim-fubitive',

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            return ']c'
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return '<Ignore>'
        end, { desc = 'Next [c]hange', expr = true })

        map('n', '[c', function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return '<Ignore>'
        end, { desc = 'Previous [c]hange', expr = true })

        -- Actions
        map('n', '<leader>hs', gs.stage_hunk, { desc = '[S]tage hunk' })
        map('n', '<leader>hr', gs.reset_hunk, { desc = '[R]eset hunk' })
        map('v', '<leader>hs', function()
          gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
        end, { desc = '[S]tage hunk' })
        map('v', '<leader>hr', function()
          gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
        end, { desc = '[R]eset hunk' })
        map('n', '<leader>hS', gs.stage_buffer, { desc = '[S]tage buffer' })
        map('n', '<leader>hu', gs.undo_stage_hunk, { desc = '[U]ndo stage hunk' })
        map('n', '<leader>hR', gs.reset_buffer, { desc = '[R]eset buffer' })
        map('n', '<leader>hp', gs.preview_hunk, { desc = '[P]review hunk' })
        map('n', '<leader>hb', gs.blame_line, { desc = '[B]lame line' })
        map('n', '<leader>hd', gs.diffthis, { desc = '[D]iff hunk' })
        map('n', '<leader>hD', function()
          gs.diffthis('~')
        end, { desc = '[D]iff hunk ~' })

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
        map({ 'o', 'x' }, 'ah', ':<C-U>Gitsigns select_hunk<CR>')
      end,
    },
  },
}
