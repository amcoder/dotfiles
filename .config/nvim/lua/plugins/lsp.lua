return {
  {
    -- omnisharp-extended
    "Hoffs/omnisharp-extended-lsp.nvim",
  },

  {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs to stdpath for neovim
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',

      -- Useful status updates for LSP
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      { 'j-hui/fidget.nvim', opts = {} },

      -- Additional lua configuration, makes nvim stuff amazing!
      'folke/neodev.nvim',
    },
    config = function()
      require('autoformat').attach()
      require('lsp').attach()
    end
  },

  {
    'williamboman/mason.nvim',
    config = function()
      -- LSP settings.

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. They will be passed to
      --  the `settings` field of the server config. You must look up that documentation yourself.
      local servers = {
        eslint = {},
        gopls = {},
        rust_analyzer = {},
        omnisharp = {
          handlers = {
            ["textDocument/definition"] = require('omnisharp_extended').handler,
            ["textDocument/publishDiagnostics"] = vim.lsp.with(
              vim.lsp.diagnostic.on_publish_diagnostics, {
                underline = {
                  severity = { min = vim.diagnostic.severity.INFO },
                },
                virtual_text = {
                  severity = { min = vim.diagnostic.severity.INFO },
                },
              }
            )
          },
          enable_roslyn_analyzers = true,
          organize_imports_on_format = true,
          enable_import_completion = true,
        },
        lua_ls = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
            diagnostics = {
              globals = { 'vim' }
            }
          },
        },
      }

      -- nvim-cmp supports additional completion capabilities, so broadcast that to servers
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

      -- Setup mason so it can manage external tooling
      require('mason').setup()

      -- Ensure the servers above are installed
      local mason_lspconfig = require 'mason-lspconfig'

      mason_lspconfig.setup {
        ensure_installed = vim.tbl_keys(servers),
      }

      mason_lspconfig.setup_handlers {
        function(server_name)
          if server_name == "omnisharp" then
            require('lspconfig')[server_name].setup(servers[server_name])
          else
            require('lspconfig')[server_name].setup {
              capabilities = capabilities,
              settings = servers[server_name],
            }
          end
        end,
      }
    end
  },

  {
    -- null-ls
    "jose-elias-alvarez/null-ls.nvim",
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          -- null_ls.builtins.code_actions.eslint_d,
          null_ls.builtins.formatting.prettierd,
        }
      })
    end
  },

}
