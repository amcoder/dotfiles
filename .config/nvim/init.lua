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
vim.o.scrolloff = 5

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menu,menuone,noselect,noinsert'

-- Show only a global status bar
vim.o.laststatus = 3

-- Spell check
vim.o.spell = true
vim.o.spelllang = 'en_us'
vim.o.spelloptions = 'camel'
local spellfile = vim.fn.stdpath('config') .. '/spell/en.utf-8.add'
vim.o.spellfile = spellfile
if vim.fn.getftime(spellfile) > vim.fn.getftime(spellfile .. '.spl') then
  vim.cmd(':silent mkspell! ' .. spellfile)
end

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

-- Remap C-a because tmux
vim.keymap.set('n', '<C-z>', '<C-a>', { noremap = true })

-- Stay centered
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')
vim.keymap.set('n', '*', '*zzzv')
vim.keymap.set('n', '#', '*zzzv')

-- Alternate filter
vim.keymap.set("n", '<bs>', '<C-^>')

-- Kep selection when shifting
vim.keymap.set("v", '>', '>gv')
vim.keymap.set("v", '<', '<gv')

-- System clipboard support
vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]])
vim.keymap.set({ 'n', 'v' }, '<leader>Y', [["+y$]])
vim.keymap.set({ 'n', 'v' }, '<leader>d', [["+d]])
vim.keymap.set({ 'n', 'v' }, '<leader>D', [["+D]])
vim.keymap.set({ 'n', 'v' }, '<leader>p', [["+p]])
vim.keymap.set({ 'n', 'v' }, '<leader>P', [["+P]])

-- New line above
vim.keymap.set('n', '<leader>o', 'm`o<esc>``')
vim.keymap.set('n', '<leader>O', 'm`O<esc>``')

vim.keymap.set('n', ']b', ':bnext<cr>', { desc = 'Next [B]uffer', silent = true })
vim.keymap.set('n', '[b', ':bprev<cr>', { desc = 'Previous [B]uffer', silent = true })
vim.keymap.set('n', ']B', ':blast<cr>', { desc = 'Last [B]uffer', silent = true })
vim.keymap.set('n', '[B', ':bfirst<cr>', { desc = 'First [B]uffer', silent = true })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- Spelling
vim.keymap.set('n', '<leader>zs', ':setlocal spelloptions=camel<CR>:setlocal spell!<CR>',
  { desc = 'Toggle [S]pellcheck' })

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
