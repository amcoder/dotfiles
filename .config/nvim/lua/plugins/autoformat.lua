return {
    { -- Autoformat
        'stevearc/conform.nvim',
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        keys = {
            {
                "<leader>f",
                function()
                    require("conform").format({ async = true, lsp_fallback = true })
                end,
                mode = "",
                desc = "Format buffer",
            },
            {
                "<leader>F",
                function()
                    vim.b.disable_autoformat = not vim.b.disable_autoformat
                    print('Autoformat: ' .. tostring(not vim.b.disable_autoformat))
                end,
                mode = "",
                desc = "Toggle Autoformat",
            },
        },
        opts = {
            notify_on_error = false,
            format_on_save = function(bufnr)
                if vim.b[bufnr].disable_autoformat then
                    return
                end
                return { timeout_ms = 500, lsp_fallback = true }
            end,
            formatters_by_ft = {
                lua = { 'stylua' },
                json = { 'jq' },
                -- Conform can also run multiple formatters sequentially
                -- python = { "isort", "black" },
                --
                -- You can use a sub-list to tell conform to run *until* a formatter
                -- is found.
                -- javascript = { { "prettierd", "prettier" } },
            },
        },
    },
}
