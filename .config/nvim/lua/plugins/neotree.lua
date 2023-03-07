return {
  {
    -- NeoTree
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v2.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = 'Neotree',
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
    },
    config = function(_, opts)
      vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])
      require('neo-tree').setup(opts)
    end
  },

}
