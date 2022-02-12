" vi mode is lame
set nocompatible

" Enable pathogen
call pathogen#infect()

" Turn on filetype handling
syntax on
filetype plugin on
filetype indent on

" matching methods
runtime macros/matchit.vim

" 700 history items
set history=700

" automatically reload changed files
set autoread

" Turn on wildmenu completion
set wildmenu

if exists('+relativenumber')
  " show relative line numbers
  set relativenumber
else
  set number
endif

" turn on virtual area
set virtualedit=block

set backspace=indent,eol,start

" tabs and indenting options
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent
set textwidth=80
"set smarttab
"set ai "Auto Indent
"set si " Smart Indent

" Turn off word wrap
set nowrap

" Highlight searches
set hlsearch
" Turn on incremenetal search
set incsearch

" Alow unsaved buffers to go into background
set hidden

" Set the status line to always display
set laststatus=2
" Set the status line:
"	buffer number, file, type, options, line, column, byte value
set statusline=[#%n]\ %f\ %y\ %m\ %r\ %{fugitive#statusline()}\ %=\ Line:%l/%L[%p%%]\ Col:%v\ [%b][0x%B]

" Visual bell
set vb

" Always keep some lines at the top/bottom of the screen
set scrolloff=2

" Get fid of the separator characters
set fillchars=""

" highlight cursor line/column
set cursorline
set cursorcolumn

" fix new split location
set splitbelow
set splitright

" Set listchars
set listchars=tab:→\ ,trail:·,eol:$,extends:»

set mouse=a
if has("mouse_sgr")
  set ttymouse=sgr
endif

if has("termguicolors")
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

" Set style
syntax enable
set background=dark
let g:nord_underline = 1
let g:nord_bold = 1
let g:nord_italic = 1
let g:nord_italic_comments = 1
colorscheme nord

" Get rid of the backup and swap files in the folder
if has("win32") || has("win64")
  set directory=$TEMP//
  set backupdir=$TEMP//
else
  set directory=~/tmp/vimtmp//,~/tmp//,/var/tmp//,/tmp//
  set backupdir=~/tmp/vimtmp//,~/tmp//,~//
endif

" gui options
if has("gui_running")
	if has("mac")
		set guifont=Monaco:h14
	elseif has("win32") || has("win64")
		set guifont=Consolas:h11
	endif
	" Turn off toolbar
	set guioptions-=T
	" Don't use popup dialogs
	set guioptions+=c
	" Turn off menus
	set guioptions-=m
	"Turn off scrollbars
	set guioptions-=r
	set guioptions-=R
	set guioptions-=l
	set guioptions-=L

	" Set window size
	if !exists("g:vimrcloaded")
		winsize 150 50
		let g:vimrcloaded = 1
	endif
endif

" Configure CtrlP
let g:ctrlp_match_window_reversed = 0
let g:ctrlp_max_height = 25

" Ignore the following files when completing files
set wildignore+=*.o,*.obj,.git,.svn,tmp/cache/**,tmp,node_modules,bower_components,vcr,package

highlight ColorColumn ctermbg=52 ctermfg=white guibg=#592929
set colorcolumn=+1,+2,+3

" Change cursor shape between insert and normal mode in iTerm2.app
if $TERM_PROGRAM =~ "iTerm"
  if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
  else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7" " Vertical bar in insert mode
    let &t_EI = "\<Esc>]50;CursorShape=0\x7" " Block in normal mode
  endif
endif

" remap the leader key
let mapleader = " "

" make Y like D and C
nnoremap Y y$

" Needed for tmux and vim to play nice
map <Esc>[A <Up>
map <Esc>[B <Down>
map <Esc>[C <Right>
map <Esc>[D <Left>

" Console movement
cmap <Esc>[A <Up>
cmap <Esc>[B <Down>
cmap <Esc>[C <Right>
cmap <Esc>[D <Left>

" Stop the arrow key bad habit!
map <Left> :echo 'Use h!'<CR>
map <Right> :echo 'Use l!'<CR>
map <Up> :echo 'Use k!'<CR>
map <Down> :echo 'Use j!'<CR>

" Turn off search highlighting
nmap <silent> <leader>n :silent :noh<CR>

" CtrlP Mappings
map <leader><leader> :CtrlP<CR>
map <leader>b :CtrlPBuffer<CR>
map <leader>gv :CtrlP app/views<CR>
map <leader>gc :CtrlP app/controllers<CR>
map <leader>gm :CtrlP app/models<CR>
map <leader>gh :CtrlP app/helpers<CR>
map <leader>ga :CtrlP app/assets<CR>
map <leader>gs :CtrlP app/assets/stylesheets<CR>
map <leader>gj :CtrlP app/assets/javascripts<CR>

" TComment mappings
map <leader>cc :TComment<CR>
map <leader>ci :TCommentInline<CR>
map <leader>cr :TCommentRight<CR>
map <leader>cb :TCommentBlock<CR>

" listchars mappings
map <silent><leader>l :set list!<CR>

" run rspec
map <leader>rr :!rspec --color %<CR>

" xmpfilter mappings
let g:xmpfilter_cmd = "xmpfilter -a --no-warning"
autocmd FileType ruby nmap <buffer> <leader>m <Plug>(xmpfilter-mark)
autocmd FileType ruby xmap <buffer> <leader>m <Plug>(xmpfilter-mark)

autocmd FileType ruby nmap <buffer> <leader>a <Plug>(xmpfilter-run)
autocmd FileType ruby xmap <buffer> <leader>a <Plug>(xmpfilter-run)

" Save files using sudo
cmap w!! w !sudo tee % >/dev/null

" indent settings overrides per language
autocmd FileType c setlocal sw=4 tabstop=4
autocmd FileType ruby setlocal tw=80
autocmd FileType sh setlocal tw=80

" Rust
let g:rustfmt_autosave = 1

" ale
let g:ale_linters = {
\   'javascript': ['eslint'],
\   'python': ['pycodestyle'],
\   'rust': ['analyzer']
\}
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier', 'eslint'],
\   'json': ['prettier'],
\   'python': ['autopep8'],
\   'rust': ['rustfmt']
\}
let g:ale_fix_on_save = 1

" Prettier
let g:prettier#autoformat = 0

" Get rid of any saved highlighting
:noh
