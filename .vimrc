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

" tabs and indenting options
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent
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

" Set style
syntax enable
let g:solarized_contract="normal"
let g:solarized_menu=0
let g:solarized_italic=0
set background=dark
colorscheme solarized

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
		set guifont=Consolas:h12
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

" Ignore the following files when completing files
set wildignore+=*.o,*.obj,.git,.svn,tmp/cache/**

" Highlight long lines
highlight OverLength ctermbg=red ctermfg=white guibg=#592929
match OverLength /\%>80v.\+/

" Get rid of any saved highlighting
:noh
