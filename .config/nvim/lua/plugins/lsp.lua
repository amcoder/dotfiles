return {
  { -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for neovim
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Extend omnisharp
      'Hoffs/omnisharp-extended-lsp.nvim',

      -- Extend csharpls
      -- 'Decodetalkers/csharpls-extended-lsp.nvim',

      -- roslyn LS
      -- 'jmederosalvarado/roslyn.nvim',
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then
            return
          end

          if client.name == 'omnisharp' then
            -- override keys for omnisharp so that we can go to decompied code
            map('gd', require('omnisharp_extended').telescope_lsp_definition, '[G]oto [D]efinition')
            map('<C-]>', require('omnisharp_extended').telescope_lsp_definition, '[G]oto [D]efinition')
            map(
              '<C-LeftMouse>',
              "<LeftMouse><cmd>lua require('omnisharp_extended').telescope_lsp_definition()<CR>",
              '[G]oto [D]efinition'
            )
            map('gr', require('omnisharp_extended').telescope_lsp_references, '[G]oto [R]eferences')
            map('gi', require('omnisharp_extended').telescope_lsp_implementation, '[G]oto [I]mplementation')
            map('gt', require('omnisharp_extended').telescope_lsp_type_definition, '[G]oto [T]ype Definition')
          else
            -- Jump to the definition of the word under your cursor.
            --  This is where a variable was first declared, or where a function is defined, etc.
            --  To jump back, press <C-T>.
            if client.server_capabilities.definitionProvider then
              map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
              map('<C-]>', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
              map(
                '<C-LeftMouse>',
                "<LeftMouse><cmd>lua require('telescope.builtin').lsp_definitions()<CR>",
                '[G]oto [D]efinition'
              )
            end

            -- Find references for the word under your cursor.
            if client.server_capabilities.referencesProvider then
              map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
            end

            -- Jump to the implementation of the word under your cursor.
            --  Useful when your language has ways of declaring types without an actual implementation.
            if client.server_capabilities.implementationProvider then
              map('gi', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
            end

            -- Jump to the type of the word under your cursor.
            --  Useful when you're not sure what type a variable is and you want to see
            --  the definition of its *type*, not where it was *defined*.
            if client.server_capabilities.typeDefinitionProvider then
              map('gt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')
            end
          end

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          if client.server_capabilities.documentSymbolProvider then
            map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
          end

          -- Fuzzy find all the symbols in your current workspace
          --  Similar to document symbols, except searches over your whole project.
          if client.server_capabilities.workspaceSymbolProvider then
            map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          end

          -- Rename the variable under your cursor
          --  Most Language Servers support renaming across files, etc.
          if client.server_capabilities.renameProvider then
            map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
          end

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          if client.server_capabilities.codeActionProvider then
            map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
          end

          -- Opens a popup that displays documentation about the word under your cursor
          --  See `:help K` for why this keymap
          if client.server_capabilities.hoverProvider then
            map('K', vim.lsp.buf.hover, 'Hover Documentation')
          end

          -- Opens a popup that displays documentation about the word under your cursor
          --  See `:help K` for why this keymap
          if client.server_capabilities.signatureHelpProvider then
            map('<C-s>', vim.lsp.buf.signature_help, 'Signature Help')
          end

          -- This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          if client.server_capabilities.documentHighlightProvider then
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              callback = vim.lsp.buf.clear_references,
            })
          end

          if client.server_capabilities.signatureHelpProvider then
            require('lsp-overloads').setup(client, {
              ui = {
                border = 'none',
                max_width = 120,
                max_height = 20,
              },
              keymaps = {
                next_signature = '<C-j>',
                previous_signature = '<C-k>',
                next_parameter = '<C-l>',
                previous_parameter = '<C-h>',
                close_signature = '<C-s>',
              },
            })

            vim.keymap.set({ 'n', 'i' }, '<C-s>', '<cmd>LspOverloadsSignature<CR>', {
              noremap = true,
              silent = true,
              buffer = event.buf,
              desc = 'Show LSP signature help',
            })
          end
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP Specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        clangd = { cmd = { 'clangd', '--offset-encoding=utf-16' } },
        bashls = {},
        dockerls = {},
        docker_compose_language_service = {},
        rust_analyzer = {},
        gopls = {},
        tsserver = {
          settings = {
            diagnostics = {
              ignoredCodes = { 6133 },
            },
          },
        },
        omnisharp = {
          autostart = true,
          handlers = {
            ['textDocument/publishDiagnostics'] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
              -- Roslyn hidden analytics come in as hints, so make then a bit quieter.
              underline = {
                severity = { min = vim.diagnostic.severity.INFO },
              },
              virtual_text = {
                severity = { min = vim.diagnostic.severity.INFO },
              },
            }),
          },
          settings = {
            FormattingOptions = {
              EnableEditorConfigSupport = true,
              OrganizeImports = true,
            },
            RoslynExtensionsOptions = {
              EnableAnalyzersSupport = true,
              EnableImportCompletion = true,
              EnableDecompilationSupport = true,
            },
            Sdk = {
              -- Specifies whether to include preview versions of the .NET SDK when
              -- determining which version to use for project loading.
              IncludePrereleases = true,
            },
          },
          keymaps = {},
        },
        -- csharp_ls = {
        --   autostart = false,
        --   handlers = {
        --     ['textDocument/definition'] = require('csharpls_extended').handler,
        --     ['textDocument/typeDefinition'] = require('csharpls_extended').handler,
        --   },
        --   keymaps = {
        --     {
        --       'gd',
        --       function()
        --         vim.lsp.buf.definition()
        --       end,
        --       '[G]oto [D]efinition',
        --     },
        --     { '<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition' },
        --   },
        -- },
        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = 'LuaJIT' },
              workspace = {
                checkThirdParty = false,
                -- Tells lua_ls where to find all the Lua files that you have loaded
                -- for your neovim configuration.
                library = {
                  '${3rd}/luv/library',
                  ---@diagnostic disable-next-line: deprecated
                  unpack(vim.api.nvim_get_runtime_file('', true)),
                },
                -- If lua_ls is really slow on your computer, you can try this instead:
                -- library = { vim.env.VIMRUNTIME },
              },
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              diagnostics = { disable = { 'missing-fields' } },
              format = {
                enable = false,
                defaultConfig = {
                  indent_style = 'space',
                  indent_size = '2',
                },
              },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --  To check the current status of installed tools and/or manually install
      --  other tools, you can run
      --    :Mason
      --
      --  You can press `g?` for help in this menu
      require('mason').setup()

      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format lua code
      })
      require('mason-tool-installer').setup({ ensure_installed = ensure_installed })

      require('mason-lspconfig').setup({
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for tsserver)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      })

      -- setup the roslyn LSP client
      -- require('roslyn').setup({
      --   dotnet_cmd = 'dotnet', -- this is the default
      --   -- 4.10.0-2.24124.2
      --   -- 4.8.0-3.23475.7 (default)
      --   roslyn_version = '4.10.0-2.24124.2',
      --   on_attach = function() end, -- required
      --   capabilities = capabilities, -- required
      -- })
    end,
  },

  -- {
  --   'ray-x/lsp_signature.nvim',
  --   event = 'VeryLazy',
  --   opts = {
  --     doc_lines = 20,
  --     max_width = 120,
  --     hint_enable = false,
  --     hint_inline = function()
  --       return true
  --     end,
  --     hint_prefix = '➡️ ',
  --     padding = ' ',
  --     handler_opts = {
  --       border = 'none',
  --     },
  --     toggle_key = '<C-s>',
  --     select_signature_key = '<C-k>',
  --   },
  --   config = function(_, opts)
  --     require('lsp_signature').setup(opts)
  --   end,
  -- },

  {
    'Issafalcon/lsp-overloads.nvim',
  },
}
