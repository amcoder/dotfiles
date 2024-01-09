return {
  {
    'tpope/vim-fugitive',
    event = 'VeryLazy',
    config = function()
      vim.keymap.set('n', '<leader>gs', ":G<cr>", { desc = '[G]it [S]tatus', silent = true })
      vim.keymap.set('n', '<leader>gb', ":Git blame<cr>", { desc = '[G]it [B]lame', silent = true })
      vim.keymap.set('v', '<leader>gb', ":'<,'>Git blame<cr>", { desc = '[G]it [B]lame', silent = true })
      vim.keymap.set('n', '<leader>gd', ":Gvdiffsplit<cr>", { desc = '[G]it [D]iff', silent = true })
      vim.keymap.set('n', '<leader>gl', ":GBrowse!<cr>", { desc = '[G]it[h]ub', silent = false })
      vim.keymap.set('v', '<leader>gl', ":'<,'>GBrowse!<cr>", { desc = '[G]it[h]ub', silent = false })
    end,
  },
  { 'tpope/vim-rhubarb', event = 'VeryLazy' },

  {
    -- Adds git releated signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    event = 'VeryLazy',
    opts = {
      -- See `:help gitsigns.txt`
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
        map('n', ']h', function()
          if vim.wo.diff then return ']h' end
          vim.schedule(function() gs.next_hunk() end)
          return '<Ignore>'
        end, { expr = true })

        map('n', '[h', function()
          if vim.wo.diff then return '[h' end
          vim.schedule(function() gs.prev_hunk() end)
          return '<Ignore>'
        end, { expr = true })

        -- Actions
        map({ 'n', 'v' }, '<leader>hs', ':Gitsigns stage_hunk<CR>', { desc = 'Stage hunk' })
        map({ 'n', 'v' }, '<leader>hr', ':Gitsigns reset_hunk<CR>', { desc = 'Reset hunk' })
        map('n', '<leader>hS', gs.stage_buffer, { desc = 'Stage Buffer' })
        map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'Undo stage hunk' })
        map('n', '<leader>hR', gs.reset_buffer, { desc = 'Reset buffer' })
        map('n', '<leader>hp', gs.preview_hunk, { desc = 'Preview hunk' })
        map('n', '<leader>hb', function() gs.blame_line { full = true } end, { desc = 'Blame line' })
        map('n', '<leader>hd', gs.diffthis, { desc = 'Diff hunk' })
        map('n', '<leader>hD', function() gs.diffthis('~') end, { desc = 'Diff hunk ~' })

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
      end,
    },
  },
}
