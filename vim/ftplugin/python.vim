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
	""""""""""""""""""""""""""""""""""""""""""""""
	"  Pep8
	""""""""""""""""""""""""""""""""""""""""""""""
	let g:pep8_map='<F5>'
	
