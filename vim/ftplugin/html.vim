""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal tabstop=2
setlocal shiftwidth=2
setlocal expandtab

hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
match BadWhitespace /\s\+$/

autocmd BufWritePre *.html :call StripTrailingWhitespaces()
