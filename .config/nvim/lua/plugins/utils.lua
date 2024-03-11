return {
    'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

    'tpope/vim-repeat', -- Additional key repeats

    -- Nice select and input pupups
    { 'stevearc/dressing.nvim', event = 'VeryLazy' },

    -- Highlight word under cursor
    { 'RRethy/vim-illuminate',  event = 'VeryLazy' },

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

    {                   -- Useful plugin to show you pending keybinds.
        'folke/which-key.nvim',
        event = 'VimEnter', -- Sets the loading event to 'VimEnter'
        config = function() -- This is the function that runs, AFTER loading
            require('which-key').setup()

            -- Document existing key chains
            require('which-key').register {
                ['<leader>c'] = { name = '[C]ode', _ = 'which_key_ignore' },
                ['<leader>d'] = { name = '[D]ocument', _ = 'which_key_ignore' },
                ['<leader>r'] = { name = '[R]ename', _ = 'which_key_ignore' },
                ['<leader>s'] = { name = '[S]earch', _ = 'which_key_ignore' },
                ['<leader>w'] = { name = '[W]orkspace', _ = 'which_key_ignore' },
            }
        end,
    },
}
