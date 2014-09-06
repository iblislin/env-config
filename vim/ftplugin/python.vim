""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi def LeadingSpaces term=reverse ctermfg=15 ctermbg=241 gui=reverse guifg=#dc322f
match LeadingSpaces /^\ \+/

""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal expandtab
nnoremap <buffer> <F5> :w<CR>:exec '!python' shellescape(@%, 1)<CR>
imap <buffer> <F5> <ESC><F5>

""""""""""""""""""""""""""""""""""""""""""""""
"  Plugins
""""""""""""""""""""""""""""""""""""""""""""""
	""""""""""""""""""""""""""""""""""""""""
	" jedi-vim
	""""""""""""""""""""""""""""""""""""""""
	let g:jedi#popup_select_first = 0
	" Fix popup for autocomplpop
	" au FileType python inoremap <buffer> . .<C-R>=jedi#complete_opened() ? "" : "\<lt>C-X>\<lt>C-O>\<lt>C-P>"<CR>

	""""""""""""""""""""""""""""""""""""""""""""""
	"  Pep8
	""""""""""""""""""""""""""""""""""""""""""""""
	let g:pep8_map='<F8>'

	""""""""""""""""""""""""""""""""""""""""""""""
	"  Vundle
	""""""""""""""""""""""""""""""""""""""""""""""
	Bundle 'jedi-vim'
	Bundle 'pep8'
