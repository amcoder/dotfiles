return {
    -- Detect tabstop and shiftwidth automatically
    {
        'tpope/vim-sleuth',
        event = 'BufEnter',
    },
    {
        'tpope/vim-repeat',
    },
    {
        'tpope/vim-surround',
    },

    {
        'mbbill/undotree',
        cmd = { 'UndotreeShow', 'UndotreeHide', 'UndotreeFocus', 'UndotreeToggle' },
        keys = {
            { '<leader>u', vim.cmd.UndotreeToggle, desc = '[U]ndotree' },
        },
        config = function()
            vim.cmd([[ let g:undotree_SetFocusWhenToggle = 1 ]])
        end,
    },

    -- Useful plugin to show you pending keybinds.
    -- NOTE: opts purposely left empty
    {
        'folke/which-key.nvim',
        event = 'VeryLazy',
        opts = {},
    },

    {
        -- Add indentation guides even on blank lines
        'lukas-reineke/indent-blankline.nvim',
        main = 'ibl',
        event = 'BufEnter',
        opts = {
            indent = {
                char = '┊',
            }
        },
    },

    -- Nice select and input pupups
    { 'stevearc/dressing.nvim', event = 'VeryLazy' },

    -- Highlight word under cursor
    { 'RRethy/vim-illuminate',  event = 'VeryLazy' },
}
