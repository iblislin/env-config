""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi def LeadingSpaces term=reverse ctermfg=15 ctermbg=241 gui=reverse guifg=#dc322f
match LeadingSpaces /^\ \+/

""""""""""""""""""""""""""""""""""""""""""""""
"  Misc
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal expandtab

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
	let g:pep8_map='<F5>'

	""""""""""""""""""""""""""""""""""""""""""""""
	"  Vundle
	""""""""""""""""""""""""""""""""""""""""""""""
	Bundle 'jedi-vim'
	Bundle 'pep8'
