return {
  {
    "folke/trouble.nvim",
    event = 'VeryLazy',
    dependencies = {
      "nvim-tree/nvim-web-devicons"
    },
  },

  {
    'numToStr/Comment.nvim',
    event = 'VeryLazy',
    config = function()
      require('Comment').setup {
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
      }
    end
  },
  {
    'JoosepAlviste/nvim-ts-context-commentstring',
    lazy = true,
  },
}
