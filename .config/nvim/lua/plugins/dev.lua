return {
    { 'numToStr/Comment.nvim', opts = {} },

    -- Highlight todo, notes, etc in comments
    {
        'folke/todo-comments.nvim',
        event = 'VimEnter',
        dependencies = { 'nvim-lua/plenary.nvim' },
        opts = { signs = false }
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
}
