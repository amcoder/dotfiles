return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format({ async = true, lsp_fallback = true })
        end,
        mode = '',
        desc = 'Format buffer',
      },
      {
        '<leader>F',
        function()
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          print('Autoformat: ' .. tostring(not vim.b.disable_autoformat))
        end,
        mode = '',
        desc = 'Toggle Autoformat',
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
        typescript = { { 'prettierd', 'prettier' } },
        typescriptreact = { { 'prettierd', 'prettier' } },
        javascript = { { 'prettierd', 'prettier' } },
        javascriptreact = { { 'prettierd', 'prettier' } },
        json = { { 'prettierd', 'prettier' } },
        css = { { 'prettierd', 'prettier' } },
        yaml = { { 'prettierd', 'prettier' } },
        markdown = { { 'prettierd', 'prettier' } },
      },
      formatters = {
        jq = {
          args = function(_, ctx)
            -- Add editorconfig support to jq
            local result = {}
            if vim.b[ctx.buf].editorconfig then
              if vim.b[ctx.buf].editorconfig.indent_style == 'tab' then
                table.insert(result, '--tab')
              elseif vim.b[ctx.buf].editorconfig.indent_size then
                table.insert(result, '--indent')
                table.insert(result, vim.b[ctx.buf].editorconfig.indent_size)
              end
            end
            return result
          end,
        },
      },
    },
  },
}
