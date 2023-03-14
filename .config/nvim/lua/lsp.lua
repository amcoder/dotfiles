return {
  attach = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lsp-attach-keymap', { clear = true }),
      -- This is where we attach the autoformatting for reasonable clients
      callback = function(args)
        local bufnr = args.buf

        local nmap = function(keys, func, desc)
          if desc then
            desc = 'LSP: ' .. desc
          end

          vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
        end

        nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ctions')

        nmap('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
        nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        nmap('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        nmap('gt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

        nmap('<leader>ss', require('telescope.builtin').lsp_document_symbols, 'Document [S]ymbols')
        nmap('<leader>sW', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace Symbols')
        nmap('<leader>SW', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace Symbols')

        nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
        nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

        nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
        nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
        nmap('<leader>wl', function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, '[W]orkspace [L]ist Folders')

        -- Create a command `:Format` local to the LSP buffer
        vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
          vim.lsp.buf.format()
        end, { desc = 'Format current buffer with LSP' })
        nmap('<leader>f', '<cmd>Format<cr>', '[F]ormat')
        nmap('<leader>F', '<cmd>AutoformatToggle<cr>', 'Auto[F]ormat Toggle')
      end,
    })
  end
}
