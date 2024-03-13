return {
  {
    'stevearc/overseer.nvim',
    opts = {},
    config = function(_, opts)
      local overseer = require('overseer')
      overseer.setup(opts)

      -- Set the dap JSON decoder to the one from overseer
      require('dap.ext.vscode').json_decode = require('overseer.json').decode

      local run_build = function()
        overseer.run_template({ tags = { overseer.TAG.BUILD } })
      end

      vim.keymap.set('n', '<leader>rr', overseer.run_template, { desc = '[R]un Task' })
      vim.keymap.set('n', '<leader>rb', run_build, { desc = '[R]un [B]uild Task' })
      vim.keymap.set('n', '<leader>rs', overseer.toggle, { desc = 'Open [R]un [S]ummary' })
    end,
  },
}
