" vi mode is lame
set nocompatible

" Turn on filetype handling
syntax on
filetype plugin on
filetype indent on

" 700 history items
set history=700

" automatically reload changed files
set autoread

" Turn on wildmenu completion
set wildmenu

" show relative line numbers
set relativenumber

" tabs and indenting options
set tabstop=4
"set shiftwidth=4
"set softtabstop=4
"set noexpandtab
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
set statusline=[#%n]\ %f\ %y\ %m\ %r\ %=\ Line:%l/%L[%p%%]\ Col:%v\ [%b][0x%B]

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

" gui options
if has("gui_running")
	set guifont=Monaco:h14
	" Turn off toolbar
	set guioptions-=T
	" Don't use popup dialogs
	set guioptions+=c
	" Turn off menus
	set guioptions-=m

	" Set window size
	if !exists("g:vimrcloaded")
		winsize 130 40
		let g:vimrcloaded = 1
	endif
end

:noh
