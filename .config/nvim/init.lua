vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Install package manager
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup('plugins')

-- [[ Setting options ]]
-- See `:help vim.o`

-- Set the colorscheme
-- vim.cmd.colorscheme 'nordfox'

-- Set highlight on search
vim.o.hlsearch = false
vim.o.incsearch = true

-- allow unsaved buffers to be hidden
vim.o.hidden = true

-- Make line numbers default
vim.wo.number = true
vim.wo.relativenumber = true

-- Cursor
vim.o.cursorline = true

-- Open splits right and below
vim.o.splitright = true
vim.o.splitbelow = true

-- indents
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.smartindent = true

vim.o.wrap = false

-- Enable mouse mode
vim.o.mouse = 'a'

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
-- vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- backup and undo
vim.o.swapfile = false
vim.o.backup = false
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
-- vim.o.ignorecase = true
-- vim.o.smartcase = true

-- Scrolling
vim.o.scrolloff = 8

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- Sign definitions
vim.fn.sign_define("DiagnosticSignError",
  { text = " ", texthl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn",
  { text = " ", texthl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo",
  { text = " ", texthl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint",
  { text = "", texthl = "DiagnosticSignHint" })

-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', 'Y', 'y$', { noremap = true, silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set('n', '<C-z>', '<C-a>', { noremap = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- See `:help telescope.builtin`
vim.keymap.set('n', '<leader>?', function()
  require('telescope.builtin').oldfiles({ cwd_only = true })
end, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader><space>', require('telescope.builtin').find_files, { desc = '[ ] Search Files' })
vim.keymap.set('n', '<leader>b', require('telescope.builtin').buffers, { desc = 'Search [B]uffers' })
vim.keymap.set('n', '<leader>/', function()
  -- You can pass additional configuration to telescope to change theme, layout, etc.
  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })

vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>st', require('telescope.builtin').treesitter, { desc = '[S]earch [T]reesitter' })
vim.keymap.set('n', '<leader>sr', require('telescope.builtin').resume, { desc = '[S]earch [R]esume' })

-- [[ Trouble ]]
vim.keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>", { silent = true, noremap = true, desc = '[T]rouble' })
vim.keymap.set("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>",
  { silent = true, noremap = true, desc = 'Trouble [W]orkspace Diagnostics' })
vim.keymap.set("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>",
  { silent = true, noremap = true, desc = 'Trouble [D]ocument Diagnostics' })
vim.keymap.set("n", "<leader>xl", "<cmd>TroubleToggle loclist<cr>",
  { silent = true, noremap = true, desc = 'Trouble [L]ocation List' })
vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>",
  { silent = true, noremap = true, desc = 'Trouble LSP [Q]uickfix List' })
vim.keymap.set("n", "<leader>xr", "<cmd>TroubleToggle lsp_references<cr>",
  { silent = true, noremap = true, desc = 'Trouble LSP [R]eferences' })
vim.keymap.set("n", "<leader>xt", "<cmd>TroubleToggle telescope<cr>",
  { silent = true, noremap = true, desc = 'Trouble [T]elescope' })
vim.keymap.set("n", "]c", function() require("trouble").next({ skip_groups = true, jump = true }); end,
  { silent = true, noremap = true, desc = 'Trouble Next' })
vim.keymap.set("n", "[c", function() require("trouble").previous({ skip_groups = true, jump = true }); end,
  { silent = true, noremap = true, desc = 'Trouble Previous' })
vim.keymap.set("n", "]C", function() require("trouble").last({ skip_groups = true, jump = true }); end,
  { silent = true, noremap = true, desc = 'Trouble Last' })
vim.keymap.set("n", "[C", function() require("trouble").first({ skip_groups = true, jump = true }); end,
  { silent = true, noremap = true, desc = 'Trouble First' })

-- [[ Configure Neotree ]]
vim.keymap.set('n', '<leader>tt', ":Neotree toggle<cr>", { desc = 'Neo[t]ree [T]oggle', silent = true })
vim.keymap.set('n', '<leader>tr', ":Neotree reveal<cr>", { desc = 'Neo[t]ree [R]eveal', silent = true })
vim.keymap.set('n', '<leader>tf', ":Neotree filesystem<cr>", { desc = 'Neo[t]ree [F]iles', silent = true })
vim.keymap.set('n', '<leader>tb', ":Neotree buffers<cr>", { desc = 'Neo[t]ree [B]uffers', silent = true })
vim.keymap.set('n', '<leader>tg', ":Neotree git_status<cr>", { desc = 'Neo[t]ree [G]it', silent = true })

-- [[ Configure Fugitive ]]
vim.keymap.set('n', '<leader>gs', ":G<cr>", { desc = '[G]it [S]tatus', silent = true })
vim.keymap.set('n', '<leader>gb', ":Git blame<cr>", { desc = '[G]it [B]lame', silent = true })
vim.keymap.set('v', '<leader>gb', ":'<,'>Git blame<cr>", { desc = '[G]it [B]lame', silent = true })
vim.keymap.set('n', '<leader>gd', ":Git diffsplit<cr>", { desc = '[G]it [B]lame', silent = true })
vim.keymap.set('n', '<leader>gl', ":GBrowse!<cr>", { desc = '[G]it[h]ub', silent = false })
vim.keymap.set('v', '<leader>gl', ":'<,'>GBrowse!<cr>", { desc = '[G]it[h]ub', silent = false })

-- [[ Configure undotree ]]
vim.cmd([[ let g:undotree_SetFocusWhenToggle = 1 ]])
vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle, { desc = '[U]ndotree' })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })
