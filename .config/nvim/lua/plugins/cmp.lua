return {
  { -- Autocompletion
    'hrsh7th/nvim-cmp',
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          -- Build Step is needed for regex support in snippets
          -- This step is not supported in many windows environments
          -- Remove the below condition to re-enable on windows
          if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = { 'rafamadriz/friendly-snippets' },
      },
      'saadparwaiz1/cmp_luasnip',

      -- Adds other completion capabilities.
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-emoji',
      'petertriho/cmp-git',

      -- Show lsp icons in the completion menu
      'onsails/lspkind.nvim',
    },
    keys = {
      {
        '<leader>C',
        function()
          vim.b.disable_cmp = not vim.b.disable_cmp
          print('Completion ' .. (vim.b.disable_cmp and 'disabled' or 'enabled'))
        end,
        mode = '',
        desc = 'Toggle Completion',
      },
    },
    config = function()
      -- See `:help cmp`
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      local lspkind = require('lspkind')

      luasnip.config.setup({})

      require('luasnip.loaders.from_vscode').lazy_load()

      cmp.setup({
        enabled = function()
          return vim.api.nvim_get_mode().mode == 'c' or not vim.b.disable_cmp
        end,
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = 'menu,menuone,noselect,noinsert' },
        formatting = {
          format = lspkind.cmp_format({
            mode = 'symbol_text',
            maxwidth = 50,
            ellipsis_char = '…',
            menu = {
              buffer = '[buf]',
              nvim_lsp = '[lsp]',
              luasnip = '[snip]',
              path = '[path]',
              cmdline = '[cmd]',
              git = '[git]',
            },
          }),
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        -- For an understanding of why these mappings were
        -- chosen, you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        mapping = cmp.mapping.preset.insert({
          ['<C-d>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),

          ['<C-Space>'] = cmp.mapping.complete({}),

          ['<Esc>'] = cmp.mapping.abort(),

          ['<C-c>'] = cmp.mapping(function()
            vim.b.disable_cmp = not vim.b.disable_cmp
            print('Completion ' .. (vim.b.disable_cmp and 'disabled' or 'enabled'))
            if vim.b.disable_cmp and cmp.visible() then
              cmp.abort()
            elseif not vim.b.disable_cmp and not cmp.visible() then
              cmp.complete({})
            end
          end, { 'i', 's' }),

          ['<C-e>'] = cmp.mapping.close(),

          ['<C-y>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
          }),

          ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
          }),

          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),

          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'emoji' },
          { name = 'path' },
        },
      })

      -- `/` cmdline setup.
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' },
        },
      })

      -- `:` cmdline setup.
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' },
        }, {
          {
            name = 'cmdline',
            option = {
              ignore_cmds = { 'Man', '!', 'GoTest', 'GoTestFunc', 'GoTestFile', 'GoTestPkg', 'GoTestSum' },
            },
          },
        }),
      })

      cmp.setup.filetype('gitcommit', {
        sources = cmp.config.sources({
          { name = 'git' },
        }, {
          { name = 'emoji' },
        }),
      })

      require('cmp_git').setup()
    end,
  },
}
